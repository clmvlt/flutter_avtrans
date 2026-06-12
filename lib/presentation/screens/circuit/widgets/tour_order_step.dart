import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/geo_point.dart';
import '../../../../data/models/optimization_models.dart';
import '../../../../data/models/tour_model.dart';
import '../../../../data/models/tour_stop.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_sheet.dart';
import '../circuit_format.dart';
import 'map_point_picker_screen.dart';
import 'tour_map_view.dart';
import 'tour_widgets.dart';

/// Étape 2 de l'assistant : trier la tournée (automatique via optimisation ou
/// manuel par glisser-déposer), définir le point de départ, basculer entre la
/// liste et la carte, puis valider pour passer en livraison.
class TourOrderStep extends StatefulWidget {
  const TourOrderStep({
    super.key,
    required this.tourId,
    required this.onBack,
    required this.onValidated,
  });

  final String tourId;
  final VoidCallback onBack;
  final VoidCallback onValidated;

  @override
  State<TourOrderStep> createState() => _TourOrderStepState();
}

class _TourOrderStepState extends State<TourOrderStep> {
  static const LatLng _franceCenter = LatLng(46.6, 2.4);

  bool _optimizing = false;
  bool _mapView = false;
  bool _depotResolved = false;

  // Calcul auto du tracé pour l'ordre courant (même non optimisé).
  bool _routing = false;
  String? _lastRouteSig;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDepot());
  }

  /// Au premier accès, propose la position actuelle comme départ par défaut.
  Future<void> _ensureDepot() async {
    if (_depotResolved) return;
    _depotResolved = true;
    final tour = sl.tourService.tourById(widget.tourId);
    if (tour == null || tour.depot != null) return;
    final here = await _currentLatLng();
    if (!mounted || here == null) return;
    await sl.tourService.setDepot(
      widget.tourId,
      GeoPoint(here.latitude, here.longitude),
    );
  }

  Future<LatLng?> _currentLatLng() async {
    var position = await sl.locationService.getLastKnownPosition();
    position ??= await sl.locationService.getCurrentPosition();
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  // ─── Départ ──────────────────────────────────────────────

  Future<void> _changeDepot(Tour tour) async {
    final depot = await _chooseDepot(tour);
    if (!mounted || depot == null) return;
    await sl.tourService.setDepot(widget.tourId, depot);
  }

  Future<GeoPoint?> _chooseDepot(Tour tour) async {
    final choice = await AppSheet.show<String>(
      context,
      title: 'Point de départ',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionTile(
            icon: Icons.my_location_rounded,
            label: 'Ma position actuelle',
            onTap: () => Navigator.of(ctx).pop('me'),
          ),
          _ActionTile(
            icon: Icons.map_outlined,
            label: 'Choisir sur la carte',
            onTap: () => Navigator.of(ctx).pop('map'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return null;

    if (choice == 'me') {
      final here = await _currentLatLng();
      if (here == null) {
        if (mounted) _snack('Position indisponible. Choisis sur la carte.');
        return null;
      }
      return GeoPoint(here.latitude, here.longitude);
    }
    final initial = tour.depot != null
        ? LatLng(tour.depot!.lat, tour.depot!.lon)
        : (await _currentLatLng() ?? _franceCenter);
    if (!mounted) return null;
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPointPickerScreen(
          initial: initial,
          title: 'Point de départ',
          confirmLabel: 'Choisir ce départ',
        ),
      ),
    );
    return result == null ? null : GeoPoint(result.latitude, result.longitude);
  }

  // ─── Tri ─────────────────────────────────────────────────

  Future<void> _optimize(Tour tour) async {
    if (tour.stops.length < 2) {
      _snack('Ajoute au moins 2 adresses pour optimiser.');
      return;
    }
    var depot = tour.depot;
    depot ??= await _chooseDepot(tour);
    if (!mounted || depot == null) return;

    setState(() => _optimizing = true);
    final request = OptimizeRequest(
      depot: depot,
      visits: [
        for (final s in tour.stops)
          OptimizeVisit(id: s.id, name: s.label, lat: s.lat, lon: s.lon),
      ],
    );
    final either = await sl.routingRepository.optimize(request);
    if (!mounted) return;
    setState(() => _optimizing = false);

    either.fold(
      (failure) => _snack(failure.message),
      (result) {
        sl.tourService.applyOptimization(tour.id, depot!, result);
        if (result.primaryRoute == null) {
          _snack('Aucun arrêt n\'a pu être routé. Vérifie les points.');
        } else if (result.skippedVisits.isNotEmpty) {
          _snack(
            '${result.skippedVisits.length} arrêt(s) écarté(s) — non rattachable(s) au réseau.',
          );
        } else {
          _snack(
            'Tournée optimisée · ${formatDistance(result.totalDistanceMeters)} · ${formatDuration(result.totalDrivingTimeSeconds)}',
          );
        }
      },
    );
  }

  /// Signature de l'ordre courant (dépôt + ids d'arrêts) : sert à ne recalculer
  /// le tracé que lorsque l'ordre ou le départ change.
  String _routeSignature(Tour tour) {
    final d = tour.depot;
    if (d == null) return '';
    return '${d.lat},${d.lon}|${tour.activeStops.map((s) => s.id).join(',')}';
  }

  /// Calcule le tracé routier de l'ordre courant via `/routing/route`, même
  /// sans optimisation, dès qu'un départ et des arrêts existent. Idempotent :
  /// ne recalcule que si l'ordre/le départ a changé (évite toute boucle).
  Future<void> _maybeComputeRoute(Tour tour) async {
    if (_routing) return;
    final depot = tour.depot;
    final active = tour.activeStops;
    if (depot == null || active.isEmpty) return;

    final sig = _routeSignature(tour);
    if (sig == _lastRouteSig) return;
    _lastRouteSig = sig;

    // Si l'ordre optimisé a déjà son tracé (avec ETA par arrêt), on le garde.
    if (tour.hasRoute && tour.optimized) return;

    setState(() => _routing = true);
    final points = <GeoPoint>[
      depot,
      ...active.map((s) => GeoPoint(s.lat, s.lon)),
      depot,
    ];
    final either = await sl.routingRepository.route(points);
    if (!mounted) return;
    setState(() => _routing = false);
    either.fold((_) {}, (r) => sl.tourService.applyManualRoute(tour.id, r));
  }

  Future<void> _onReorder(Tour tour, int oldIndex, int newIndex) async {
    // reorderStops invalide le tracé ; il est recalculé via _maybeComputeRoute.
    await sl.tourService.reorderStops(tour.id, oldIndex, newIndex);
  }

  Future<void> _removeStop(int index) =>
      sl.tourService.removeStopAt(widget.tourId, index);

  Future<void> _stopActions(TourStop stop, int index) async {
    await AppSheet.show<void>(
      context,
      title: stop.label,
      builder: (ctx) => _ActionTile(
        icon: Icons.delete_outline_rounded,
        label: 'Retirer de la tournée',
        destructive: true,
        onTap: () {
          Navigator.of(ctx).pop();
          _removeStop(index);
        },
      ),
    );
  }

  void _validate(Tour tour) {
    if (tour.stops.isEmpty) {
      _snack('Ajoute au moins une adresse avant de valider.');
      return;
    }
    widget.onValidated();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: sl.tourService,
      builder: (context, _) {
        final tour = sl.tourService.tourById(widget.tourId);
        if (tour == null) return const SizedBox.shrink();

        // Calcule/rafraîchit le tracé de l'ordre courant (même non optimisé).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeComputeRoute(tour);
        });

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Adresses',
              onPressed: widget.onBack,
            ),
            title: const Text('Ordre de la tournée'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.base,
                  AppSpacing.screen,
                  AppSpacing.sm,
                ),
                child: _DepotCard(tour: tour, onTap: () => _changeDepot(tour)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                  vertical: AppSpacing.sm,
                ),
                child: _ViewToggle(
                  mapView: _mapView,
                  onChanged: (v) => setState(() => _mapView = v),
                ),
              ),
              if (_routing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              Expanded(
                child: _mapView ? _buildMap(tour) : _buildList(tour),
              ),
              _buildActionBar(tour),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap(Tour tour) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.xs,
        AppSpacing.screen,
        AppSpacing.base,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: TourMapView(tour: tour),
      ),
    );
  }

  Widget _buildList(Tour tour) {
    var number = 0;
    final children = <Widget>[];
    for (var i = 0; i < tour.stops.length; i++) {
      final stop = tour.stops[i];
      final display = stop.skipped ? null : ++number;
      children.add(
        Padding(
          key: ValueKey(stop.id),
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _StopTile(
            index: i,
            number: display,
            stop: stop,
            optimized: tour.optimized,
            onTap: () => _stopActions(stop, i),
          ),
        ),
      );
    }

    return ReorderableListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.xs,
        AppSpacing.screen,
        AppSpacing.lg,
      ),
      buildDefaultDragHandles: false,
      header: _buildListHeader(tour),
      onReorder: (o, n) => _onReorder(tour, o, n),
      children: children,
    );
  }

  Widget _buildListHeader(Tour tour) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final skipped = tour.skippedStops;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tour.hasRoute) ...[
          _RouteLine(tour: tour),
          const SizedBox(height: AppSpacing.md),
        ],
        if (skipped.isNotEmpty) ...[
          SkippedBanner(count: skipped.length),
          const SizedBox(height: AppSpacing.md),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Text(
                'Arrêts · ${tour.stopCount}',
                style: textTheme.titleSmall
                    ?.copyWith(color: colors.mutedForeground),
              ),
              const Spacer(),
              if (tour.optimized)
                StatusChip(label: 'Optimisée', color: colors.success)
              else if (tour.hasRoute)
                StatusChip(label: 'Ordre manuel', color: colors.mutedForeground),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(Tour tour) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        boxShadow: colors.navShadow,
        border: colors.isDarkMode
            ? Border(top: BorderSide(color: colors.border))
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  text: tour.optimized ? 'Ré-optimiser' : 'Optimiser',
                  icon: Icons.auto_awesome_rounded,
                  variant: ButtonVariant.secondary,
                  isLoading: _optimizing,
                  onPressed: tour.stops.length < 2 || _optimizing
                      ? null
                      : () => _optimize(tour),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  text: 'Valider',
                  icon: Icons.check_rounded,
                  onPressed: _optimizing ? null : () => _validate(tour),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte « point de départ » de la tournée.
class _DepotCard extends StatelessWidget {
  const _DepotCard({required this.tour, required this.onTap});

  final Tour tour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final depot = tour.depot;
    final subtitle = depot == null
        ? 'Appuie pour définir le départ'
        : '${depot.lat.toStringAsFixed(5)}, ${depot.lon.toStringAsFixed(5)}';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.foreground,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.home_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Départ', style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            depot == null ? 'Définir' : 'Modifier',
            style: textTheme.labelMedium?.copyWith(color: colors.primary),
          ),
        ],
      ),
    );
  }
}

/// Bascule Liste / Carte.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.mapView, required this.onChanged});

  final bool mapView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: [
          _segment(context, 'Liste', Icons.format_list_numbered_rounded,
              selected: !mapView, onTap: () => onChanged(false)),
          _segment(context, 'Carte', Icons.map_rounded,
              selected: mapView, onTap: () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    String label,
    IconData icon, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: selected ? colors.cardShadow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? colors.primary : colors.mutedForeground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? colors.foreground : colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne compacte de résumé du tracé (dans l'en-tête de liste).
class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.tour});
  final Tour tour;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.route_rounded, size: 18, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${formatDistance(tour.totalDistanceMeters)} · ${formatDuration(tour.totalDrivingSeconds)}',
            style: textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.index,
    required this.number,
    required this.stop,
    required this.optimized,
    required this.onTap,
  });

  final int index;
  final int? number;
  final TourStop stop;
  final bool optimized;
  final VoidCallback onTap;

  String? _subtitle() {
    if (stop.skipped) {
      return stop.skipReason == 'TOO_FAR'
          ? 'Écarté · trop éloigné d\'une route'
          : 'Écarté · hors réseau routier';
    }
    if (optimized && stop.arrivalTime != null) {
      final dist = stop.cumulativeDistanceMeters;
      final arrival = 'Arrivée ${formatTime(stop.arrivalTime)}';
      return dist != null ? '$arrival · ${formatDistance(dist)}' : arrival;
    }
    final secondary = stop.address.secondaryLine;
    return secondary.isEmpty || stop.label.contains(secondary) ? null : secondary;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final subtitle = _subtitle();

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: stop.skipped ? colors.warningMuted : colors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: stop.skipped
                ? Icon(Icons.warning_amber_rounded,
                    size: 18, color: colors.warning)
                : Text(
                    '${number ?? ''}',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.label,
                  style: textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color:
                          stop.skipped ? colors.warning : colors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Icon(Icons.drag_indicator_rounded,
                  size: 22, color: colors.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final color = destructive ? colors.destructive : colors.foreground;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              children: [
                Icon(icon,
                    size: 22,
                    color: destructive
                        ? colors.destructive
                        : colors.mutedForeground),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(label,
                      style: textTheme.titleSmall?.copyWith(color: color)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

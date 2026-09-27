import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/geo_point.dart';
import '../../../../data/models/optimization_models.dart';
import '../../../../data/models/tour_model.dart';
import '../../../../data/models/tour_stop.dart';
import '../../../widgets/app_alert.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dock.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/app_segmented.dart';
import 'circuit_action_sheet.dart';
import 'map_point_picker_screen.dart';
import 'tour_order_widgets.dart';

enum _DepotChoice { here, map }

/// Étape 2 de l'assistant : trier la tournée (automatique via optimisation ou
/// manuel par glisser-déposer), définir le point de départ, basculer entre la
/// liste et la carte, puis enregistrer pour passer en livraison.
///
/// Le dock porte l'optimisation (secondaire) et l'enregistrement (principal),
/// avec au-dessus l'état du tracé (distance · durée, calcul en cours).
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

class _TourOrderStepState extends State<TourOrderStep> with DockNoticeMixin {
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
    final choice = await showCircuitActionSheet<_DepotChoice>(
      context,
      title: 'Point de départ',
      actions: const [
        CircuitSheetAction(
          value: _DepotChoice.here,
          icon: Icons.my_location_rounded,
          label: 'Ma position actuelle',
        ),
        CircuitSheetAction(
          value: _DepotChoice.map,
          icon: Icons.map_outlined,
          label: 'Choisir sur la carte',
        ),
      ],
    );
    if (!mounted || choice == null) return null;

    if (choice == _DepotChoice.here) {
      final here = await _currentLatLng();
      if (here == null) {
        if (mounted) showDockError('Position indisponible. Choisis sur la carte.');
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
    clearDockNotice();
    if (tour.stops.length < 2) {
      showDockError('Ajoute au moins 2 adresses pour optimiser.');
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
      (failure) {
        HapticFeedback.heavyImpact();
        showDockError(failure.message);
      },
      (result) {
        sl.tourService.applyOptimization(tour.id, depot!, result);
        final skipped = result.skippedVisits.length;
        if (result.primaryRoute == null) {
          showDockNotice(
            'Aucun arrêt n\'a pu être routé. Vérifie les points.',
            variant: AlertVariant.warning,
          );
        } else if (skipped > 0) {
          showDockNotice(
            skipped == 1
                ? '1 arrêt écarté : non rattachable au réseau.'
                : '$skipped arrêts écartés : non rattachables au réseau.',
            variant: AlertVariant.warning,
          );
        } else {
          // Le succès se voit : liste réordonnée et tracé « optimisée ».
          HapticFeedback.mediumImpact();
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
    final remove = await showCircuitActionSheet<bool>(
      context,
      title: stop.label,
      actions: const [
        CircuitSheetAction(
          value: true,
          icon: Icons.delete_outline_rounded,
          label: 'Retirer de la tournée',
          destructive: true,
        ),
      ],
    );
    if (remove != true || !mounted) return;
    await _removeStop(index);
  }

  void _validate(Tour tour) {
    clearDockNotice();
    if (tour.stops.isEmpty) {
      showDockError('Ajoute au moins une adresse avant de valider.');
      return;
    }
    widget.onValidated();
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: sl.tourService,
      builder: (context, _) {
        final tour = sl.tourService.tourById(widget.tourId);
        if (tour == null) {
          return Scaffold(backgroundColor: colors.background, appBar: AppBar());
        }

        // Calcule/rafraîchit le tracé de l'ordre courant (même non optimisé).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeComputeRoute(tour);
        });

        return AppPage(
          title: 'Ordre de la tournée',
          leading: AppIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Adresses',
            color: colors.foreground,
            onPressed: widget.onBack,
          ),
          bottom: AppPageBar(
            child: AppSegmented<bool>(
              segments: const [
                AppSegment(
                  value: false,
                  label: 'Liste',
                  icon: Icons.format_list_numbered_rounded,
                ),
                AppSegment(value: true, label: 'Carte', icon: Icons.map_rounded),
              ],
              selected: _mapView,
              onChanged: (v) => setState(() => _mapView = v),
            ),
          ),
          body: _mapView ? _buildMap(tour) : _buildList(tour),
          dock: _buildDock(tour),
        );
      },
    );
  }

  Widget _buildMap(Tour tour) =>
      OrderMapPanel(tour: tour, onChangeDepot: () => _changeDepot(tour));

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
          child: OrderStopCard(
            index: i,
            number: display,
            stop: stop,
            optimized: tour.optimized,
            onTap: () => _stopActions(stop, i),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final side = AppLayout.sidePadding(constraints.maxWidth);
        return ReorderableListView(
          padding: EdgeInsets.fromLTRB(
            side + padding.left,
            AppSpacing.md,
            side + padding.right,
            AppSpacing.lg + padding.bottom,
          ),
          buildDefaultDragHandles: false,
          header: OrderListHeader(
            tour: tour,
            onChangeDepot: () => _changeDepot(tour),
            onBack: widget.onBack,
          ),
          // `onReorderItem` donne l'index final (déjà corrigé du retrait) ;
          // le service attend l'index « avant retrait » de l'ancien
          // `onReorder` : on le reconstitue.
          onReorderItem: (oldIndex, newIndex) => _onReorder(
            tour,
            oldIndex,
            newIndex > oldIndex ? newIndex + 1 : newIndex,
          ),
          children: children,
        );
      },
    );
  }

  Widget _buildDock(Tour tour) {
    final canOptimize = tour.stops.length >= 2;
    return AppDock(
      status: OrderRouteLine(tour: tour, routing: _routing),
      actions: [
        // Deux boutons côte à côte : libellés courts pour ne pas être coupés.
        if (canOptimize)
          DockAction(
            label: tour.optimized ? 'Ré-optimiser' : 'Optimiser',
            icon: Icons.auto_awesome_rounded,
            tone: DockTone.secondary,
            isLoading: _optimizing,
            onPressed: _optimizing ? null : () => _optimize(tour),
            semanticsHint: 'Calcule l\'ordre de passage le plus rapide',
          ),
        DockAction(
          label: canOptimize ? 'Enregistrer' : 'Enregistrer la tournée',
          icon: Icons.check_rounded,
          onPressed: _optimizing ? null : () => _validate(tour),
          semanticsHint: 'Valide la tournée et passe en livraison',
        ),
      ],
      notice: dockNotice,
      onDismissNotice: clearDockNotice,
    );
  }
}

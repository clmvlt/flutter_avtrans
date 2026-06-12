import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/navigation_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/tour_model.dart';
import '../../../data/models/tour_stop.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'circuit_format.dart';
import 'tour_edit_flow_screen.dart';
import 'tour_map_screen.dart';
import 'widgets/navigation_app_sheet.dart';
import 'widgets/tour_widgets.dart';

/// Mode **livraison** d'une tournée validée : liste ordonnée des points en
/// lecture seule, avec accès à la carte et à la navigation GPS (par arrêt ou
/// pour toute la tournée). « Modifier » (menu ⋮) repasse en mode édition.
class TourDeliveryScreen extends StatefulWidget {
  const TourDeliveryScreen({super.key, required this.tourId});

  final String tourId;

  @override
  State<TourDeliveryScreen> createState() => _TourDeliveryScreenState();
}

class _TourDeliveryScreenState extends State<TourDeliveryScreen> {
  Future<void> _navigate(TourStop stop) async {
    final app = sl.navigationPreferenceService.current;
    final ok = await NavigationLauncher.openPoint(
      app,
      stop.lat,
      stop.lon,
      label: stop.label,
    );
    if (!ok && mounted) _snack('Impossible d\'ouvrir l\'application GPS.');
  }

  Future<void> _navigateRoute(Tour tour) async {
    final app = sl.navigationPreferenceService.current;
    final stops = tour.activeStops.map((s) => (lat: s.lat, lon: s.lon)).toList();
    if (stops.isEmpty) return;
    final origin =
        tour.depot == null ? null : (lat: tour.depot!.lat, lon: tour.depot!.lon);
    final ok = await NavigationLauncher.openRoute(app, stops, origin: origin);
    if (!ok && mounted) _snack('Impossible d\'ouvrir l\'application GPS.');
  }

  Future<void> _modify(Tour tour) async {
    await sl.tourService.setStatus(tour.id, TourStatus.draft);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TourEditFlowScreen(tourId: tour.id)),
    );
  }

  void _openMap(Tour tour) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TourMapScreen(tourId: tour.id)),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      // Écoute aussi la préférence GPS pour rafraîchir la pastille d'app.
      listenable: Listenable.merge(
        [sl.tourService, sl.navigationPreferenceService],
      ),
      builder: (context, _) {
        final tour = sl.tourService.tourById(widget.tourId);
        if (tour == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
          return Scaffold(backgroundColor: colors.background, appBar: AppBar());
        }

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            title: Text(tour.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.map_outlined),
                tooltip: 'Voir sur la carte',
                onPressed: () => _openMap(tour),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _modify(tour);
                  if (v == 'nav') showNavigationAppSheet(context);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  PopupMenuItem(
                      value: 'nav', child: Text('Application GPS')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _buildList(tour)),
              if (tour.activeStops.isNotEmpty)
                _BottomBar(
                  tour: tour,
                  onNavigateRoute: () => _navigateRoute(tour),
                  onChangeApp: () => showNavigationAppSheet(context),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(Tour tour) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    var number = 0;
    final stopWidgets = <Widget>[];
    for (final stop in tour.stops) {
      final display = stop.skipped ? null : ++number;
      stopWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _DeliveryStopTile(
            number: display,
            stop: stop,
            optimized: tour.optimized,
            onNavigate: stop.skipped ? null : () => _navigate(stop),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.base,
        AppSpacing.screen,
        AppSpacing.lg,
      ),
      children: [
        if (tour.hasRoute) ...[
          RouteSummaryCard(tour: tour, onTap: () => _openMap(tour)),
          const SizedBox(height: AppSpacing.md),
        ],
        if (tour.skippedStops.isNotEmpty) ...[
          SkippedBanner(count: tour.skippedStops.length),
          const SizedBox(height: AppSpacing.md),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Points · ${tour.stopCount}',
            style: textTheme.titleSmall?.copyWith(color: colors.mutedForeground),
          ),
        ),
        ...stopWidgets,
      ],
    );
  }
}

class _DeliveryStopTile extends StatelessWidget {
  const _DeliveryStopTile({
    required this.number,
    required this.stop,
    required this.optimized,
    required this.onNavigate,
  });

  final int? number;
  final TourStop stop;
  final bool optimized;
  final VoidCallback? onNavigate;

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
      onTap: onNavigate,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: stop.skipped ? colors.warningMuted : colors.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: stop.skipped
                ? Icon(Icons.warning_amber_rounded,
                    size: 18, color: colors.warning)
                : Text(
                    '${number ?? ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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
          if (onNavigate != null)
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.navigation_rounded,
                  size: 20, color: colors.primary),
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.tour,
    required this.onNavigateRoute,
    required this.onChangeApp,
  });

  final Tour tour;
  final VoidCallback onNavigateRoute;
  final VoidCallback onChangeApp;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final app = sl.navigationPreferenceService.current;

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
                  text: 'Lancer la navigation',
                  icon: Icons.navigation_rounded,
                  onPressed: onNavigateRoute,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                onTap: onChangeApp,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded,
                          size: 16, color: colors.mutedForeground),
                      const SizedBox(width: 6),
                      Text(app.label, style: textTheme.labelMedium),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

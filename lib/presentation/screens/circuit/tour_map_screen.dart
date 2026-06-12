import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/navigation_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/tour_model.dart';
import '../../../data/models/tour_stop.dart';
import '../../widgets/app_button.dart';
import 'circuit_format.dart';
import 'widgets/navigation_app_sheet.dart';
import 'widgets/tour_map_view.dart';

/// Carte plein écran d'une tournée : tracé + arrêts numérotés, avec navigation
/// GPS (par arrêt ou pour toute la tournée).
class TourMapScreen extends StatefulWidget {
  const TourMapScreen({super.key, required this.tourId});

  final String tourId;

  @override
  State<TourMapScreen> createState() => _TourMapScreenState();
}

class _TourMapScreenState extends State<TourMapScreen> {
  TourStop? _selected;

  Future<void> _navigateToStop(TourStop stop) async {
    final app = sl.navigationPreferenceService.current;
    final ok = await NavigationLauncher.openPoint(
      app,
      stop.lat,
      stop.lon,
      label: stop.label,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir l\'application GPS.')),
      );
    }
  }

  Future<void> _navigateRoute(Tour tour) async {
    final app = sl.navigationPreferenceService.current;
    final stops = tour.activeStops.map((s) => (lat: s.lat, lon: s.lon)).toList();
    if (stops.isEmpty) return;
    final origin =
        tour.depot == null ? null : (lat: tour.depot!.lat, lon: tour.depot!.lon);
    final ok = await NavigationLauncher.openRoute(app, stops, origin: origin);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir l\'application GPS.')),
      );
    }
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
          return Scaffold(appBar: AppBar());
        }

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            title: Text(tour.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Application GPS',
                onPressed: () => showNavigationAppSheet(context),
              ),
            ],
          ),
          body: Stack(
            children: [
              TourMapView(
                tour: tour,
                selected: _selected,
                onStopTap: (s) => setState(() => _selected = s),
                onMapTap: () => setState(() => _selected = null),
              ),
              if (_selected != null)
                Positioned(
                  left: AppSpacing.base,
                  right: AppSpacing.base,
                  bottom: tour.activeStops.isEmpty ? AppSpacing.base : 132,
                  child: _StopCard(
                    stop: _selected!,
                    onNavigate: () => _navigateToStop(_selected!),
                    onClose: () => setState(() => _selected = null),
                  ),
                ),
              if (tour.activeStops.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomBar(
                    tour: tour,
                    onNavigateRoute: () => _navigateRoute(tour),
                    onChangeApp: () => showNavigationAppSheet(context),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stop,
    required this.onNavigate,
    required this.onClose,
  });

  final TourStop stop;
  final VoidCallback onNavigate;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: colors.heroShadow,
        border: colors.isDarkMode ? Border.all(color: colors.border) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(stop.label, style: textTheme.titleSmall)),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close_rounded,
                    size: 20, color: colors.mutedForeground),
              ),
            ],
          ),
          if (stop.arrivalTime != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Arrivée estimée ${formatTime(stop.arrivalTime)}'
              '${stop.cumulativeDistanceMeters != null ? ' · ${formatDistance(stop.cumulativeDistanceMeters)}' : ''}',
              style: textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            text: 'Naviguer ici',
            icon: Icons.navigation_rounded,
            size: ButtonSize.sm,
            onPressed: onNavigate,
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
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tour.hasRoute)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                ),
              Row(
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
            ],
          ),
        ),
      ),
    );
  }
}

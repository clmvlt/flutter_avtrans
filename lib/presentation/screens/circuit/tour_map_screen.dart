import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/navigation_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/tour_model.dart';
import '../../../data/models/tour_stop.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dock.dart';
import '../../widgets/app_page.dart';
import 'circuit_format.dart';
import 'widgets/navigation_app_sheet.dart';
import 'widgets/tour_map_parts.dart';
import 'widgets/tour_map_view.dart';
import 'widgets/tour_widgets.dart';

/// Carte plein écran d'une tournée : tracé + arrêts numérotés, avec navigation
/// GPS (par arrêt ou pour toute la tournée).
///
/// La carte passe sous le dock (« Lancer la navigation ») ; toucher un repère
/// ouvre la carte de l'arrêt au-dessus du dock, avec « Naviguer ici ».
class TourMapScreen extends StatefulWidget {
  const TourMapScreen({super.key, required this.tourId});

  final String tourId;

  @override
  State<TourMapScreen> createState() => _TourMapScreenState();
}

class _TourMapScreenState extends State<TourMapScreen> with DockNoticeMixin {
  static const String _gpsError = 'Impossible d\'ouvrir l\'application GPS.';

  TourStop? _selected;

  Future<void> _navigateToStop(TourStop stop) async {
    clearDockNotice();
    final app = sl.navigationPreferenceService.current;
    final ok = await NavigationLauncher.openPoint(
      app,
      stop.lat,
      stop.lon,
      label: stop.label,
    );
    if (!ok && mounted) showDockError(_gpsError);
  }

  Future<void> _navigateRoute(Tour tour) async {
    clearDockNotice();
    final app = sl.navigationPreferenceService.current;
    final stops = tour.activeStops.map((s) => (lat: s.lat, lon: s.lon)).toList();
    if (stops.isEmpty) return;
    final origin =
        tour.depot == null ? null : (lat: tour.depot!.lat, lon: tour.depot!.lon);
    final ok = await NavigationLauncher.openRoute(app, stops, origin: origin);
    if (!ok && mounted) showDockError(_gpsError);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      // Écoute aussi la préférence GPS pour rafraîchir la ligne d'app.
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

        final hasActiveStops = tour.activeStops.isNotEmpty;
        final selected = _selected;

        return AppPage(
          title: tour.name,
          actions: [
            AppIconButton(
              icon: Icons.tune_rounded,
              tooltip: 'Application GPS',
              color: colors.foreground,
              onPressed: () => showNavigationAppSheet(context),
            ),
          ],
          body: LayoutBuilder(
            builder: (context, constraints) {
              // Lu dans le corps : hauteur du dock (la carte passe dessous).
              final inset = MediaQuery.paddingOf(context).bottom;
              final side = AppLayout.sidePadding(constraints.maxWidth);
              return Stack(
                children: [
                  TourMapView(
                    tour: tour,
                    selected: selected,
                    fitPadding: EdgeInsets.only(bottom: inset),
                    onStopTap: (s) => setState(() => _selected = s),
                    onMapTap: () => setState(() => _selected = null),
                  ),
                  if (!hasActiveStops)
                    Positioned(
                      left: side,
                      right: side,
                      bottom: inset + AppSpacing.base,
                      child: MapEmptyNotice(
                        message: tour.stops.isEmpty
                            ? 'Aucun arrêt dans cette tournée'
                            : 'Aucun arrêt routable à afficher',
                      ),
                    ),
                  if (selected != null)
                    Positioned(
                      left: side,
                      right: side,
                      bottom: inset + AppSpacing.sm,
                      child: SelectedStopCard(
                        stop: selected,
                        number: _numberOf(tour, selected),
                        onNavigate: () => _navigateToStop(selected),
                        onClose: () => setState(() => _selected = null),
                      ),
                    ),
                ],
              );
            },
          ),
          dock: AppDock(
            status: hasActiveStops
                ? NavigationAppLine(
                    app: sl.navigationPreferenceService.current,
                    summary: tour.hasRoute
                        ? formatRouteSummary(
                            tour.totalDistanceMeters,
                            tour.totalDrivingSeconds,
                          )
                        : null,
                    onChangeApp: () => showNavigationAppSheet(context),
                  )
                : null,
            actions: [
              if (hasActiveStops)
                DockAction(
                  label: 'Lancer la navigation',
                  icon: Icons.navigation_rounded,
                  // Un arrêt touché devient l'action principale (sa carte).
                  tone: selected != null
                      ? DockTone.secondary
                      : DockTone.primary,
                  onPressed: () => _navigateRoute(tour),
                  semanticsHint: 'Ouvre toute la tournée dans le GPS',
                ),
            ],
            notice: dockNotice,
            onDismissNotice: clearDockNotice,
          ),
        );
      },
    );
  }

  /// Rang de l'arrêt parmi les arrêts routés (comme sur les repères).
  int? _numberOf(Tour tour, TourStop stop) {
    final index = tour.activeStops.indexWhere((s) => identical(s, stop));
    return index < 0 ? null : index + 1;
  }
}

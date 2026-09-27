import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/navigation_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/tour_model.dart';
import '../../../data/models/tour_stop.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dock.dart';
import '../../widgets/app_list_row.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_state_views.dart';
import 'tour_edit_flow_screen.dart';
import 'tour_map_screen.dart';
import 'widgets/circuit_action_sheet.dart';
import 'widgets/delivery_widgets.dart';
import 'widgets/navigation_app_sheet.dart';
import 'widgets/tour_widgets.dart';

enum _DeliveryAction { edit, gpsApp }

/// Mode **livraison** d'une tournée validée : liste ordonnée des points en
/// lecture seule, avec accès à la carte et à la navigation GPS (par arrêt ou
/// pour toute la tournée). « Modifier la tournée » (menu ⋮) repasse en mode
/// édition.
class TourDeliveryScreen extends StatefulWidget {
  const TourDeliveryScreen({super.key, required this.tourId});

  final String tourId;

  @override
  State<TourDeliveryScreen> createState() => _TourDeliveryScreenState();
}

class _TourDeliveryScreenState extends State<TourDeliveryScreen>
    with DockNoticeMixin {
  static const String _gpsError = 'Impossible d\'ouvrir l\'application GPS.';

  Future<void> _navigate(TourStop stop) async {
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

  Future<void> _showMenu(Tour tour) async {
    final action = await showCircuitActionSheet<_DeliveryAction>(
      context,
      title: tour.name,
      actions: [
        const CircuitSheetAction(
          value: _DeliveryAction.edit,
          icon: Icons.edit_road_rounded,
          label: 'Modifier la tournée',
          subtitle: 'Repasse en préparation : adresses et ordre',
        ),
        CircuitSheetAction(
          value: _DeliveryAction.gpsApp,
          icon: Icons.navigation_outlined,
          label: 'Application GPS',
          subtitle: sl.navigationPreferenceService.current.label,
        ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _DeliveryAction.edit:
        await _modify(tour);
      case _DeliveryAction.gpsApp:
        await showNavigationAppSheet(context);
    }
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

        return AppPage(
          title: tour.name,
          actions: [
            AppIconButton(
              icon: Icons.map_outlined,
              tooltip: 'Voir sur la carte',
              color: colors.foreground,
              onPressed: () => _openMap(tour),
            ),
            AppIconButton(
              icon: Icons.more_vert_rounded,
              tooltip: 'Plus d\'actions',
              color: colors.foreground,
              onPressed: () => _showMenu(tour),
            ),
          ],
          body: AppScrollView(
            children: [
              DeliveryHeroCard(tour: tour, onTap: () => _openMap(tour)),
              if (tour.skippedStops.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                SkippedStopsCallout(count: tour.skippedStops.length),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppSectionHeader(
                title: 'Arrêts',
                summary: DisplayFormat.plural(tour.stopCount, 'arrêt'),
              ),
              if (tour.stops.isEmpty)
                AppEmptyCard(
                  icon: Icons.wrong_location_outlined,
                  message: 'Aucun arrêt dans cette tournée',
                  actionLabel: 'Modifier',
                  onAction: () => _modify(tour),
                )
              else
                RowsCard(children: _stopRows(tour)),
            ],
          ),
          dock: AppDock(
            status: hasActiveStops
                ? NavigationAppLine(
                    app: sl.navigationPreferenceService.current,
                    onChangeApp: () => showNavigationAppSheet(context),
                  )
                : null,
            actions: [
              if (hasActiveStops)
                DockAction(
                  label: 'Lancer la navigation',
                  icon: Icons.navigation_rounded,
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

  List<Widget> _stopRows(Tour tour) {
    var number = 0;
    return [
      for (final stop in tour.stops)
        DeliveryStopRow(
          key: ValueKey(stop.id),
          number: stop.skipped ? null : ++number,
          stop: stop,
          optimized: tour.optimized,
          onNavigate: stop.skipped ? null : () => _navigate(stop),
        ),
    ];
  }
}

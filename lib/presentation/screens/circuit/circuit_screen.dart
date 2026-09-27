import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/tour_model.dart';
import '../../widgets/app_confirm_sheet.dart';
import '../../widgets/app_dock.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_list_row.dart';
import '../../widgets/app_page.dart';
import 'tour_delivery_screen.dart';
import 'tour_edit_flow_screen.dart';
import 'widgets/circuit_action_sheet.dart';
import 'widgets/tour_list_items.dart';
import 'widgets/tour_name_dialog.dart';
import 'widgets/tour_widgets.dart';

enum _TourAction { rename, delete }

/// Écran « Circuit » : liste des tournées.
///
/// Point d'entrée de la fonctionnalité : on y crée, ouvre et supprime des
/// tournées. La carte hero montre la tournée en cours (la plus récente en
/// livraison, sinon la plus récente) ; les autres sont des lignes. Une
/// tournée s'ouvre en mode édition (brouillon) ou livraison (validée) selon
/// son statut. Les tournées sont locales (persistées sur l'appareil et
/// chargées au démarrage) : pas d'état de chargement ni d'erreur réseau.
class CircuitScreen extends StatelessWidget {
  const CircuitScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final name = await showTourNameDialog(
      context,
      title: 'Nouvelle tournée',
      actionLabel: 'Créer la tournée',
    );
    if (name == null || !context.mounted) return;
    final tour = await sl.tourService.createTour(name);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TourEditFlowScreen(tourId: tour.id)),
    );
  }

  void _open(BuildContext context, Tour tour) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => tour.isDelivery
            ? TourDeliveryScreen(tourId: tour.id)
            : TourEditFlowScreen(tourId: tour.id),
      ),
    );
  }

  Future<void> _rename(BuildContext context, Tour tour) async {
    final name = await showTourNameDialog(
      context,
      title: 'Renommer la tournée',
      actionLabel: 'Enregistrer le nom',
      initialName: tour.name,
    );
    if (name == null || !context.mounted) return;
    await sl.tourService.renameTour(tour.id, name);
  }

  Future<void> _confirmDelete(BuildContext context, Tour tour) async {
    final stops = tour.stopCount;
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Supprimer la tournée ?',
      message: stops == 0
          ? '« ${tour.name} » sera définitivement supprimée.'
          : '« ${tour.name} » sera définitivement supprimée, avec '
              '${DisplayFormat.plural(stops, 'arrêt')}.',
      confirmLabel: 'Supprimer la tournée',
      confirmIcon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !context.mounted) return;
    await sl.tourService.deleteTour(tour.id);
  }

  Future<void> _showActions(BuildContext context, Tour tour) async {
    final action = await showCircuitActionSheet<_TourAction>(
      context,
      title: tour.name,
      actions: const [
        CircuitSheetAction(
          value: _TourAction.rename,
          icon: Icons.edit_rounded,
          label: 'Renommer',
        ),
        CircuitSheetAction(
          value: _TourAction.delete,
          icon: Icons.delete_outline_rounded,
          label: 'Supprimer la tournée',
          destructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _TourAction.rename:
        await _rename(context, tour);
      case _TourAction.delete:
        await _confirmDelete(context, tour);
    }
  }

  /// La tournée mise en avant : la plus récente en livraison, sinon la plus
  /// récente tout court (la liste est triée de la plus récente à la plus
  /// ancienne).
  Tour? _focusTour(List<Tour> tours) {
    for (final tour in tours) {
      if (tour.isDelivery) return tour;
    }
    return tours.isEmpty ? null : tours.first;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl.tourService,
      builder: (context, _) {
        final tours = sl.tourService.tours;
        final focus = _focusTour(tours);
        final others = [
          for (final tour in tours)
            if (tour.id != focus?.id) tour,
        ];

        return AppPage(
          title: 'Tournées',
          body: focus == null
              ? const _EmptyBody()
              : AppScrollView(
                  children: [
                    TourHeroCard(
                      tour: focus,
                      onTap: () => _open(context, focus),
                      onMore: () => _showActions(context, focus),
                    ),
                    if (others.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppSectionHeader(
                        title: 'Autres tournées',
                        summary: DisplayFormat.plural(others.length, 'tournée'),
                      ),
                      RowsCard(
                        children: [
                          for (final tour in others)
                            TourRow(
                              key: ValueKey(tour.id),
                              tour: tour,
                              onTap: () => _open(context, tour),
                              onMore: () => _showActions(context, tour),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
          dock: AppDock(
            actions: [
              DockAction(
                label: 'Nouvelle tournée',
                icon: Icons.add_rounded,
                onPressed: () => _create(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Aucune tournée : état vide centré dans la zone visible au-dessus du dock.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: const AppEmptyState(
        icon: Icons.route_rounded,
        title: 'Aucune tournée',
        subtitle:
            'Crée ta première tournée pour commencer à ajouter des adresses.',
      ),
    );
  }
}

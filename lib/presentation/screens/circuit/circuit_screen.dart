import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/tour_model.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import 'tour_delivery_screen.dart';
import 'tour_edit_flow_screen.dart';
import 'widgets/tour_name_dialog.dart';
import 'widgets/tour_widgets.dart';

/// Écran « Circuit » — liste des tournées.
///
/// Point d'entrée de la fonctionnalité : on y crée, ouvre et supprime des
/// tournées. Une tournée s'ouvre en mode édition (brouillon) ou livraison
/// (validée) selon son statut. Les données sont persistées.
class CircuitScreen extends StatelessWidget {
  const CircuitScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final name = await showTourNameDialog(
      context,
      title: 'Nouvelle tournée',
      actionLabel: 'Créer',
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

  Future<void> _confirmDelete(BuildContext context, Tour tour) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la tournée ?'),
        content: Text(
          '« ${tour.name} » et ses ${tour.stopCount} arrêt(s) seront définitivement supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.destructive),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await sl.tourService.deleteTour(tour.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: sl.tourService,
      builder: (context, _) {
        final tours = sl.tourService.tours;

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(title: const Text('Tournées')),
          floatingActionButton: tours.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _create(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nouvelle tournée'),
                  backgroundColor: colors.primary,
                  foregroundColor: colors.primaryForeground,
                ),
          body: tours.isEmpty
              ? AppEmptyState(
                  icon: Icons.route_rounded,
                  title: 'Aucune tournée',
                  subtitle:
                      'Crée ta première tournée pour commencer à ajouter des adresses.',
                  actionText: 'Nouvelle tournée',
                  onAction: () => _create(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.base,
                    AppSpacing.screen,
                    // Laisse la place au FAB.
                    AppSpacing.xxl + AppSpacing.lg,
                  ),
                  itemCount: tours.length,
                  itemBuilder: (context, index) {
                    final tour = tours[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _TourCard(
                        tour: tour,
                        onTap: () => _open(context, tour),
                        onRename: () async {
                          final name = await showTourNameDialog(
                            context,
                            title: 'Renommer la tournée',
                            actionLabel: 'Enregistrer',
                            initialName: tour.name,
                          );
                          if (name == null || !context.mounted) return;
                          await sl.tourService.renameTour(tour.id, name);
                        },
                        onDelete: () => _confirmDelete(context, tour),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

/// Carte d'une tournée dans la liste.
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.tour,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final Tour tour;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  String get _subtitle {
    final count = tour.stopCount;
    final stops = count <= 1 ? '$count arrêt' : '$count arrêts';
    final d = tour.createdAt.day.toString().padLeft(2, '0');
    final m = tour.createdAt.month.toString().padLeft(2, '0');
    return '$stops · créée le $d/$m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.route_rounded, color: colors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tour.name,
                        style: textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusChip(
                      label: tour.isDelivery ? 'Livraison' : 'Brouillon',
                      color: tour.isDelivery
                          ? colors.success
                          : colors.mutedForeground,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(_subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: colors.mutedForeground),
            onSelected: (value) {
              if (value == 'rename') onRename();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Renommer')),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Supprimer',
                  style: TextStyle(color: colors.destructive),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

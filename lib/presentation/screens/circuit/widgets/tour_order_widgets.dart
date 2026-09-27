import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/tour_model.dart';
import '../../../../data/models/tour_stop.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/app_state_views.dart';
import '../circuit_format.dart';
import 'tour_map_view.dart';
import 'tour_widgets.dart';

/// Carte « Départ » de l'étape Ordre : point de départ et de retour de la
/// tournée, touchable pour le changer.
class DepotCard extends StatelessWidget {
  const DepotCard({super.key, required this.tour, required this.onTap});

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

    return RowsCard(
      children: [
        AppListRow(
          icon: Icons.home_rounded,
          iconColor: colors.foreground,
          title: 'Départ',
          subtitle: subtitle,
          showChevron: false,
          onTap: onTap,
          trailing: Text(
            depot == null ? 'Définir' : 'Modifier',
            style: textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          semanticsLabel: depot == null
              ? 'Départ non défini. Définir le départ'
              : 'Départ : $subtitle. Modifier le départ',
        ),
      ],
    );
  }
}

/// En-tête de la liste réordonnable : départ, arrêts écartés, titre de
/// section, et l'état vide (aucun arrêt).
class OrderListHeader extends StatelessWidget {
  const OrderListHeader({
    super.key,
    required this.tour,
    required this.onChangeDepot,
    required this.onBack,
  });

  final Tour tour;
  final VoidCallback onChangeDepot;

  /// Retour à l'étape « Adresses ».
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final skipped = tour.skippedStops;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DepotCard(tour: tour, onTap: onChangeDepot),
        if (skipped.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SkippedStopsCallout(count: skipped.length),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: 'Arrêts',
          summary: DisplayFormat.plural(tour.stopCount, 'arrêt'),
        ),
        if (tour.stops.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 16,
                  color: colors.mutedForeground,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Fais glisser la poignée pour changer l\'ordre',
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        if (tour.stops.isEmpty)
          AppEmptyCard(
            icon: Icons.add_location_alt_outlined,
            message: 'Aucun arrêt',
            detail: 'Reviens aux adresses pour en ajouter.',
            actionLabel: 'Adresses',
            onAction: onBack,
          ),
      ],
    );
  }
}

/// Mode « Carte » de l'étape Ordre : départ au-dessus, carte du tracé qui
/// remplit l'espace jusqu'au dock.
class OrderMapPanel extends StatelessWidget {
  const OrderMapPanel({
    super.key,
    required this.tour,
    required this.onChangeDepot,
  });

  final Tour tour;
  final VoidCallback onChangeDepot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final side = AppLayout.sidePadding(constraints.maxWidth);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            side + padding.left,
            AppSpacing.md,
            side + padding.right,
            // Hauteur du dock (fondu compris) : la carte s'arrête au-dessus.
            padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DepotCard(tour: tour, onTap: onChangeDepot),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  // La carte est dans une carte : l'attribution n'a pas à
                  // réserver la place du dock.
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    removeBottom: true,
                    removeLeft: true,
                    removeRight: true,
                    child: TourMapView(tour: tour),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ligne d'état du dock de l'étape Ordre : calcul en cours, ou tracé
/// (distance · durée) et nature de l'ordre (optimisé / manuel).
class OrderRouteLine extends StatelessWidget {
  const OrderRouteLine({super.key, required this.tour, required this.routing});

  final Tour tour;
  final bool routing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (routing) {
      return const DockStatusLine(text: 'Calcul du trajet…', busy: true);
    }
    if (tour.hasRoute) {
      final summary = formatRouteSummary(
        tour.totalDistanceMeters,
        tour.totalDrivingSeconds,
      );
      return DockStatusLine(
        icon: tour.optimized ? Icons.auto_awesome_rounded : Icons.route_rounded,
        color: tour.optimized ? colors.success : colors.primary,
        text: '$summary · ${tour.optimized ? 'optimisée' : 'ordre manuel'}',
      );
    }
    return DockStatusLine(
      icon: Icons.route_rounded,
      text: tour.depot == null
          ? 'Définis le départ pour calculer le trajet'
          : 'Trajet non calculé',
    );
  }
}

/// Carte d'un arrêt dans la liste réordonnable : rang, adresse, arrivée
/// estimée, poignée de glisser-déposer. Tap : actions de l'arrêt.
class OrderStopCard extends StatelessWidget {
  const OrderStopCard({
    super.key,
    required this.index,
    required this.number,
    required this.stop,
    required this.optimized,
    required this.onTap,
  });

  /// Position dans la liste (pour la poignée de glisser-déposer).
  final int index;

  /// Rang de passage ; `null` pour un arrêt écarté.
  final int? number;
  final TourStop stop;
  final bool optimized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      padding: EdgeInsets.zero,
      child: AppListRow(
        leading: StopNumberBox(number: number, skipped: stop.skipped),
        title: stop.label,
        subtitle: stopSubtitle(stop, optimized: optimized),
        showChevron: false,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.sm,
          0,
          AppSpacing.sm,
        ),
        trailing: ReorderableDragStartListener(
          index: index,
          child: Semantics(
            label: 'Déplacer l\'arrêt',
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 22,
                color: colors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

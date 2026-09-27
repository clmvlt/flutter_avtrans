import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/tour_model.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_hero_card.dart';
import '../../../widgets/app_list_row.dart';
import '../circuit_format.dart';

/// Mot d'état d'une tournée : « En livraison » (validée) ou « En
/// préparation » (brouillon).
String tourStatusLabel(Tour tour) =>
    tour.isDelivery ? 'En livraison' : 'En préparation';

IconData tourStatusIcon(Tour tour) =>
    tour.isDelivery ? Icons.local_shipping_rounded : Icons.edit_road_rounded;

Color tourStatusColor(Tour tour, AppColors colors) =>
    tour.isDelivery ? colors.success : colors.primary;

/// Carte hero de la liste des tournées : la tournée en cours (ou la plus
/// récente). Tap : l'ouvre ; « ⋮ » : renommer / supprimer.
class TourHeroCard extends StatelessWidget {
  const TourHeroCard({
    super.key,
    required this.tour,
    required this.onTap,
    required this.onMore,
  });

  final Tour tour;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppHeroCard(
      icon: tourStatusIcon(tour),
      accent: tourStatusColor(tour, colors),
      title: tourStatusLabel(tour),
      subtitle: tour.name,
      onTap: onTap,
      trailing: AppIconButton(
        icon: Icons.more_vert_rounded,
        tooltip: 'Actions sur la tournée',
        color: colors.mutedForeground,
        onPressed: onMore,
      ),
      child: AppMetricRow(
        metrics: [
          AppMetric(label: 'Arrêts', value: '${tour.stopCount}'),
          if (tour.hasRoute) ...[
            AppMetric(
              label: 'Distance',
              value: formatDistance(tour.totalDistanceMeters),
            ),
            AppMetric(
              label: 'Conduite',
              value: formatDuration(tour.totalDrivingSeconds),
            ),
          ] else
            AppMetric(
              label: 'Créée le',
              value: DisplayFormat.dateSmart(tour.createdAt),
            ),
        ],
      ),
    );
  }
}

/// Ligne d'une tournée : état (icône + mot), nombre d'arrêts, date de
/// création, menu « ⋮ ».
class TourRow extends StatelessWidget {
  const TourRow({
    super.key,
    required this.tour,
    required this.onTap,
    required this.onMore,
  });

  final Tour tour;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final d = tour.createdAt.day.toString().padLeft(2, '0');
    final m = tour.createdAt.month.toString().padLeft(2, '0');
    final subtitle = '${tourStatusLabel(tour)} · '
        '${DisplayFormat.plural(tour.stopCount, 'arrêt')} · créée le $d/$m';

    return AppListRow(
      icon: tourStatusIcon(tour),
      iconColor: tourStatusColor(tour, colors),
      title: tour.name,
      subtitle: subtitle,
      showChevron: false,
      onTap: onTap,
      onLongPress: onMore,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      trailing: AppIconButton(
        icon: Icons.more_vert_rounded,
        tooltip: 'Actions sur la tournée',
        color: colors.mutedForeground,
        onPressed: onMore,
      ),
    );
  }
}

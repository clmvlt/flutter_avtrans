import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/tour_model.dart';
import '../../../../data/models/tour_stop.dart';
import '../../../widgets/app_hero_card.dart';
import '../../../widgets/app_list_row.dart';
import '../circuit_format.dart';
import 'tour_widgets.dart';

/// Carte hero du mode livraison : état de la tournée et chiffres du tracé.
/// Tap (chevron) : ouvre la carte.
class DeliveryHeroCard extends StatelessWidget {
  const DeliveryHeroCard({super.key, required this.tour, required this.onTap});

  final Tour tour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle = !tour.hasRoute
        ? 'Trajet non calculé'
        : tour.optimized
            ? 'Tournée optimisée'
            : 'Ordre manuel';

    return AppHeroCard(
      icon: Icons.local_shipping_rounded,
      accent: colors.success,
      title: 'En livraison',
      subtitle: subtitle,
      onTap: onTap,
      child: AppMetricRow(
        metrics: [
          AppMetric(label: 'Arrêts', value: '${tour.stopCount}'),
          AppMetric(
            label: 'Distance',
            value: formatDistance(tour.totalDistanceMeters),
          ),
          AppMetric(
            label: 'Conduite',
            value: formatDuration(tour.totalDrivingSeconds),
          ),
        ],
      ),
    );
  }
}

/// Ligne d'un arrêt en livraison : rang, adresse, heure d'arrivée estimée.
/// Tap : lance la navigation vers l'arrêt (sauf arrêt écarté).
class DeliveryStopRow extends StatelessWidget {
  const DeliveryStopRow({
    super.key,
    required this.number,
    required this.stop,
    required this.optimized,
    required this.onNavigate,
  });

  final int? number;
  final TourStop stop;
  final bool optimized;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle = stopSubtitle(stop, optimized: optimized);

    return AppListRow(
      leading: StopNumberBox(number: number, skipped: stop.skipped),
      title: stop.label,
      subtitle: subtitle,
      showChevron: false,
      onTap: onNavigate,
      trailing: onNavigate == null
          ? null
          : Icon(
              Icons.navigation_rounded,
              size: 20,
              color: colors.primary,
            ),
      semanticsLabel: [
        stop.skipped ? 'Arrêt écarté' : 'Arrêt ${number ?? ''}',
        stop.label,
        if (subtitle != null) subtitle,
        if (onNavigate != null) 'Naviguer',
      ].join('. '),
    );
  }
}

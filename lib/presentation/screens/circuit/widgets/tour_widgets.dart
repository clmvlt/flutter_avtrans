import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/tour_model.dart';
import '../../../widgets/app_card.dart';
import '../circuit_format.dart';

/// Carte de résumé du tracé (distance + durée) — ouvre la carte au tap.
class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({super.key, required this.tour, required this.onTap});

  final Tour tour;
  final VoidCallback onTap;

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
              color: colors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.route_rounded, color: colors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatDistance(tour.totalDistanceMeters)} · ${formatDuration(tour.totalDrivingSeconds)}',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text('Voir le tracé sur la carte', style: textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.mutedForeground),
        ],
      ),
    );
  }
}

/// Bannière d'avertissement : arrêts écartés par l'optimisation.
class SkippedBanner extends StatelessWidget {
  const SkippedBanner({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.warningMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: colors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$count arrêt(s) écarté(s) : adresse non rattachable au réseau routier. Ajuste leur point GPS.',
              style: textTheme.bodySmall
                  ?.copyWith(color: colors.warningForeground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille de statut (« Optimisée », « Ordre manuel »…).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

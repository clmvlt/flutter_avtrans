import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/service_model.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_skeleton.dart';

/// Bandeau des repères « Semaine · Mois · Mois dernier » — une seule ligne
/// discrète qui remplace les quatre tuiles et mène à l'écran Mes heures.
/// « Aujourd'hui » n'y figure pas : c'est le compteur du hero.
class HoursStrip extends StatelessWidget {
  const HoursStrip({super.key, required this.hours, required this.onTap});

  final WorkedHours? hours;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: 'Mes heures : semaine ${TimeFormat.hoursDecimal(hours?.week)}, '
          'mois ${TimeFormat.hoursDecimal(hours?.month)}, '
          'mois dernier ${TimeFormat.hoursDecimal(hours?.lastMonth)}',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Row(
          children: [
            _Figure(label: 'Semaine', hours: hours?.week, loading: hours == null),
            const SizedBox(width: AppSpacing.md),
            _Figure(label: 'Mois', hours: hours?.month, loading: hours == null),
            const SizedBox(width: AppSpacing.md),
            _Figure(
              label: 'Mois dernier',
              hours: hours?.lastMonth,
              loading: hours == null,
            ),
            Icon(Icons.chevron_right_rounded, color: colors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.hours,
    required this.loading,
  });

  final String label;
  final double? hours;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: textTheme.bodySmall, maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          if (loading)
            const AppSkeleton(width: 64, height: 19)
          else
            Text(
              TimeFormat.hoursDecimal(hours),
              style: textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

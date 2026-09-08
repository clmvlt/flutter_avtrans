import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../widgets/app_sheet.dart';

/// Feuille de confirmation « Terminer le service ? » : récapitulatif de la
/// journée (début, pauses, travaillé, fin) puis deux choix. Remplace le
/// maintien long ou le double tap : lisible, accessible, et donne au
/// chauffeur la preuve de son total avant de clôturer.
abstract final class EndServiceSheet {
  /// Retourne `true` si l'utilisateur confirme la fin de service.
  static Future<bool> show(
    BuildContext context, {
    required DateTime? start,
    required DateTime now,
    required Duration worked,
    required Duration breaks,
    required int breakCount,
  }) async {
    final result = await AppSheet.show<bool>(
      context,
      title: 'Terminer le service ?',
      builder: (ctx) => _EndServiceBody(
        start: start,
        now: now,
        worked: worked,
        breaks: breaks,
        breakCount: breakCount,
      ),
    );
    return result ?? false;
  }
}

class _EndServiceBody extends StatelessWidget {
  const _EndServiceBody({
    required this.start,
    required this.now,
    required this.worked,
    required this.breaks,
    required this.breakCount,
  });

  final DateTime? start;
  final DateTime now;
  final Duration worked;
  final Duration breaks;
  final int breakCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final pausesLabel = breakCount == 0
        ? 'Aucune'
        : '${TimeFormat.durationShort(breaks)} · $breakCount';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Le total du jour sera figé. Tu pourras démarrer un nouveau service '
          'plus tard si besoin.',
          style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
        ),
        const SizedBox(height: AppSpacing.base),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            children: [
              _RecapRow(
                icon: Icons.play_arrow_rounded,
                label: 'Début',
                value: start != null ? TimeFormat.hm(start!) : '—',
              ),
              _RecapRow(
                icon: Icons.coffee_rounded,
                label: 'Pauses',
                value: pausesLabel,
              ),
              _RecapRow(
                icon: Icons.stop_rounded,
                label: 'Fin',
                value: TimeFormat.hm(now),
              ),
              Divider(height: AppSpacing.base, color: colors.border),
              _RecapRow(
                icon: Icons.schedule_rounded,
                label: 'Travaillé',
                value: TimeFormat.durationShort(worked),
                emphasized: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.destructive,
              foregroundColor: colors.destructiveForeground,
              textStyle: textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.stop_rounded, size: 22),
            label: const Text('Terminer le service'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 52,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: colors.foreground),
            child: const Text('Continuer à travailler'),
          ),
        ),
      ],
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.mutedForeground),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: emphasized ? colors.foreground : colors.mutedForeground,
                fontWeight: emphasized ? FontWeight.w600 : null,
              ),
            ),
          ),
          Text(
            value,
            style: (emphasized ? textTheme.titleLarge : textTheme.titleSmall)
                ?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

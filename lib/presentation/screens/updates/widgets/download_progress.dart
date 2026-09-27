import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Barre de progression d'un téléchargement, avec son pourcentage.
class DownloadProgress extends StatelessWidget {
  const DownloadProgress({super.key, required this.progress});

  /// 0 → 1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);

    return Semantics(
      label: 'Téléchargement',
      value: '$percent %',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Téléchargement…', style: textTheme.bodySmall),
              ),
              Text(
                '$percent %',
                style: textTheme.labelMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.surfaceSunken,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

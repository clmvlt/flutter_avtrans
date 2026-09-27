import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/widgets.dart';

/// Ligne de fiche en lecture seule, à la géométrie d'[AppListRow] (56 dp,
/// boîte d'icône 40) : libellé discret au-dessus, valeur lisible en dessous,
/// pastille d'état optionnelle à droite.
class VehiculeFieldRow extends StatelessWidget {
  const VehiculeFieldRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.valueMaxLines = 2,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Pastille d'état ([AppStatusChip]) à droite.
  final Widget? trailing;
  final int valueMaxLines;

  /// Valeur absente (« — ») : texte en `mutedForeground`.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppLayout.rowMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              AppIconBox(icon: icon, color: colors.mutedForeground),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: textTheme.bodySmall),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      style: textTheme.titleSmall?.copyWith(
                        color: muted ? colors.mutedForeground : null,
                      ),
                      maxLines: valueMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

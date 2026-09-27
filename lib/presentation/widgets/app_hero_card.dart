import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_card.dart';
import 'app_list_row.dart';
import 'app_page.dart';

/// Carte hero : LE point focal d'une page, sur le modèle de la carte de la
/// page Pointage. Ligne d'état (boîte d'icône 44 · mot d'état 22 sp en
/// `foreground` · sous-ligne) puis contenu libre (grand chiffre, métriques).
///
/// La carte reste sur `card` : l'état vit dans l'icône et le mot, jamais
/// dans un fond teinté.
class AppHeroCard extends StatelessWidget {
  const AppHeroCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.onTap,
    this.showChevron,
    this.header,
  });

  final IconData icon;
  final Color accent;

  /// Mot d'état ou nom de l'objet (« 2 véhicules en retard », « AB-123-CD »).
  final String title;
  final String? subtitle;

  /// Accessoire de la ligne d'état (badge, point pulsant). Chevron par
  /// défaut si la carte est tapable.
  final Widget? trailing;

  /// Contenu sous la ligne d'état, précédé de 24 dp.
  final Widget? child;
  final VoidCallback? onTap;

  /// Chevron en fin de ligne d'état ; par défaut : carte tapable sans
  /// [trailing]. Peut s'ajouter à un [trailing] (point pulsant…).
  final bool? showChevron;

  /// Bloc au-dessus de la ligne d'état (photo…), suivi de 16 dp.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      elevation: AppCardElevation.hero,
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            header!,
            const SizedBox(height: AppSpacing.base),
          ],
          Row(
            children: [
              AppIconBox(
                icon: icon,
                color: accent,
                size: AppLayout.heroIconBox,
                iconSize: 24,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: textTheme.headlineSmall,
                        maxLines: 1,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: textTheme.bodyLarge
                            ?.copyWith(color: colors.mutedForeground),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
              if (showChevron ?? (trailing == null && onTap != null)) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right_rounded, color: colors.mutedForeground),
              ],
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: AppSpacing.lg),
            child!,
          ],
        ],
      ),
    );
  }
}

/// Un chiffre clé : libellé `bodySmall` au-dessus, valeur `titleLarge`
/// tabulaire (comme le bandeau des heures de la page Pointage).
class AppMetric extends StatelessWidget {
  const AppMetric({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Deux à quatre [AppMetric] côte à côte, à parts égales.
class AppMetricRow extends StatelessWidget {
  const AppMetricRow({super.key, required this.metrics});

  final List<AppMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: metrics[i]),
        ],
      ],
    );
  }
}

/// Grand chiffre de carte hero (52 sp tabulaire, `displayLarge`), précédé
/// de son libellé : « Travaillé aujourd'hui » / « 7h42 ».
class AppHeroFigure extends StatelessWidget {
  const AppHeroFigure({
    super.key,
    required this.label,
    required this.value,
    this.muted = false,
    this.small = false,
  });

  final String label;
  final String value;

  /// Valeur nulle / en attente : chiffre en `mutedForeground`.
  final bool muted;

  /// 34 sp (`displaySmall`) au lieu de 52 sp, pour les valeurs longues.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final style = (small ? textTheme.displaySmall : textTheme.displayLarge)
        ?.copyWith(
      color: muted ? colors.mutedForeground : colors.foreground,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: style, maxLines: 1),
        ),
      ],
    );
  }
}

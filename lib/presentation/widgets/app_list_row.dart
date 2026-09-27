import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_page.dart';

/// Boîte d'icône teintée : fond de l'accent à 16 %, icône dans l'accent.
/// 40 dp dans une ligne, 44 dp dans une carte hero.
class AppIconBox extends StatelessWidget {
  const AppIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = AppLayout.iconBox,
    this.iconSize,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, size: iconSize ?? (size * 0.55).roundToDouble(),
          color: color),
    );
  }
}

/// Ligne tapable de 56 dp min : boîte d'icône · titre + sous-ligne ·
/// accessoire (valeur, badge) · chevron quand la ligne ouvre quelque chose.
///
/// Le titre est l'action ou l'objet (« Signer mes heures », « AB-123-CD »),
/// la sous-ligne dit le pourquoi ou le détail. Le texte reste en
/// `foreground` / `mutedForeground` : seule l'icône porte la couleur.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.leading,
    this.trailing,
    this.showChevron,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.base,
      vertical: AppSpacing.sm,
    ),
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.md)),
    this.subtitleMaxLines = 2,
    this.titleStyle,
    this.semanticsLabel,
  });

  final String title;
  final String? subtitle;

  /// Icône dans une [AppIconBox] teintée par [iconColor].
  final IconData? icon;
  final Color? iconColor;

  /// Remplace la boîte d'icône (avatar, vignette…).
  final Widget? leading;

  /// Valeur ou badge à droite, avant le chevron.
  final Widget? trailing;

  /// Chevron à droite ; par défaut : ligne tapable sans [trailing].
  final bool? showChevron;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final int subtitleMaxLines;
  final TextStyle? titleStyle;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final chevron = showChevron ?? (onTap != null && trailing == null);
    final lead = leading ??
        (icon != null
            ? AppIconBox(icon: icon!, color: iconColor ?? colors.mutedForeground)
            : null);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppLayout.rowMinHeight),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (lead != null) ...[
              lead,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: titleStyle ?? textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall,
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
            if (chevron) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.mutedForeground,
              ),
            ],
          ],
        ),
      ),
    );

    final content = onTap == null && onLongPress == null
        ? row
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: borderRadius,
              child: row,
            ),
          );

    if (semanticsLabel == null) return content;
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      // Le libellé remplace ceux des enfants : l'action doit rester
      // déclenchable par le lecteur d'écran.
      onTap: onTap,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: content,
    );
  }
}

/// En-tête de section façon « Aujourd'hui » de la page Pointage : titre
/// `titleMedium` à gauche, résumé discret ou lien texte à droite, puis
/// 12 dp avant le contenu (inclus).
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.summary,
    this.actionLabel,
    this.onAction,
  });

  final String title;

  /// Résumé à droite : « 3 services · 1 pause ».
  final String? summary;

  /// Lien texte à droite (« Tout voir »), prioritaire sur [summary].
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final hasAction = actionLabel != null && onAction != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xs,
        0,
        hasAction ? 0 : AppSpacing.xs,
        hasAction ? AppSpacing.xs : AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: textTheme.titleMedium),
            ),
          ),
          if (hasAction)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                minimumSize: const Size(48, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                textStyle: textTheme.labelLarge,
              ),
              child: Text(actionLabel!),
            )
          else if (summary != null && summary!.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            // Le titre passe avant : le résumé prend sa largeur naturelle,
            // plafonnée à 45 % pour ne jamais écraser le titre.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.45,
              ),
              child: Text(
                summary!,
                style: textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pastille d'état : icône teintée + libellé en `foreground` sur un fond de
/// la teinte à 12 %. Jamais la couleur seule.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: colors.foreground,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

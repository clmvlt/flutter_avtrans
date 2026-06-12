import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_card.dart';

/// Section de réglages/outils — un titre discret + un groupe de tuiles
/// dans une [AppCard] (pattern « Réglages iOS », très « app mobile »).
///
/// ```dart
/// AppSection(
///   title: 'MON ACTIVITÉ',
///   children: [
///     AppTile(icon: Icons.event_busy, label: 'Absences', onTap: ...),
///     AppTile(icon: Icons.payments, label: 'Acomptes', onTap: ...),
///   ],
/// )
/// ```
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    this.title,
    required this.children,
  });

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    // Insère des séparateurs fins entre les tuiles.
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: colors.border, indent: 56));
      }
      rows.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              title!.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(letterSpacing: 0.8),
            ),
          ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: rows),
        ),
      ],
    );
  }
}

/// Tuile d'une [AppSection] — chip d'icône coloré + libellé + accessoire.
class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.color,
    this.badgeText,
    this.badgeColor,
    this.trailing,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Couleur d'accent du chip d'icône (défaut : accent du thème).
  final Color? color;

  /// Pastille de valeur à droite (ex. « 3 », « à signer »).
  final String? badgeText;
  final Color? badgeColor;

  /// Remplace le chevron par un widget custom.
  final Widget? trailing;

  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final accent = color ?? colors.mutedForeground;

    final radius = BorderRadius.vertical(
      top: Radius.circular(isFirst ? AppRadius.lg : 0),
      bottom: Radius.circular(isLast ? AppRadius.lg : 0),
    );

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: textTheme.titleSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? colors.primary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    badgeText!,
                    style: textTheme.labelSmall?.copyWith(
                      color: badgeColor ?? colors.primary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              trailing ??
                  (onTap != null
                      ? Icon(Icons.chevron_right_rounded,
                          size: 20, color: colors.mutedForeground)
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

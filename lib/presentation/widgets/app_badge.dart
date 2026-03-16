import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Variantes du badge shadcn
enum BadgeVariant { primary, secondary, destructive, outline, success, warning }

/// Badge shadcn/ui - petit indicateur de statut
class AppBadge extends StatelessWidget {
  final String text;
  final BadgeVariant variant;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.text,
    this.variant = BadgeVariant.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (bg, fg, borderColor) = _getColors(colors);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: borderColor != null
            ? Border.all(color: borderColor)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: fg,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color?) _getColors(AppColors colors) {
    return switch (variant) {
      BadgeVariant.primary => (colors.primary, colors.primaryForeground, null),
      BadgeVariant.secondary => (colors.secondary, colors.secondaryForeground, null),
      BadgeVariant.destructive => (colors.destructive, colors.destructiveForeground, null),
      BadgeVariant.outline => (Colors.transparent, colors.foreground, colors.border),
      BadgeVariant.success => (colors.success, colors.successForeground, null),
      BadgeVariant.warning => (colors.warning, colors.warningForeground, null),
    };
  }
}

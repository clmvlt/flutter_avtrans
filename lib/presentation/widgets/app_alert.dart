import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Variantes de l'alerte
enum AlertVariant { info, destructive, success, warning }

/// Alert shadcn/ui
class AppAlert extends StatelessWidget {
  final String? title;
  final String description;
  final AlertVariant variant;
  final IconData? icon;

  const AppAlert({
    super.key,
    this.title,
    required this.description,
    this.variant = AlertVariant.info,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (bg, fg, borderColor, defaultIcon) = _getStyle(colors);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: 16, color: fg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: fg,
                        height: 1.4,
                      ),
                    ),
                  ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: fg.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color, IconData) _getStyle(AppColors colors) {
    return switch (variant) {
      AlertVariant.info => (
          colors.infoMuted,
          colors.info,
          colors.info.withValues(alpha: 0.3),
          Icons.info_outline,
        ),
      AlertVariant.destructive => (
          colors.errorBg,
          colors.destructive,
          colors.destructive.withValues(alpha: 0.3),
          Icons.error_outline,
        ),
      AlertVariant.success => (
          colors.successMuted,
          colors.success,
          colors.success.withValues(alpha: 0.3),
          Icons.check_circle_outline,
        ),
      AlertVariant.warning => (
          colors.warningMuted,
          colors.warning,
          colors.warning.withValues(alpha: 0.3),
          Icons.warning_amber_rounded,
        ),
    };
  }
}

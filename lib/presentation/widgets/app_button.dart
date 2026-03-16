import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Variantes du bouton shadcn
enum ButtonVariant { primary, destructive, outline, secondary, ghost, link }

/// Bouton shadcn/ui
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final ButtonVariant variant;
  final bool fullWidth;

  // Compat legacy
  final bool isOutlined;
  final bool isDanger;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.fullWidth = true,
    this.isOutlined = false,
    this.isDanger = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  ButtonVariant get _effectiveVariant {
    if (isDanger) return ButtonVariant.destructive;
    if (isOutlined) return ButtonVariant.outline;
    return variant;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = _effectiveVariant;

    final child = isLoading
        ? SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getForeground(v, colors),
              ),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16),
                const SizedBox(width: 8),
              ],
              Text(text),
            ],
          );

    final style = _getStyle(v, colors);

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 40,
      child: switch (v) {
        ButtonVariant.primary => ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: style,
            child: child,
          ),
        ButtonVariant.destructive => ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: style,
            child: child,
          ),
        ButtonVariant.outline => OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: style,
            child: child,
          ),
        ButtonVariant.secondary => ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: style,
            child: child,
          ),
        ButtonVariant.ghost => TextButton(
            onPressed: isLoading ? null : onPressed,
            style: style,
            child: child,
          ),
        ButtonVariant.link => TextButton(
            onPressed: isLoading ? null : onPressed,
            style: style,
            child: child,
          ),
      },
    );
  }

  Color _getForeground(ButtonVariant v, AppColors colors) {
    if (foregroundColor != null) return foregroundColor!;
    return switch (v) {
      ButtonVariant.primary => colors.primaryForeground,
      ButtonVariant.destructive => colors.destructiveForeground,
      ButtonVariant.outline => colors.foreground,
      ButtonVariant.secondary => colors.secondaryForeground,
      ButtonVariant.ghost => colors.foreground,
      ButtonVariant.link => colors.primary,
    };
  }

  ButtonStyle _getStyle(ButtonVariant v, AppColors colors) {
    final fg = _getForeground(v, colors);
    final bg = backgroundColor;

    return switch (v) {
      ButtonVariant.primary => ElevatedButton.styleFrom(
          backgroundColor: bg ?? colors.primary,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ButtonVariant.destructive => ElevatedButton.styleFrom(
          backgroundColor: bg ?? colors.destructive,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ButtonVariant.outline => OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: colors.input),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ButtonVariant.secondary => ElevatedButton.styleFrom(
          backgroundColor: bg ?? colors.secondary,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ButtonVariant.ghost => TextButton.styleFrom(
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ButtonVariant.link => TextButton.styleFrom(
          foregroundColor: fg,
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
          ),
        ),
    };
  }
}

/// Bouton texte simple
class AppTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;

  const AppTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color ?? colors.primary,
      ),
      child: Text(text),
    );
  }
}

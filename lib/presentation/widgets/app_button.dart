import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Variantes du bouton
enum ButtonVariant { primary, destructive, outline, secondary, ghost, link }

/// Tailles du bouton
enum ButtonSize { sm, md, lg }

/// Bouton accessible — 48dp minimum, 16sp texte
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final ButtonVariant variant;
  final ButtonSize size;
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
    this.size = ButtonSize.md,
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

  double get _height => switch (size) {
    ButtonSize.sm => 40,
    ButtonSize.md => 48,
    ButtonSize.lg => 56,
  };

  double get _fontSize => switch (size) {
    ButtonSize.sm => 14,
    ButtonSize.md => 16,
    ButtonSize.lg => 18,
  };

  double get _iconSize => switch (size) {
    ButtonSize.sm => 16,
    ButtonSize.md => 20,
    ButtonSize.lg => 22,
  };

  EdgeInsets get _padding => switch (size) {
    ButtonSize.sm => const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ButtonSize.md => const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ButtonSize.lg => const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = _effectiveVariant;

    final child = isLoading
        ? SizedBox(
            height: _iconSize,
            width: _iconSize,
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
                Icon(icon, size: _iconSize),
                const SizedBox(width: 8),
              ],
              Text(text),
            ],
          );

    final style = _getStyle(v, colors);

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: _height,
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
          padding: _padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ButtonVariant.destructive => ElevatedButton.styleFrom(
          backgroundColor: bg ?? colors.destructive,
          foregroundColor: fg,
          elevation: 0,
          padding: _padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ButtonVariant.outline => OutlinedButton.styleFrom(
          foregroundColor: fg,
          padding: _padding,
          side: BorderSide(color: colors.input),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ButtonVariant.secondary => ElevatedButton.styleFrom(
          backgroundColor: bg ?? colors.secondary,
          foregroundColor: fg,
          elevation: 0,
          padding: _padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ButtonVariant.ghost => TextButton.styleFrom(
          foregroundColor: fg,
          padding: _padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ButtonVariant.link => TextButton.styleFrom(
          foregroundColor: fg,
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 48),
          textStyle: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
          ),
        ),
    };
  }
}

/// Bouton texte simple — touch target 48dp
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
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Text(text),
    );
  }
}

/// Bouton icone — touch target 48dp
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.tooltip,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      icon: Icon(icon, size: size, color: color ?? colors.mutedForeground),
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    );
  }
}

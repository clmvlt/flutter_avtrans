import 'package:flutter/material.dart';

/// Système de couleurs inspiré de shadcn/ui
/// Tokens: background, foreground, card, popover, primary, secondary,
/// muted, accent, destructive, border, input, ring
class AppColors {
  final bool isDarkMode;

  const AppColors._({required this.isDarkMode});

  static const AppColors light = AppColors._(isDarkMode: false);
  static const AppColors dark = AppColors._(isDarkMode: true);

  static AppColors of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }

  // ============ Background & Foreground ============
  Color get background => isDarkMode
      ? const Color(0xFF09090B) // zinc-950
      : const Color(0xFFFFFFFF);

  Color get foreground => isDarkMode
      ? const Color(0xFFFAFAFA) // zinc-50
      : const Color(0xFF09090B); // zinc-950

  // ============ Card ============
  Color get card => isDarkMode
      ? const Color(0xFF09090B)
      : const Color(0xFFFFFFFF);

  Color get cardForeground => isDarkMode
      ? const Color(0xFFFAFAFA)
      : const Color(0xFF09090B);

  // ============ Popover ============
  Color get popover => isDarkMode
      ? const Color(0xFF09090B)
      : const Color(0xFFFFFFFF);

  Color get popoverForeground => isDarkMode
      ? const Color(0xFFFAFAFA)
      : const Color(0xFF09090B);

  // ============ Primary (blue brand) ============
  Color get primary => isDarkMode
      ? const Color(0xFF3B82F6) // blue-500
      : const Color(0xFF2563EB); // blue-600

  Color get primaryForeground => isDarkMode
      ? const Color(0xFFFAFAFA)
      : const Color(0xFFFFFFFF);

  Color get primaryLight => isDarkMode
      ? const Color(0xFF60A5FA) // blue-400
      : const Color(0xFF3B82F6); // blue-500

  // ============ Secondary ============
  Color get secondary => isDarkMode
      ? const Color(0xFF27272A) // zinc-800
      : const Color(0xFFF4F4F5); // zinc-100

  Color get secondaryForeground => isDarkMode
      ? const Color(0xFFFAFAFA)
      : const Color(0xFF18181B); // zinc-900

  // ============ Muted ============
  Color get muted => isDarkMode
      ? const Color(0xFF27272A) // zinc-800
      : const Color(0xFFF4F4F5); // zinc-100

  Color get mutedForeground => isDarkMode
      ? const Color(0xFFA1A1AA) // zinc-400
      : const Color(0xFF71717A); // zinc-500

  // ============ Accent ============
  Color get accent => isDarkMode
      ? const Color(0xFF27272A) // zinc-800
      : const Color(0xFFF4F4F5); // zinc-100

  Color get accentForeground => isDarkMode
      ? const Color(0xFFFAFAFA)
      : const Color(0xFF18181B);

  // ============ Destructive ============
  Color get destructive => isDarkMode
      ? const Color(0xFFEF4444) // red-500
      : const Color(0xFFDC2626); // red-600

  Color get destructiveForeground => isDarkMode
      ? const Color(0xFFFAFAFA)
      : const Color(0xFFFFFFFF);

  // ============ Border & Input ============
  Color get border => isDarkMode
      ? const Color(0xFF27272A) // zinc-800
      : const Color(0xFFE4E4E7); // zinc-200

  Color get input => isDarkMode
      ? const Color(0xFF27272A)
      : const Color(0xFFE4E4E7);

  // ============ Ring (focus) ============
  Color get ring => isDarkMode
      ? const Color(0xFF3B82F6) // blue-500
      : const Color(0xFF2563EB); // blue-600

  // ============ Semantic Colors ============
  Color get success => isDarkMode
      ? const Color(0xFF22C55E) // green-500
      : const Color(0xFF16A34A); // green-600

  Color get successForeground => const Color(0xFFFFFFFF);

  Color get successMuted => isDarkMode
      ? const Color(0xFF052E16) // green-950
      : const Color(0xFFF0FDF4); // green-50

  Color get warning => isDarkMode
      ? const Color(0xFFFACC15) // yellow-400
      : const Color(0xFFCA8A04); // yellow-600

  Color get warningForeground => isDarkMode
      ? const Color(0xFF09090B)
      : const Color(0xFFFFFFFF);

  Color get warningMuted => isDarkMode
      ? const Color(0xFF422006) // yellow-950 approx
      : const Color(0xFFFEFCE8); // yellow-50

  Color get info => isDarkMode
      ? const Color(0xFF38BDF8) // sky-400
      : const Color(0xFF0284C7); // sky-600

  Color get infoForeground => const Color(0xFFFFFFFF);

  Color get infoMuted => isDarkMode
      ? const Color(0xFF082F49) // sky-950
      : const Color(0xFFF0F9FF); // sky-50

  // ============ Chart Colors ============
  Color get chart1 => isDarkMode
      ? const Color(0xFF3B82F6)
      : const Color(0xFF2563EB);

  Color get chart2 => isDarkMode
      ? const Color(0xFF22C55E)
      : const Color(0xFF16A34A);

  Color get chart3 => isDarkMode
      ? const Color(0xFFF59E0B)
      : const Color(0xFFD97706);

  Color get chart4 => isDarkMode
      ? const Color(0xFF8B5CF6)
      : const Color(0xFF7C3AED);

  Color get chart5 => isDarkMode
      ? const Color(0xFFEC4899)
      : const Color(0xFFDB2777);

  // ============ Aliases (backwards compat) ============
  Color get bgPrimary => background;
  Color get bgSecondary => card;
  Color get bgTertiary => muted;
  Color get bgHover => accent;
  Color get textPrimary => foreground;
  Color get textSecondary => mutedForeground;
  Color get textMuted => mutedForeground;
  Color get textInverse => primaryForeground;
  Color get borderPrimary => border;
  Color get borderSecondary => border;
  Color get borderFocus => ring;
  Color get error => destructive;
  Color get errorBg => isDarkMode
      ? const Color(0xFF450A0A) // red-950
      : const Color(0xFFFEF2F2); // red-50
  Color get successBg => successMuted;
  Color get warningBg => warningMuted;
  Color get infoBg => infoMuted;
  Color get surface => card;
  Color get divider => border;

  // ============ Static compat ============
  static const Color primaryStatic = Color(0xFF3B82F6);
  static const Color primaryLightStatic = Color(0xFF60A5FA);
  static const Color primaryDarkStatic = Color(0xFF2563EB);
  static const Color secondaryStatic = Color(0xFF8B5CF6);
  static const Color secondaryLightStatic = Color(0xFFA78BFA);
  static const Color secondaryDarkStatic = Color(0xFF7C3AED);
  static const Color bgPrimaryStatic = Color(0xFF09090B);
  static const Color bgSecondaryStatic = Color(0xFF09090B);
  static const Color bgTertiaryStatic = Color(0xFF27272A);
  static const Color bgHoverStatic = Color(0xFF27272A);
  static const Color textPrimaryStatic = Color(0xFFFAFAFA);
  static const Color textSecondaryStatic = Color(0xFFA1A1AA);
  static const Color textMutedStatic = Color(0xFF71717A);
  static const Color textInverseStatic = Color(0xFF09090B);
  static const Color borderPrimaryStatic = Color(0xFF27272A);
  static const Color borderSecondaryStatic = Color(0xFF27272A);
  static const Color borderFocusStatic = Color(0xFF3B82F6);
  static const Color successStatic = Color(0xFF22C55E);
  static const Color successBgStatic = Color(0xFF052E16);
  static const Color errorStatic = Color(0xFFEF4444);
  static const Color errorBgStatic = Color(0xFF450A0A);
  static const Color warningStatic = Color(0xFFFACC15);
  static const Color warningBgStatic = Color(0xFF422006);
  static const Color infoStatic = Color(0xFF38BDF8);
  static const Color infoBgStatic = Color(0xFF082F49);
}

/// Extension pour accéder aux couleurs depuis le contexte
extension AppColorsExtension on BuildContext {
  AppColors get colors => AppColors.of(this);
}

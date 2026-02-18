import 'package:flutter/material.dart';

/// Classe pour accéder aux couleurs en fonction du thème
class AppColors {
  final bool isDarkMode;

  const AppColors._({required this.isDarkMode});

  /// Instance pour le mode clair
  static const AppColors light = AppColors._(isDarkMode: false);

  /// Instance pour le mode sombre
  static const AppColors dark = AppColors._(isDarkMode: true);

  /// Obtient les couleurs en fonction du mode
  static AppColors of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }

  // ============ Couleurs principales ============
  // Couleurs plus saturées en light mode pour meilleur contraste
  Color get primary => isDarkMode
      ? const Color(0xFF5B7FFF)
      : const Color(0xFF4361EE);

  Color get primaryLight => isDarkMode
      ? const Color(0xFF7A9AFF)
      : const Color(0xFF6B8AFF);

  Color get primaryDark => isDarkMode
      ? const Color(0xFF4563D9)
      : const Color(0xFF3651D4);

  Color get secondary => isDarkMode
      ? const Color(0xFF8B5CF6)
      : const Color(0xFF7C3AED);

  Color get secondaryLight => isDarkMode
      ? const Color(0xFFA78BFA)
      : const Color(0xFF9061F9);

  Color get secondaryDark => isDarkMode
      ? const Color(0xFF7C3AED)
      : const Color(0xFF6D28D9);

  // ============ Couleurs de fond ============
  // Light mode: fond gris clair pour réduire l'effet "trop blanc"
  Color get bgPrimary => isDarkMode
      ? const Color(0xFF0F1419)
      : const Color(0xFFEFF1F5);  // Gris très clair au lieu de blanc

  Color get bgSecondary => isDarkMode
      ? const Color(0xFF1A1F2E)
      : const Color(0xFFFAFAFC);  // Blanc cassé léger

  Color get bgTertiary => isDarkMode
      ? const Color(0xFF252B3B)
      : const Color(0xFFE8EBF0);  // Gris plus marqué

  Color get bgHover => isDarkMode
      ? const Color(0xFF2D3548)
      : const Color(0xFFDDE1E8);

  // ============ Couleurs de texte ============
  // Light mode: textes plus foncés pour meilleur contraste
  Color get textPrimary => isDarkMode
      ? const Color(0xFFE8EAF0)
      : const Color(0xFF0F172A);  // Presque noir

  Color get textSecondary => isDarkMode
      ? const Color(0xFF9BA3B4)
      : const Color(0xFF475569);  // Gris foncé

  Color get textMuted => isDarkMode
      ? const Color(0xFF6B7280)
      : const Color(0xFF64748B);

  Color get textInverse => isDarkMode
      ? const Color(0xFF0F1419)
      : const Color(0xFFFFFFFF);

  // ============ Couleurs de bordure ============
  // Light mode: bordures plus visibles
  Color get borderPrimary => isDarkMode
      ? const Color(0xFF2D3548)
      : const Color(0xFFCBD5E1);  // Plus visible

  Color get borderSecondary => isDarkMode
      ? const Color(0xFF3E4555)
      : const Color(0xFFB0BCC9);  // Plus foncé

  Color get borderFocus => isDarkMode
      ? const Color(0xFF5B7FFF)
      : const Color(0xFF4361EE);

  // ============ Couleurs sémantiques ============
  // Light mode: couleurs plus saturées
  Color get success => isDarkMode
      ? const Color(0xFF10B981)
      : const Color(0xFF059669);  // Plus foncé

  Color get successBg => isDarkMode
      ? const Color(0xFF064E3B)
      : const Color(0xFFD1FAE5);

  Color get error => isDarkMode
      ? const Color(0xFFEF4444)
      : const Color(0xFFDC2626);  // Plus foncé

  Color get errorBg => isDarkMode
      ? const Color(0xFF7F1D1D)
      : const Color(0xFFFEE2E2);

  Color get warning => isDarkMode
      ? const Color(0xFFF59E0B)
      : const Color(0xFFD97706);  // Plus foncé

  Color get warningBg => isDarkMode
      ? const Color(0xFF78350F)
      : const Color(0xFFFEF3C7);

  Color get info => isDarkMode
      ? const Color(0xFF3B82F6)
      : const Color(0xFF2563EB);  // Plus foncé

  Color get infoBg => isDarkMode
      ? const Color(0xFF1E3A8A)
      : const Color(0xFFDBEAFE);

  // ============ Aliases ============
  Color get background => bgPrimary;
  Color get surface => bgSecondary;
  Color get divider => borderPrimary;

  // ============ Constantes statiques (rétrocompatibilité - utilisent dark par défaut) ============
  // Ces constantes permettent d'utiliser AppColors.primary etc. sans contexte
  // Pour un support complet du thème, utiliser context.colors à la place

  static const Color primaryStatic = Color(0xFF5B7FFF);
  static const Color primaryLightStatic = Color(0xFF7A9AFF);
  static const Color primaryDarkStatic = Color(0xFF4563D9);

  static const Color secondaryStatic = Color(0xFF8B5CF6);
  static const Color secondaryLightStatic = Color(0xFFA78BFA);
  static const Color secondaryDarkStatic = Color(0xFF7C3AED);

  static const Color bgPrimaryStatic = Color(0xFF0F1419);
  static const Color bgSecondaryStatic = Color(0xFF1A1F2E);
  static const Color bgTertiaryStatic = Color(0xFF252B3B);
  static const Color bgHoverStatic = Color(0xFF2D3548);

  static const Color textPrimaryStatic = Color(0xFFE8EAF0);
  static const Color textSecondaryStatic = Color(0xFF9BA3B4);
  static const Color textMutedStatic = Color(0xFF6B7280);
  static const Color textInverseStatic = Color(0xFF0F1419);

  static const Color borderPrimaryStatic = Color(0xFF2D3548);
  static const Color borderSecondaryStatic = Color(0xFF3E4555);
  static const Color borderFocusStatic = Color(0xFF5B7FFF);

  static const Color successStatic = Color(0xFF10B981);
  static const Color successBgStatic = Color(0xFF064E3B);
  static const Color errorStatic = Color(0xFFEF4444);
  static const Color errorBgStatic = Color(0xFF7F1D1D);
  static const Color warningStatic = Color(0xFFF59E0B);
  static const Color warningBgStatic = Color(0xFF78350F);
  static const Color infoStatic = Color(0xFF3B82F6);
  static const Color infoBgStatic = Color(0xFF1E3A8A);
}

/// Extension pour accéder facilement aux couleurs depuis le contexte
extension AppColorsExtension on BuildContext {
  AppColors get colors => AppColors.of(this);
}

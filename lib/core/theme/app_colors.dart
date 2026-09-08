import 'package:flutter/material.dart';

/// Charte de couleurs « AV Pointage » — direction *soft & chaleureux*.
///
/// Principes :
/// - Fond bleu-gris chaud (jamais gris froid pur), surfaces blanches en relief
///   par l'OMBRE et non par la bordure.
/// - Bleu AVTRANS retravaillé (#2D5BFF) comme couleur de marque.
/// - Chaque domaine métier possède un accent + un fond doux assorti.
/// - Dark mode : élévation par surfaces plus claires (jamais de noir pur),
///   ombres quasi nulles.
///
/// Tous les getters/alias historiques sont conservés pour une migration
/// progressive des écrans.
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
      ? const Color(0xFF121316) // dark chaud — jamais #000 pur
      : const Color(0xFFF6F7FB); // bleu-gris très doux, chaleureux

  Color get foreground => isDarkMode
      ? const Color(0xFFE9EBF0) // ~91% — jamais #FFF pur
      : const Color(0xFF0F172A); // slate-900, moins dur que le quasi-noir

  // ============ Card (surface en relief) ============
  Color get card => isDarkMode
      ? const Color(0xFF1D1F24) // surface élevée 1
      : const Color(0xFFFFFFFF);

  Color get cardForeground => foreground;

  /// Surface plus élevée encore (sheets, popovers, éléments flottants).
  Color get surfaceElevated => isDarkMode
      ? const Color(0xFF26282F)
      : const Color(0xFFFFFFFF);

  /// Surface « enfoncée » : champs, pills, fonds de section, segmented.
  Color get surfaceSunken => isDarkMode
      ? const Color(0xFF17181C)
      : const Color(0xFFEEF1F8);

  // ============ Popover ============
  Color get popover => surfaceElevated;
  Color get popoverForeground => foreground;

  // ============ Primary (bleu AVTRANS) ============
  Color get primary => isDarkMode
      ? const Color(0xFF5B7FFF) // plus lumineux sur fond sombre
      : const Color(0xFF2D5BFF); // bleu AVTRANS retravaillé

  Color get primaryForeground => const Color(0xFFFFFFFF);

  Color get primaryLight => isDarkMode
      ? const Color(0xFF8AA3FF)
      : const Color(0xFF5B7FFF);

  /// Fond doux pour éléments « primary » discrets (chips, badges, halos).
  Color get primarySoft => isDarkMode
      ? const Color(0xFF1F2740)
      : const Color(0xFFE6ECFF);

  // ============ Secondary ============
  Color get secondary => surfaceSunken;
  Color get secondaryForeground => isDarkMode
      ? const Color(0xFFE9EBF0)
      : const Color(0xFF1E293B);

  // ============ Muted ============
  Color get muted => surfaceSunken;
  Color get mutedForeground => isDarkMode
      ? const Color(0xFF9AA1AE)
      : const Color(0xFF64748B); // slate-500

  // ============ Accent ============
  Color get accent => surfaceSunken;
  Color get accentForeground => secondaryForeground;

  // ============ Destructive ============
  Color get destructive => isDarkMode
      ? const Color(0xFFF26269)
      : const Color(0xFFE5484D); // rouge plus doux que red-600

  Color get destructiveForeground => const Color(0xFFFFFFFF);

  // ============ Border & Input ============
  Color get border => isDarkMode
      ? const Color(0xFF2C2F37) // séparation discrète en dark
      : const Color(0xFFE7EAF1); // très léger — l'ombre fait le travail

  Color get input => border;

  // ============ Ring (focus) ============
  Color get ring => primary;

  // ============ Semantic Colors ============
  Color get success => isDarkMode
      ? const Color(0xFF1FB880)
      : const Color(0xFF0E9F6E); // émeraude

  Color get successForeground => const Color(0xFFFFFFFF);

  Color get successMuted => isDarkMode
      ? const Color(0xFF10271F)
      : const Color(0xFFE3F5EE);

  Color get warning => isDarkMode
      ? const Color(0xFFFBBF24)
      : const Color(0xFFF59E0B); // ambre

  Color get warningForeground => isDarkMode
      ? const Color(0xFF0F172A)
      : const Color(0xFF7A4E03);

  Color get warningMuted => isDarkMode
      ? const Color(0xFF2C2208)
      : const Color(0xFFFEF3DD);

  Color get info => isDarkMode
      ? const Color(0xFF38BDF8)
      : const Color(0xFF0EA5C4); // teal/sky

  Color get infoForeground => const Color(0xFFFFFFFF);

  Color get infoMuted => isDarkMode
      ? const Color(0xFF0A2A33)
      : const Color(0xFFDEF4F9);

  // ============ Couleurs de domaine (accent + fond doux) ============
  // Chaque univers métier a son identité — utilisées dans les cartes,
  // icônes, accents de liste, mini-charts.

  Color get domainPointage => primary;
  Color get domainPointageSoft => primarySoft;

  Color get domainHours => success;
  Color get domainHoursSoft => successMuted;

  Color get domainAbsence => warning;
  Color get domainAbsenceSoft => warningMuted;

  Color get domainAcompte => isDarkMode
      ? const Color(0xFF9D86FF)
      : const Color(0xFF7C5CFC); // violet doux
  Color get domainAcompteSoft => isDarkMode
      ? const Color(0xFF221C3A)
      : const Color(0xFFEFEAFE);

  Color get domainYpsium => info;
  Color get domainYpsiumSoft => infoMuted;

  Color get domainVehicule => isDarkMode
      ? const Color(0xFF94A3B8)
      : const Color(0xFF475569); // slate
  Color get domainVehiculeSoft => isDarkMode
      ? const Color(0xFF22262E)
      : const Color(0xFFEBEEF3);

  // ============ Chart Colors (alignées sur les domaines) ============
  Color get chart1 => domainPointage;
  Color get chart2 => domainHours;
  Color get chart3 => domainAbsence;
  Color get chart4 => domainAcompte;
  Color get chart5 => domainYpsium;

  // ============ Ombres (élévation douce) ============
  /// Ombre standard d'une carte. Quasi nulle en dark (on s'appuie sur la
  /// surface plus claire), diffuse et basse en light.
  List<BoxShadow> get cardShadow => isDarkMode
      ? const []
      : const [
          BoxShadow(
            color: Color(0x0F1E293B), // ~6%
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ];

  /// Ombre marquée pour les éléments « hero » (carte de pointage, FAB).
  List<BoxShadow> get heroShadow => isDarkMode
      ? const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x141E293B), // ~8%
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ];

  /// Ombre de la barre de navigation basse (vers le haut).
  List<BoxShadow> get navShadow => isDarkMode
      ? const []
      : const [
          BoxShadow(
            color: Color(0x0F1E293B),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ];

  // ============ Verre liquide (tab bar flottante iOS) ============
  /// Fond translucide du verre (posé sur un BackdropFilter flou + saturé).
  Color get glassSurface => isDarkMode
      ? const Color(0xA61D1F24) // card ~65 %
      : const Color(0x9EFFFFFF); // blanc ~62 %

  /// Reflet spéculaire sur le bord du verre (intensité max du dégradé).
  Color get glassRim => isDarkMode
      ? const Color(0x47FFFFFF) // blanc 28 %
      : const Color(0xF2FFFFFF); // blanc 95 %

  /// Pastille derrière l'onglet actif.
  Color get glassSelected => isDarkMode
      ? const Color(0x24FFFFFF) // blanc 14 %
      : const Color(0xF0FFFFFF); // blanc 94 %

  /// Ombre douce de la pastille active (light uniquement).
  List<BoxShadow> get glassSelectedShadow => isDarkMode
      ? const []
      : const [
          BoxShadow(
            color: Color(0x1A1E293B), // ~10 %
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ];

  /// Ombre portée de la barre. Dessinée uniquement à l'extérieur de la forme
  /// (`BlurStyle.outer`) pour ne pas assombrir le verre translucide.
  List<BoxShadow> get glassNavShadow => isDarkMode
      ? const []
      : const [
          BoxShadow(
            color: Color(0x1F1E293B), // ~12 %
            blurRadius: 24,
            offset: Offset(0, 8),
            blurStyle: BlurStyle.outer,
          ),
        ];

  // ============ Aliases (compat ascendante) ============
  Color get bgPrimary => background;
  Color get bgSecondary => card;
  Color get bgTertiary => surfaceSunken;
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
      ? const Color(0xFF2E1213)
      : const Color(0xFFFCEBEC);
  Color get successBg => successMuted;
  Color get warningBg => warningMuted;
  Color get infoBg => infoMuted;
  Color get surface => card;
  Color get divider => border;

  // ============ Disabled ============
  Color get disabled => isDarkMode
      ? const Color(0xFF5A5E68)
      : const Color(0xFFAEB6C2);

  // ============ Static compat ============
  static const Color primaryStatic = Color(0xFF2D5BFF);
  static const Color primaryLightStatic = Color(0xFF5B7FFF);
  static const Color primaryDarkStatic = Color(0xFF2D5BFF);
  static const Color secondaryStatic = Color(0xFF7C5CFC);
  static const Color secondaryLightStatic = Color(0xFF9D86FF);
  static const Color secondaryDarkStatic = Color(0xFF7C5CFC);
  static const Color bgPrimaryStatic = Color(0xFF121316);
  static const Color bgSecondaryStatic = Color(0xFF1D1F24);
  static const Color bgTertiaryStatic = Color(0xFF17181C);
  static const Color bgHoverStatic = Color(0xFF26282F);
  static const Color textPrimaryStatic = Color(0xFFE9EBF0);
  static const Color textSecondaryStatic = Color(0xFF9AA1AE);
  static const Color textMutedStatic = Color(0xFF5A5E68);
  static const Color textInverseStatic = Color(0xFF121316);
  static const Color borderPrimaryStatic = Color(0xFF2C2F37);
  static const Color borderSecondaryStatic = Color(0xFF2C2F37);
  static const Color borderFocusStatic = Color(0xFF5B7FFF);
  static const Color successStatic = Color(0xFF1FB880);
  static const Color successBgStatic = Color(0xFF10271F);
  static const Color errorStatic = Color(0xFFF26269);
  static const Color errorBgStatic = Color(0xFF2E1213);
  static const Color warningStatic = Color(0xFFFBBF24);
  static const Color warningBgStatic = Color(0xFF2C2208);
  static const Color infoStatic = Color(0xFF38BDF8);
  static const Color infoBgStatic = Color(0xFF0A2A33);
}

/// Extension pour accéder aux couleurs depuis le contexte
extension AppColorsExtension on BuildContext {
  AppColors get colors => AppColors.of(this);
}

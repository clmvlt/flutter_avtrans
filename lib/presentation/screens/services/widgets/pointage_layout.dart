/// Constantes de mise en page propres à la page Pointage (les espacements,
/// rayons et couleurs génériques restent dans le thème).
abstract final class PointageLayout {
  /// Largeur max du contenu (tablette / paysage).
  static const double maxContentWidth = 480;

  /// Ruban de journée : piste, trait de pause, étendue minimale.
  static const double ribbonHeight = 12;
  static const double ribbonPauseHeight = 6;
  static const Duration ribbonMinSpan = Duration(hours: 1);

  /// Fil de la journée.
  static const double timeColumnWidth = 52;
  static const double railWidth = 24;
  static const double dotSize = 12;
  static const double rowMinHeight = 56;
  static const double gapRowHeight = 32;

  /// Boîtes d'icône (hero, checklist).
  static const double iconBoxSize = 44;
  static const double prereqIconBoxSize = 40;

  /// Dock : repli des deux boutons en colonne.
  static const double stackedButtonsTextScale = 1.2;
  static const double stackedButtonsMinWidth = 340;

  /// Dock : hauteur du fondu sous lequel le contenu s'estompe, et écart entre
  /// les boutons et la tab bar en verre. L'écart est volontairement large :
  /// à 8 dp, bouton et capsule se lisaient comme deux barres empilées.
  static const double dockFadeHeight = 24;
  static const double dockToTabBarGap = 24;
}

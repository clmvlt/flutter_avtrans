import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Niveau d'élévation visuelle d'une [AppCard].
enum AppCardElevation {
  /// Aucune ombre — carte « à plat » (ex. liste sur fond clair).
  flat,

  /// Ombre douce standard.
  raised,

  /// Ombre marquée pour les éléments « hero ».
  hero,
}

/// Carte standard de l'app — direction *soft & chaleureux*.
///
/// Remplace les `Container( decoration: BoxDecoration(border: Border.all...) )`
/// dupliqués : ici la profondeur vient de l'OMBRE, pas de la bordure.
///
/// ```dart
/// AppCard(
///   onTap: _open,
///   child: Text('Bonjour'),
/// )
/// ```
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.base),
    this.onTap,
    this.onLongPress,
    this.color,
    this.radius = AppRadius.lg,
    this.elevation = AppCardElevation.raised,
    this.border = false,
    this.gradient,
    this.clip = false,
    this.width,
    this.splashColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Couleur de fond — par défaut `colors.card`.
  final Color? color;
  final double radius;
  final AppCardElevation elevation;

  /// Forcer une bordure discrète (utile sur fond coloré identique).
  final bool border;

  final Gradient? gradient;

  /// Rogner le contenu au rayon de la carte (ex. images en bord).
  final bool clip;
  final double? width;
  final Color? splashColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(radius);

    final shadows = switch (elevation) {
      AppCardElevation.flat => const <BoxShadow>[],
      AppCardElevation.raised => colors.cardShadow,
      AppCardElevation.hero => colors.heroShadow,
    };

    // En dark, on garde toujours une fine bordure pour séparer les surfaces.
    final showBorder = border || colors.isDarkMode;

    Widget content = Padding(padding: padding, child: child);

    if (onTap != null || onLongPress != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: borderRadius,
          splashColor: splashColor ?? colors.primary.withValues(alpha: 0.06),
          highlightColor: colors.primary.withValues(alpha: 0.03),
          child: content,
        ),
      );
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? colors.card) : null,
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: shadows,
        border: showBorder ? Border.all(color: colors.border) : null,
      ),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: content,
    );
  }
}

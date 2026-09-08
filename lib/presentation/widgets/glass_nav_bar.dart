import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Barre de navigation basse « verre dépoli », façon iOS.
///
/// Pilule flottante détachée des bords (marge latérale + espace sous la
/// barre), fond translucide et flou du contenu qui défile derrière.
///
/// À utiliser avec `Scaffold(extendBody: true)` : le corps passe sous la
/// barre, et chaque écran réserve `MediaQuery.paddingOf(context).bottom`
/// en bas de ses listes pour que le dernier élément reste visible.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  /// Marge latérale de la pilule.
  static const double horizontalMargin = AppSpacing.base;

  /// Espace entre la pilule et le bord bas (en plus de la zone système).
  static const double bottomGap = AppSpacing.sm;

  /// Intensité du flou d'arrière-plan.
  static const double blurSigma = 24;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final padding = MediaQuery.paddingOf(context);
    final radius = BorderRadius.circular(AppRadius.full);

    // Les insets système sont gérés ici (marges) : on les retire du
    // MediaQuery pour que NavigationBar, qui embarque son propre SafeArea,
    // ne les ré-applique pas à l'intérieur de la pilule.
    return MediaQuery.removePadding(
      context: context,
      removeLeft: true,
      removeRight: true,
      removeBottom: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalMargin + padding.left,
          0,
          horizontalMargin + padding.right,
          bottomGap + padding.bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: colors.glassNavShadow,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.glassSurface,
                  borderRadius: radius,
                  border: Border.all(color: colors.glassBorder),
                ),
                child: NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  backgroundColor: Colors.transparent,
                  destinations: destinations,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

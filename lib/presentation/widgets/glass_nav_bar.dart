import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Tab bar « verre liquide », fidèle à la barre d'onglets iOS 26.
///
/// - Capsule flottante détachée des bords (marge latérale + espace sous la
///   barre, au-dessus de la zone système).
/// - Fond en verre : le contenu qui défile derrière est flouté et saturé,
///   avec un reflet dégradé sur le bord.
/// - Pastille glissante derrière l'onglet actif, icône + libellé teintés
///   dans la couleur primaire.
/// - Aucun composant Material : pas de ripple, pas d'indicateur M3.
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

  /// Hauteur de la capsule.
  static const double height = 64;

  /// Marge latérale de la capsule.
  static const double horizontalMargin = AppSpacing.base;

  /// Espace entre la capsule et le bord bas (en plus de la zone système).
  static const double bottomGap = AppSpacing.sm;

  /// Retrait de la pastille active par rapport aux bords de la capsule.
  static const EdgeInsets pillInset =
      EdgeInsets.symmetric(horizontal: 4, vertical: 5);

  /// Largeur max de la pastille (évite une pastille géante sur tablette).
  static const double pillMaxWidth = 96;

  /// Flou et saturation du verre.
  static const double blurSigma = 30;
  static const double saturation = 1.4;

  /// Flou + saturation : c'est la saturation qui donne au verre iOS son
  /// aspect « vibrant » plutôt que laiteux.
  static ImageFilter _glassFilter() {
    const s = saturation;
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    const sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
    const matrix = <double>[
      sr + s, sg, sb, 0, 0, //
      sr, sg + s, sb, 0, 0, //
      sr, sg, sb + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
    return ImageFilter.compose(
      outer: ImageFilter.blur(
        sigmaX: blurSigma,
        sigmaY: blurSigma,
        tileMode: TileMode.mirror,
      ),
      inner: const ColorFilter.matrix(matrix),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final padding = MediaQuery.paddingOf(context);
    final radius = BorderRadius.circular(height / 2);

    // Pas d'ombre portée : sur iPhone elle se rendait comme une seconde
    // capsule grise sous la barre. Le bord peint délimite seul la capsule.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalMargin + padding.left,
        0,
        horizontalMargin + padding.right,
        bottomGap + padding.bottom,
      ),
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: _glassFilter(),
            child: CustomPaint(
              foregroundPainter: _GlassRimPainter(color: colors.glassRim),
              child: ColoredBox(
                color: colors.glassSurface,
                child: _Tabs(
                  selectedIndex: selectedIndex,
                  onSelected: onDestinationSelected,
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

/// Pastille glissante + rangée d'onglets.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const inset = GlassNavBar.pillInset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth =
            (constraints.maxWidth - inset.horizontal) / destinations.length;
        final pillWidth = math.min(slotWidth, GlassNavBar.pillMaxWidth);
        final pillLeft = inset.left +
            slotWidth * selectedIndex +
            (slotWidth - pillWidth) / 2;

        return Stack(
          children: [
            // Pastille active : glisse d'un onglet à l'autre.
            AnimatedPositioned(
              duration: AppDuration.slow,
              curve: Curves.easeOutCubic,
              left: pillLeft,
              top: inset.top,
              width: pillWidth,
              height: constraints.maxHeight - inset.vertical,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.glassSelected,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: inset.left),
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _Tab(
                        destination: destinations[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Un onglet : icône (contour → pleine) au-dessus d'un libellé compact.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.primary : colors.mutedForeground;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: AppDuration.fast,
              child: IconTheme(
                key: ValueKey<bool>(selected),
                data: IconThemeData(size: 24, color: color),
                child: selected
                    ? (destination.selectedIcon ?? destination.icon)
                    : destination.icon,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: AppDuration.fast,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
                height: 1.1,
                letterSpacing: -0.1,
              ),
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bord du verre : trait de 1 px en léger dégradé, un peu plus marqué en haut
/// à gauche qu'en bas à droite, comme la lumière qui accroche le verre. Sans
/// ombre portée, c'est lui qui délimite la capsule sur un fond uni.
class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color,
          color.withValues(alpha: color.a * 0.6),
          color.withValues(alpha: color.a * 0.85),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(0.5),
        Radius.circular(size.height / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GlassRimPainter oldDelegate) =>
      oldDelegate.color != color;
}

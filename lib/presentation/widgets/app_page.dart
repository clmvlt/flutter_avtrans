import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Gabarit commun des pages, tiré de la page Pointage : une colonne de
/// contenu de 480 dp max centrée, 20 dp de marge d'écran, des lignes de
/// 56 dp et des boîtes d'icône teintées.
abstract final class AppLayout {
  /// Largeur max de la colonne de contenu (tablette / paysage).
  static const double contentMaxWidth = 480;

  /// Hauteur minimale d'une ligne tapable.
  static const double rowMinHeight = 56;

  /// Boîte d'icône d'une ligne, et celle d'une carte hero.
  static const double iconBox = 40;
  static const double heroIconBox = 44;

  /// Marge horizontale qui centre la colonne de contenu dans [width].
  static double sidePadding(double width) =>
      math.max(AppSpacing.screen, (width - contentMaxWidth) / 2);
}

/// Page standard : fond `background`, barre de titre à gauche avec ses
/// actions en icônes, corps (généralement [AppScrollView] ou [AppListView])
/// et dock d'action optionnel dans la zone du pouce ([AppDock]).
///
/// Avec un dock, le corps passe dessous (`extendBody`) : le fondu du dock
/// remplace tout bord dur, et les corps standard réservent sa hauteur.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.dock,
    this.bottom,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final Widget body;

  /// Actions de la barre de titre, en [AppIconButton] (couleur `foreground`).
  final List<Widget> actions;

  /// Dock d'action persistant ([AppDock]).
  final Widget? dock;

  /// Contenu fixé sous le titre (ex. [AppSegmented] dans un [AppPageBar]).
  final PreferredSizeWidget? bottom;
  final Widget? leading;

  /// `false` : pas de flèche retour automatique (écran bloquant).
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      extendBody: dock != null,
      appBar: AppBar(
        title: Text(title),
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: actions.isEmpty
            ? null
            : [...actions, const SizedBox(width: AppSpacing.xs)],
        bottom: bottom,
      ),
      body: body,
      bottomNavigationBar: dock,
    );
  }
}

/// Bande fixée sous la barre de titre (segments, recherche), alignée sur la
/// colonne de contenu.
class AppPageBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageBar({super.key, required this.child, this.height = 60});

  final Widget child;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = AppLayout.sidePadding(constraints.maxWidth);
        return Padding(
          padding: EdgeInsets.fromLTRB(side, 0, side, AppSpacing.md),
          child: Align(alignment: Alignment.topCenter, child: child),
        );
      },
    );
  }
}

/// Corps défilant standard : colonne centrée (480 dp max), marges d'écran,
/// bas réservé au dock et à la tab bar (`paddingOf.bottom`), tirer pour
/// rafraîchir si [onRefresh] est fourni.
class AppScrollView extends StatelessWidget {
  const AppScrollView({
    super.key,
    required this.children,
    this.onRefresh,
    this.controller,
    this.topPadding = AppSpacing.md,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final double topPadding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final padding = MediaQuery.paddingOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = AppLayout.sidePadding(constraints.maxWidth);
        Widget view = SingleChildScrollView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            side + padding.left,
            topPadding,
            side + padding.right,
            AppSpacing.lg + padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        );
        if (onRefresh != null) {
          view = RefreshIndicator(
            onRefresh: onRefresh!,
            color: colors.primary,
            backgroundColor: colors.card,
            child: view,
          );
        }
        return view;
      },
    );
  }
}

/// Variante paresseuse d'[AppScrollView] pour les longues listes : un
/// en-tête fixe ([header]), puis [itemCount] éléments construits à la
/// demande, puis un pied optionnel (ex. « Charger plus »).
class AppListView extends StatelessWidget {
  const AppListView({
    super.key,
    this.header = const [],
    required this.itemCount,
    required this.itemBuilder,
    this.footer,
    this.onRefresh,
    this.controller,
    this.topPadding = AppSpacing.md,
    this.itemSpacing = AppSpacing.md,
  });

  final List<Widget> header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? footer;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final double topPadding;

  /// Espace vertical entre deux éléments.
  final double itemSpacing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final padding = MediaQuery.paddingOf(context);
    final total = header.length + itemCount + (footer != null ? 1 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = AppLayout.sidePadding(constraints.maxWidth);
        Widget view = ListView.builder(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            side + padding.left,
            topPadding,
            side + padding.right,
            AppSpacing.lg + padding.bottom,
          ),
          itemCount: total,
          itemBuilder: (context, index) {
            if (index < header.length) return header[index];
            final i = index - header.length;
            if (i < itemCount) {
              return Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : itemSpacing),
                child: itemBuilder(context, i),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.base),
              child: footer,
            );
          },
        );
        if (onRefresh != null) {
          view = RefreshIndicator(
            onRefresh: onRefresh!,
            color: colors.primary,
            backgroundColor: colors.card,
            child: view,
          );
        }
        return view;
      },
    );
  }
}

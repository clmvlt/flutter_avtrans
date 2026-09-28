import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_page.dart';

/// Gabarit des écrans d'authentification (connexion, inscription, attente
/// d'activation), dans la langue de la page Pointage : fond calme
/// `background`, colonne de 480 dp max centrée, marges d'écran de 20 dp.
///
/// - Sans [title] ni [showBack] : pas de barre de titre (connexion).
/// - [centered] : le contenu est centré verticalement tant qu'il tient dans
///   l'écran, et défile sinon (clavier ouvert à 360 dp).
/// - [busy] : une action est en vol, le contenu ignore les taps (remplace
///   l'ancien `LoadingOverlay` ; le bouton concerné porte le spinner).
/// - [dock] : dock d'action persistant ([AppDock]) pour les écrans d'état.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    this.title,
    this.showBack = false,
    this.centered = true,
    this.busy = false,
    this.dock,
  });

  final List<Widget> children;

  /// Titre de la barre, à gauche comme sur les autres pages.
  final String? title;

  /// Flèche de retour dans la barre (écran poussé).
  final bool showBack;
  final bool centered;
  final bool busy;
  final Widget? dock;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasBar = title != null || showBack;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: colors.background,
      // Avec un dock, le contenu passe dessous : son fondu remplace tout bord
      // dur, et le corps réserve sa hauteur (`paddingOf.bottom`). Clavier
      // ouvert, le dock remonte au-dessus et le corps s'arrête à lui
      // (comme AppPage).
      extendBody: dock != null && !keyboardOpen,
      appBar: hasBar
          ? AppBar(
              title: title == null ? null : Text(title!),
              automaticallyImplyLeading: showBack,
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = AppLayout.sidePadding(constraints.maxWidth);
            final top = hasBar ? AppSpacing.md : AppSpacing.lg;
            final bottom = AppSpacing.lg + MediaQuery.paddingOf(context).bottom;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(side, top, side, bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - top - bottom),
                ),
                child: AbsorbPointer(
                  absorbing: busy,
                  child: Column(
                    mainAxisAlignment: centered
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: dock,
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_alert.dart';
import 'app_button.dart';
import 'app_page.dart';
import 'app_skeleton.dart';

/// Tonalité d'un bouton du dock.
enum DockTone {
  /// Prochaine étape, action principale de la page : bleu marque.
  primary,

  /// Démarrer / reprendre / valider : vert.
  success,

  /// Action réversible (pause) : ambre doux, texte foncé.
  soft,

  /// Action de clôture ou destructive : rouge, protégée par une feuille.
  danger,

  /// Action calme (réessayer, annuler) : surface enfoncée.
  secondary,
}

/// Un bouton du dock.
class DockAction {
  const DockAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = DockTone.primary,
    this.isLoading = false,
    this.semanticsHint,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final DockTone tone;

  /// Cette action est en vol : spinner à la place de l'icône.
  final bool isLoading;
  final String? semanticsHint;
}

/// Message inline du dock (erreur d'action, confirmation).
class DockNotice {
  const DockNotice({required this.text, required this.variant});

  final String text;
  final AlertVariant variant;
}

/// Texte lisible sur `warningMuted` : ambre foncé en clair, ambre clair en
/// sombre (`warningForeground` est illisible sur `warningMuted` en dark).
Color onWarningMuted(AppColors c) =>
    c.isDarkMode ? c.warning : c.warningForeground;

/// Dock d'action persistant, à passer à `AppPage.dock` (ou au slot
/// `bottomNavigationBar` d'un `Scaffold(extendBody: true)`).
///
/// Jamais une seconde barre : pas de carte, pas d'ombre, pas de trait. Le
/// contenu qui défile s'estompe sous un fondu vers `background`. Empile :
/// fondu · notice inline (optionnelle) · ligne d'état (optionnelle) · un ou
/// deux `AppButton lg` (56 dp) dont le libellé dit l'action.
///
/// Sans bouton, sans notice et sans ligne d'état, le dock ne rend rien.
/// Il réserve lui-même `paddingOf.bottom + bottomGap` sous les boutons.
///
/// Clavier ouvert (`viewInsets.bottom` visible, page du Navigator racine) :
/// le dock remonte juste au-dessus pour que son bouton reste tapable (le
/// pavé numérique iOS n'a pas de touche pour se fermer), sans fondu ;
/// [AppPage] arrête alors le corps au-dessus du dock. Dans l'onglet Ypsium,
/// la coquille a déjà réduit la page au-dessus du clavier.
class AppDock extends StatelessWidget {
  const AppDock({
    super.key,
    this.actions = const [],
    this.status,
    this.notice,
    this.onDismissNotice,
    this.absorbing = false,
    this.skeleton = false,
    this.bottomGap = AppSpacing.md,
  });

  /// Un ou deux boutons.
  final List<DockAction> actions;

  /// Ligne d'état au-dessus des boutons (ex. position GPS).
  final Widget? status;
  final DockNotice? notice;
  final VoidCallback? onDismissNotice;

  /// Une action est en vol : le dock ignore les taps.
  final bool absorbing;

  /// Premier chargement : squelette à la place des boutons.
  final bool skeleton;

  /// Écart sous les boutons (24 dp au-dessus de la tab bar en verre).
  final double bottomGap;

  bool get _isEmpty =>
      actions.isEmpty && notice == null && status == null && !skeleton;

  @override
  Widget build(BuildContext context) {
    if (_isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final background = colors.background;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = keyboard > 0
        ? keyboard + AppSpacing.md
        : MediaQuery.paddingOf(context).bottom + bottomGap;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fondu transparent aux gestes : ce qui est visible dessous reste
        // tapable.
        if (keyboard == 0)
          IgnorePointer(
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [background.withValues(alpha: 0), background],
                ),
              ),
            ),
          ),
        ColoredBox(
          color: background,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.sm,
              AppSpacing.screen,
              bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.contentMaxWidth,
                ),
                child: AbsorbPointer(
                  absorbing: absorbing,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSize(
                        duration: AppDuration.base,
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: notice == null
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: EdgeInsets.only(
                                  bottom: actions.isEmpty && status == null
                                      ? 0
                                      : AppSpacing.sm,
                                ),
                                child: GestureDetector(
                                  onTap: onDismissNotice,
                                  child: AppAlert(
                                    variant: notice!.variant,
                                    description: notice!.text,
                                  ),
                                ),
                              ),
                      ),
                      if (status != null) ...[
                        status!,
                        if (actions.isNotEmpty || skeleton)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                      AnimatedSize(
                        duration: AppDuration.base,
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: skeleton
                            ? const AppSkeleton(
                                height: 56,
                                borderRadius: AppRadius.lg,
                              )
                            : DockButtons(actions: actions),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Un ou deux `AppButton lg` ; deux boutons se partagent la largeur à parts
/// égales (gap 12 dp) et s'empilent quand le texte est agrandi ou l'écran
/// étroit.
class DockButtons extends StatelessWidget {
  const DockButtons({super.key, required this.actions});

  final List<DockAction> actions;

  static const double _stackedTextScale = 1.2;
  static const double _stackedMinWidth = 340;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox(width: double.infinity);
    if (actions.length == 1) return _button(context, actions.first);

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final stacked = scale > _stackedTextScale ||
            constraints.maxWidth < _stackedMinWidth ||
            !_labelsFit(context, constraints.maxWidth);
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                _button(context, actions[i]),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              Expanded(child: _button(context, actions[i], compact: true)),
            ],
          ],
        );
      },
    );
  }

  /// Chaque libellé tient-il en entier dans une moitié du dock (icône,
  /// écart et marges compris) ? Sinon on empile plutôt que de tronquer.
  bool _labelsFit(BuildContext context, double maxWidth) {
    final half = (maxWidth - AppSpacing.md) / 2;
    const style = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    );
    final scaler = MediaQuery.textScalerOf(context);
    for (final a in actions) {
      final painter = TextPainter(
        text: TextSpan(text: a.label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      // Icône 22 + écart 8 + marges 2 × 16.
      final needed = painter.width + 22 + 8 + 2 * AppSpacing.base;
      painter.dispose();
      if (needed > half) return false;
    }
    return true;
  }

  Widget _button(BuildContext context, DockAction a, {bool compact = false}) {
    final colors = context.colors;
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 12)
        : null;

    final button = switch (a.tone) {
      DockTone.primary => AppButton(
          text: a.label,
          icon: a.icon,
          onPressed: a.onPressed,
          isLoading: a.isLoading,
          size: ButtonSize.lg,
          padding: padding,
        ),
      DockTone.success => AppButton(
          text: a.label,
          icon: a.icon,
          onPressed: a.onPressed,
          isLoading: a.isLoading,
          size: ButtonSize.lg,
          padding: padding,
          backgroundColor: colors.success,
          foregroundColor: colors.successForeground,
        ),
      DockTone.soft => AppButton(
          text: a.label,
          icon: a.icon,
          onPressed: a.onPressed,
          isLoading: a.isLoading,
          size: ButtonSize.lg,
          padding: padding,
          backgroundColor: colors.warningMuted,
          foregroundColor: onWarningMuted(colors),
        ),
      DockTone.danger => AppButton(
          text: a.label,
          icon: a.icon,
          onPressed: a.onPressed,
          isLoading: a.isLoading,
          size: ButtonSize.lg,
          padding: padding,
          isDanger: true,
        ),
      DockTone.secondary => AppButton(
          text: a.label,
          icon: a.icon,
          onPressed: a.onPressed,
          isLoading: a.isLoading,
          size: ButtonSize.lg,
          padding: padding,
          variant: ButtonVariant.secondary,
        ),
    };

    return Semantics(
      button: true,
      enabled: a.onPressed != null && !a.isLoading,
      label: a.label,
      hint: a.semanticsHint,
      excludeSemantics: true,
      child: button,
    );
  }
}

/// Gère la notice éphémère d'un dock : `showDockError` / `showDockSuccess`
/// l'affichent puis la masquent seules ; un tap la ferme (`clearDockNotice`).
///
/// ```dart
/// class _MyPageState extends State<MyPage> with DockNoticeMixin {
///   ...
///   dock: AppDock(notice: dockNotice, onDismissNotice: clearDockNotice, ...)
/// }
/// ```
mixin DockNoticeMixin<T extends StatefulWidget> on State<T> {
  DockNotice? _dockNotice;
  Timer? _dockNoticeTimer;

  DockNotice? get dockNotice => _dockNotice;

  void showDockNotice(
    String text, {
    AlertVariant variant = AlertVariant.destructive,
    Duration duration = const Duration(seconds: 6),
  }) {
    if (!mounted) return;
    _dockNoticeTimer?.cancel();
    setState(() => _dockNotice = DockNotice(text: text, variant: variant));
    _dockNoticeTimer = Timer(duration, clearDockNotice);
  }

  void showDockError(String text) => showDockNotice(text);

  void showDockSuccess(String text) => showDockNotice(
        text,
        variant: AlertVariant.success,
        duration: const Duration(seconds: 4),
      );

  void clearDockNotice() {
    _dockNoticeTimer?.cancel();
    _dockNoticeTimer = null;
    if (_dockNotice != null && mounted) setState(() => _dockNotice = null);
  }

  @override
  void dispose() {
    _dockNoticeTimer?.cancel();
    super.dispose();
  }
}

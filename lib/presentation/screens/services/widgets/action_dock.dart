import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_alert.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_skeleton.dart';
import 'pointage_layout.dart';
import 'pointage_status.dart';

/// Tonalité d'un bouton du dock.
enum DockTone {
  /// Prochaine étape (signer, saisir, faire le rapport) — bleu marque.
  primary,

  /// Démarrer / reprendre le service — vert.
  success,

  /// Action réversible (pause) — ambre doux, texte foncé.
  soft,

  /// Action de clôture (terminer) — rouge, protégée par une feuille.
  danger,

  /// Action calme (réessayer) — surface enfoncée.
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

/// Ligne d'état GPS du dock : visible AVANT d'appuyer.
class GpsStatus {
  const GpsStatus({
    required this.text,
    this.icon,
    this.busy = false,
    this.color,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final IconData? icon;

  /// Indicateur de progression à la place de l'icône.
  final bool busy;
  final Color? color;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Message inline du dock (erreur d'action, confirmation).
class DockNotice {
  const DockNotice({required this.text, required this.variant});

  final String text;
  final AlertVariant variant;
}

/// Dock d'action persistant, à placer dans le slot `bottomNavigationBar` d'un
/// `Scaffold(extendBody: true)`. Il ne doit jamais se lire comme une seconde
/// barre au-dessus de la tab bar en verre : pas de carte, pas d'ombre, pas de
/// trait — le contenu qui défile s'estompe sous un fondu vers `background`,
/// et les boutons gardent un écart net avec la capsule
/// (`PointageLayout.dockToTabBarGap`).
///
/// Empile : fondu · notice inline (optionnelle) · ligne GPS · un ou deux
/// boutons `AppButton lg` (56 dp). Réserve elle-même
/// `paddingOf.bottom + dockToTabBarGap` sous les boutons (la tab bar est déjà
/// comprise dans `paddingOf.bottom`). L'écran réserve `paddingOf.bottom` en
/// bas de sa liste pour que le dernier élément reste visible.
class ActionDock extends StatelessWidget {
  const ActionDock({
    super.key,
    this.actions = const [],
    this.gps,
    this.notice,
    this.onDismissNotice,
    this.absorbing = false,
    this.skeleton = false,
    this.shakeToken = 0,
  });

  /// Un ou deux boutons.
  final List<DockAction> actions;
  final GpsStatus? gps;
  final DockNotice? notice;
  final VoidCallback? onDismissNotice;

  /// Une action est en vol : le dock ignore les taps.
  final bool absorbing;

  /// Premier chargement : squelette à la place des boutons.
  final bool skeleton;

  /// Incrémenté pour secouer la ligne GPS (tentative sans position).
  final int shakeToken;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = colors.background;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fondu : le contenu qui défile s'estompe sous le dock au lieu de
        // buter sur un trait — aucun bord dur, donc pas de « seconde barre ».
        // Transparent aux gestes : ce qui est visible dessous reste tapable.
        IgnorePointer(
          child: Container(
            height: PointageLayout.dockFadeHeight,
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
              bottom + PointageLayout.dockToTabBarGap,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: PointageLayout.maxContentWidth,
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
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
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
                      if (gps != null) ...[
                        GpsStatusLine(status: gps!, shakeToken: shakeToken),
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
                            : _DockButtons(actions: actions),
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
class _DockButtons extends StatelessWidget {
  const _DockButtons({required this.actions});

  final List<DockAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    if (actions.length == 1) return _button(context, actions.first);

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final stacked = scale > PointageLayout.stackedButtonsTextScale ||
            constraints.maxWidth < PointageLayout.stackedButtonsMinWidth;
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
          foregroundColor: PointageColors.onWarningMuted(colors),
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

/// Ligne GPS : icône (ou indicateur) + texte + bouton texte optionnel. Se
/// secoue (±4 dp, 300 ms) quand [shakeToken] change.
class GpsStatusLine extends StatefulWidget {
  const GpsStatusLine({super.key, required this.status, this.shakeToken = 0});

  final GpsStatus status;
  final int shakeToken;

  @override
  State<GpsStatusLine> createState() => _GpsStatusLineState();
}

class _GpsStatusLineState extends State<GpsStatusLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void didUpdateWidget(GpsStatusLine old) {
    super.didUpdateWidget(old);
    if (old.shakeToken != widget.shakeToken &&
        !MediaQuery.disableAnimationsOf(context)) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final s = widget.status;
    final accent = s.color ?? colors.mutedForeground;

    final row = Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: AnimatedSwitcher(
            duration: AppDuration.fast,
            child: s.busy
                ? Padding(
                    key: const ValueKey('busy'),
                    padding: const EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  )
                : Icon(
                    s.icon ?? Icons.my_location_rounded,
                    key: ValueKey(s.icon),
                    size: 18,
                    color: accent,
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            s.text,
            style: textTheme.labelMedium?.copyWith(color: colors.foreground),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (s.actionLabel != null && s.onAction != null)
          TextButton(
            onPressed: s.onAction,
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              textStyle: textTheme.labelLarge,
            ),
            child: Text(s.actionLabel!),
          ),
      ],
    );

    return Semantics(
      label: 'Position : ${s.text}',
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          // 3 oscillations amorties de ±4 dp.
          final t = _shake.value;
          final dx = t == 0 || t == 1
              ? 0.0
              : 4 * (1 - t) * _sin(t * 3 * 2 * 3.141592653589793);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: row,
        ),
      ),
    );
  }

  static double _sin(double x) {
    // Série de Taylor suffisante sur [0, 6π] après réduction.
    const twoPi = 2 * 3.141592653589793;
    var r = x % twoPi;
    if (r > 3.141592653589793) r -= twoPi;
    final r2 = r * r;
    return r * (1 - r2 / 6 * (1 - r2 / 20 * (1 - r2 / 42 * (1 - r2 / 72))));
  }
}

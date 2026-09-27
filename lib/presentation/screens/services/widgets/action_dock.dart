import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_dock.dart';
import 'pointage_layout.dart';

export '../../../widgets/app_dock.dart' show DockAction, DockNotice, DockTone;

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

/// Dock de la page Pointage : le dock partagé ([AppDock]) avec la ligne GPS
/// et 24 dp d'écart au-dessus de la tab bar en verre (à 8 dp, bouton et
/// capsule se lisaient comme deux barres empilées).
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
    return AppDock(
      actions: actions,
      status: gps == null
          ? null
          : GpsStatusLine(status: gps!, shakeToken: shakeToken),
      notice: notice,
      onDismissNotice: onDismissNotice,
      absorbing: absorbing,
      skeleton: skeleton,
      bottomGap: PointageLayout.dockToTabBarGap,
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

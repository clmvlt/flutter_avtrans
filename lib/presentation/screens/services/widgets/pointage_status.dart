import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../pointage_controller.dart';

/// Apparence d'un moment de la journée : mot d'état, icône, accent.
///
/// Règle « le contraste avant la teinte » : le texte est toujours rendu en
/// `foreground` par les widgets ; seule l'icône (et le point pulsant) porte
/// la couleur. Un statut est toujours icône + texte, jamais la couleur seule.
class PointageStatusVisual {
  const PointageStatusVisual._({
    required this.label,
    required this.icon,
    required this.accent,
    required this.isLive,
  });

  factory PointageStatusVisual.of(PointageMoment moment, AppColors c) {
    return switch (moment) {
      PointageMoment.loading => PointageStatusVisual._(
          label: 'Chargement',
          icon: Icons.hourglass_top_rounded,
          accent: c.mutedForeground,
          isLive: false,
        ),
      PointageMoment.offline => PointageStatusVisual._(
          label: 'Hors ligne',
          icon: Icons.cloud_off_rounded,
          accent: c.destructive,
          isLive: false,
        ),
      PointageMoment.notStarted => PointageStatusVisual._(
          label: 'Hors service',
          icon: Icons.bedtime_outlined,
          accent: c.mutedForeground,
          isLive: false,
        ),
      PointageMoment.onDuty => PointageStatusVisual._(
          label: 'En service',
          icon: Icons.bolt_rounded,
          accent: c.success,
          isLive: true,
        ),
      PointageMoment.onBreak => PointageStatusVisual._(
          label: 'En pause',
          icon: Icons.pause_circle_outline_rounded,
          accent: c.warning,
          isLive: true,
        ),
      PointageMoment.dayDone => PointageStatusVisual._(
          label: 'Journée terminée',
          icon: Icons.check_circle_rounded,
          accent: c.success,
          isLive: false,
        ),
    };
  }

  final String label;
  final IconData icon;
  final Color accent;

  /// Un pointage est ouvert : le point pulse.
  final bool isLive;
}

/// Couleurs dérivées propres à la page.
abstract final class PointageColors {
  /// Texte lisible sur `warningMuted` : ambre foncé en clair, ambre clair en
  /// sombre (`warningForeground` est illisible sur `warningMuted` en dark).
  static Color onWarningMuted(AppColors c) =>
      c.isDarkMode ? c.warning : c.warningForeground;
}

/// Point qui pulse doucement (opacité 35 % → 100 %, 1,2 s aller-retour).
/// Statique quand le système demande moins d'animations.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  late final Animation<double> _opacity =
      Tween<double>(begin: 0.35, end: 1).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

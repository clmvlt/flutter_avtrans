import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/app_hero_card.dart';
import '../../../widgets/live_builder.dart';
import '../../services/widgets/pointage_status.dart';

/// Carte hero de l'Accueil : l'état du pointage, sur les règles de la carte
/// de la page Pointage. La carte reste sur `card` : l'état vit dans l'icône
/// (et le point pulsant), le mot d'état reste en `foreground`.
///
/// Le temps net du service en cours et le total du jour avancent en direct.
/// Tapable : ouvre l'onglet Pointage.
class HomePointageCard extends StatelessWidget {
  const HomePointageCard({
    super.key,
    required this.activeService,
    required this.hoursToday,
    required this.onTap,
  });

  /// Service de travail en cours (pause en cours comprise), `null` hors
  /// service.
  final Service? activeService;

  /// Total « Aujourd'hui » de l'API.
  final HeuresPeriode? hoursToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiveBuilder(
      running: activeService != null || (hoursToday?.enCours ?? false),
      builder: _build,
    );
  }

  Widget _build(BuildContext context) {
    final colors = context.colors;
    final s = activeService;
    final worked = hoursToday?.live.value ?? Duration.zero;

    final (label, icon, accent, live) = switch (s) {
      null => (
          'Hors service',
          Icons.bedtime_outlined,
          colors.mutedForeground,
          false,
        ),
      Service(enPause: true) => (
          'En pause',
          Icons.pause_circle_outline_rounded,
          colors.warning,
          true,
        ),
      Service() => ('En service', Icons.bolt_rounded, colors.success, true),
    };

    final now = DateTime.now();
    final pause = s?.pauseEnCours;
    final subtitle = switch (s) {
      null => worked > Duration.zero
          ? 'Aucun service en cours'
          : 'Aucun pointage aujourd\'hui',
      Service(enPause: true) when pause != null =>
        'Pause depuis ${TimeFormat.hm(pause.debut)} · '
            '${TimeFormat.durationShort(pause.liveDuree.value)}',
      Service(enPause: true) => 'En pause',
      // Service de nuit : « Depuis le 12/10 à 21:00 ».
      Service() => 'Depuis ${TimeFormat.hmOrDay(s.debut, now)} · '
          '${TimeFormat.durationShort(s.liveTravail.value)} travaillées',
    };

    final workedLabel = TimeFormat.hours(worked);

    return Semantics(
      button: true,
      label: 'Pointage : $label. $subtitle. '
          'Travaillé aujourd\'hui : $workedLabel',
      hint: 'Ouvre la page Pointage',
      onTap: onTap,
      excludeSemantics: true,
      child: AppHeroCard(
        icon: icon,
        accent: accent,
        title: label,
        subtitle: subtitle,
        onTap: onTap,
        trailing: live
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulseDot(color: accent),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.mutedForeground,
                  ),
                ],
              )
            : null,
        child: AppHeroFigure(
          label: 'Travaillé aujourd\'hui',
          value: workedLabel,
          muted: worked <= Duration.zero,
        ),
      ),
    );
  }
}

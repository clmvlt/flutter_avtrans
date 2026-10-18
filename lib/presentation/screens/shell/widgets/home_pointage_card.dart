import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
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
    this.jour,
  });

  /// Service de travail en cours (pause en cours comprise), `null` hors
  /// service.
  final Service? activeService;

  /// Temps net de la journée de travail en cours (`workedHours.day`).
  final HeuresPeriode? hoursToday;

  /// Jour de cette journée (`workedHours.jour`) : la veille pour un salarié
  /// de nuit après minuit, tant que son service touche aujourd'hui.
  final DateTime? jour;
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
    final day = jour;
    final isToday = day == null || TimeFormat.sameDay(day, now);
    final pause = s?.pauseEnCours;
    final subtitle = switch (s) {
      // Journée de la veille : elle a forcément un service.
      null => worked > Duration.zero || !isToday
          ? 'Aucun service en cours'
          : 'Aucun pointage aujourd\'hui',
      Service(enPause: true) when pause != null =>
        'Pause depuis ${TimeFormat.hm(pause.debut)} · '
            '${TimeFormat.durationShort(pause.liveDuree.value)}',
      Service(enPause: true) => 'En pause',
      // Daté s'il ne commence pas le jour de la journée.
      Service() => 'Depuis ${DisplayFormat.hmOn(s.debut, day ?? now)} · '
          '${TimeFormat.durationShort(s.liveTravail.value)} travaillées',
    };

    final workedLabel = TimeFormat.hours(worked);
    final figureLabel = isToday
        ? 'Travaillé aujourd\'hui'
        : 'Travaillé · journée du ${DisplayFormat.dayNumeric(day)}';

    return Semantics(
      button: true,
      label: 'Pointage : $label. $subtitle. '
          '$figureLabel : $workedLabel',
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
          label: figureLabel,
          value: workedLabel,
          muted: worked <= Duration.zero,
        ),
      ),
    );
  }
}

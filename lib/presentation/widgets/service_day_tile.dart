import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/service_model.dart';
import 'app_card.dart';
import 'app_list_row.dart';
import 'live_builder.dart';

/// Carte d'un pointage (service ou pause) : boîte d'icône teintée, titre,
/// plage horaire, et la durée de l'API (ou « En cours ») en pastille à
/// droite. Une ligne en cours avance en direct.
///
/// Les listes du jour utilisent plutôt le fil de la page Pointage
/// (`DayTimeline`) ; cette carte reste pour un pointage isolé.
class ServiceDayTile extends StatelessWidget {
  const ServiceDayTile({super.key, required this.service, this.onTap});

  final Service service;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LiveBuilder(running: service.enCours, builder: _build);
  }

  Widget _build(BuildContext context) {
    final colors = context.colors;
    final isBreak = service.isBreak;
    final isActive = service.enCours;
    final accent = isBreak ? colors.warning : colors.success;
    final label = isBreak ? 'Pause' : 'Service';

    final start = service.debut.toLocal();
    final end = service.fin?.toLocal();
    // Service : temps net ; pause : sa durée.
    final duration =
        (isBreak ? service.liveDuree : service.liveTravail).value;

    final String timeLine;
    if (isActive) {
      timeLine =
          'Depuis ${TimeFormat.hm(start)} · ${TimeFormat.durationShort(duration)}';
    } else if (end != null) {
      timeLine = TimeFormat.hmRange(start, end);
    } else {
      timeLine = TimeFormat.hm(start);
    }

    final Widget pill = isActive
        ? AppStatusChip(
            label: 'En cours',
            color: accent,
            icon: Icons.fiber_manual_record_rounded,
          )
        : AppStatusChip(
            label: TimeFormat.durationShort(duration),
            color: accent,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: AppListRow(
          title: label,
          subtitle: timeLine,
          icon: isBreak ? Icons.coffee_rounded : Icons.work_rounded,
          iconColor: accent,
          trailing: pill,
          showChevron: false,
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          semanticsLabel: '$label, $timeLine',
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/service_model.dart';
import 'app_card.dart';
import 'app_list_row.dart';

/// Carte d'un pointage (service ou pause) : boîte d'icône teintée, titre,
/// plage horaire, et la durée (ou « En cours ») en pastille à droite.
///
/// Les listes du jour utilisent plutôt le fil de la page Pointage
/// (`DayTimeline`) ; cette carte reste pour un pointage isolé.
class ServiceDayTile extends StatelessWidget {
  const ServiceDayTile({super.key, required this.service, this.onTap});

  final Service service;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isBreak = service.isBreak;
    final isActive = service.isActive;
    final accent = isBreak ? colors.warning : colors.success;
    final label = isBreak ? 'Pause' : 'Service';

    final start = service.debut.toLocal();
    final end = service.fin?.toLocal();
    final duration = isActive
        ? DateTime.now().difference(start)
        : end?.difference(start);

    final String timeLine;
    if (isActive) {
      timeLine = duration != null
          ? 'Depuis ${TimeFormat.hm(start)} · ${TimeFormat.durationShort(duration)}'
          : 'Depuis ${TimeFormat.hm(start)}';
    } else if (end != null) {
      timeLine = TimeFormat.hmRange(start, end);
    } else {
      timeLine = TimeFormat.hm(start);
    }

    Widget? pill;
    if (isActive) {
      pill = AppStatusChip(
        label: 'En cours',
        color: accent,
        icon: Icons.fiber_manual_record_rounded,
      );
    } else if (duration != null) {
      pill = AppStatusChip(
        label: TimeFormat.durationShort(duration),
        color: accent,
      );
    }

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

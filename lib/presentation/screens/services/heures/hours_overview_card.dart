import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/service_model.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_list_row.dart';
import 'hours_period.dart';

/// « Mes totaux » : les cinq totaux en cours de la vue d'ensemble
/// (aujourd'hui, semaine, mois, mois dernier, année), une ligne chacun. Un
/// tap affiche la période dans la carte du haut.
class HoursOverviewCard extends StatelessWidget {
  const HoursOverviewCard({
    super.key,
    required this.hours,
    required this.now,
    required this.onSelect,
  });

  final WorkedHours hours;
  final DateTime now;
  final ValueChanged<HoursShortcut> onSelect;

  @override
  Widget build(BuildContext context) {
    final lastMonth = DateTime(now.year, now.month - 1, 1);

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          _Row(
            icon: Icons.today_rounded,
            title: 'Aujourd\'hui',
            subtitle: TimeFormat.dateLong(now),
            hours: hours.day,
            onTap: () => onSelect(HoursShortcut.today),
          ),
          _Row(
            icon: Icons.view_week_rounded,
            title: 'Cette semaine',
            subtitle: 'Semaine ${HoursWeeks.weekNumber(now)}',
            hours: hours.week,
            onTap: () => onSelect(HoursShortcut.week),
          ),
          _Row(
            icon: Icons.calendar_month_rounded,
            title: 'Ce mois',
            subtitle: DisplayFormat.monthYear(now),
            hours: hours.month,
            onTap: () => onSelect(HoursShortcut.month),
          ),
          _Row(
            icon: Icons.history_rounded,
            title: 'Mois dernier',
            subtitle: DisplayFormat.monthYear(lastMonth),
            hours: hours.lastMonth,
            onTap: () => onSelect(HoursShortcut.lastMonth),
          ),
          _Row(
            icon: Icons.event_note_rounded,
            title: 'Cette année',
            subtitle: '${now.year}',
            hours: hours.year,
            onTap: () => onSelect(HoursShortcut.year),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.hours,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double? hours;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final value = TimeFormat.hoursDecimal(hours);

    return AppListRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: colors.domainHours,
      trailing: Text(
        value,
        style: textTheme.titleMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      showChevron: true,
      onTap: onTap,
      semanticsLabel: '$title, $subtitle : $value',
    );
  }
}

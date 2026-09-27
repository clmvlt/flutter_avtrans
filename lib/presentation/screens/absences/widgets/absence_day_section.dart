import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';
import 'absence_visuals.dart';

/// Section sous le calendrier : le jour sélectionné et ses absences.
class AbsenceDaySection extends StatelessWidget {
  const AbsenceDaySection({
    super.key,
    required this.day,
    required this.absences,
    required this.onOpen,
  });

  final DateTime day;
  final List<Absence> absences;
  final ValueChanged<Absence> onOpen;

  @override
  Widget build(BuildContext context) {
    final title = day.year == DateTime.now().year
        ? TimeFormat.dateLong(day)
        : '${TimeFormat.dateLong(day)} ${day.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: title,
          summary: DisplayFormat.plural(absences.length, 'absence'),
        ),
        if (absences.isEmpty)
          const AppEmptyCard(
            icon: Icons.event_available_rounded,
            message: 'Aucune absence ce jour',
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (final a in absences)
                  AbsenceRow(absence: a, onTap: () => onOpen(a)),
              ],
            ),
          ),
      ],
    );
  }
}

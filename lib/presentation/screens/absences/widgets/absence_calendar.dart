import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';

/// Calendrier des absences dans une carte. Un point sous chaque jour
/// d'absence : rouge si une absence approuvée tombe ce jour-là, gris sinon.
///
/// La page défile verticalement : seul le balayage horizontal (changer de
/// mois) est capté par le calendrier ; le format se change par son bouton.
class AbsenceCalendar extends StatelessWidget {
  const AbsenceCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.format,
    required this.eventLoader,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onPageChanged,
  });

  final DateTime focusedDay;
  final DateTime? selectedDay;
  final CalendarFormat format;
  final List<Absence> Function(DateTime day) eventLoader;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final ValueChanged<DateTime> onPageChanged;

  static const Map<CalendarFormat, String> _formats = {
    CalendarFormat.month: 'Mois',
    CalendarFormat.twoWeeks: '2 semaines',
    CalendarFormat.week: 'Semaine',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: TableCalendar<Absence>(
        firstDay: DateTime(2020),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        calendarFormat: format,
        availableCalendarFormats: _formats,
        availableGestures: AvailableGestures.horizontalSwipe,
        locale: 'fr_FR',
        startingDayOfWeek: StartingDayOfWeek.monday,
        eventLoader: eventLoader,
        onDaySelected: onDaySelected,
        onFormatChanged: onFormatChanged,
        onPageChanged: onPageChanged,
        calendarStyle: CalendarStyle(
          defaultTextStyle: TextStyle(color: colors.foreground),
          weekendTextStyle: TextStyle(color: colors.mutedForeground),
          outsideTextStyle: TextStyle(color: colors.disabled),
          selectedDecoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            color: colors.primaryForeground,
            fontWeight: FontWeight.w700,
          ),
          todayDecoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
          markersMaxCount: 3,
          markerSize: 6,
          markerMargin: const EdgeInsets.symmetric(horizontal: 1),
        ),
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: true,
          formatButtonShowsNext: false,
          titleTextFormatter: (date, _) => DisplayFormat.monthYear(date),
          titleTextStyle: textTheme.titleMedium!,
          formatButtonTextStyle: textTheme.labelMedium!,
          formatButtonPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          formatButtonDecoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          leftChevronIcon:
              Icon(Icons.chevron_left_rounded, color: colors.foreground),
          rightChevronIcon:
              Icon(Icons.chevron_right_rounded, color: colors.foreground),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: textTheme.labelSmall!,
          weekendStyle: textTheme.labelSmall!,
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return null;

            // Rouge pour les absences approuvées, gris pour tout le reste.
            final hasApproved =
                events.any((e) => e.status == AbsenceStatus.approved);
            final markerColor =
                hasApproved ? colors.destructive : colors.mutedForeground;

            return Positioned(
              bottom: 1,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

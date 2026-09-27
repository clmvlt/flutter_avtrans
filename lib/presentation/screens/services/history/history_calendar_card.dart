import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/service_model.dart';
import '../../../widgets/app_card.dart';

/// Calendrier mensuel de l'historique, aux couleurs du kit : jour choisi en
/// pastille pleine, aujourd'hui en pastille douce, un point vert sous les
/// jours avec un service et un point ambre sous ceux avec une pause.
///
/// Une fine barre en haut de la carte signale le chargement du mois.
class HistoryCalendarCard extends StatelessWidget {
  const HistoryCalendarCard({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.format,
    required this.loading,
    required this.eventLoader,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onPageChanged,
  });

  final DateTime focusedDay;
  final DateTime? selectedDay;
  final CalendarFormat format;

  /// Le mois affiché est en cours de chargement.
  final bool loading;
  final List<Service> Function(DateTime day) eventLoader;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final ValueChanged<DateTime> onPageChanged;

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final dayStyle = textTheme.bodyMedium!.copyWith(fontFeatures: _tabular);
    final dowStyle = textTheme.labelSmall!.copyWith(
      color: colors.mutedForeground,
    );

    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        children: [
          SizedBox(
            height: 2,
            child: loading
                ? LinearProgressIndicator(
                    minHeight: 2,
                    color: colors.primary,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: TableCalendar<Service>(
              firstDay: DateTime(2020),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: focusedDay,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              calendarFormat: format,
              locale: 'fr_FR',
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Mois',
                CalendarFormat.twoWeeks: '2 sem.',
                CalendarFormat.week: 'Semaine',
              },
              eventLoader: eventLoader,
              onDaySelected: onDaySelected,
              onFormatChanged: onFormatChanged,
              onPageChanged: onPageChanged,
              daysOfWeekHeight: 24,
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: true,
                formatButtonShowsNext: false,
                titleTextFormatter: (date, _) => DisplayFormat.monthYear(date),
                titleTextStyle: textTheme.titleMedium!,
                headerPadding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                formatButtonTextStyle: textTheme.labelMedium!,
                formatButtonPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                formatButtonDecoration: BoxDecoration(
                  color: colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left_rounded,
                  color: colors.foreground,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.foreground,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: dowStyle,
                weekendStyle: dowStyle,
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: dayStyle,
                weekendTextStyle: dayStyle.copyWith(
                  color: colors.mutedForeground,
                ),
                outsideTextStyle: dayStyle.copyWith(color: colors.disabled),
                selectedDecoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: dayStyle.copyWith(
                  color: colors.primaryForeground,
                  fontWeight: FontWeight.w600,
                ),
                todayDecoration: BoxDecoration(
                  color: colors.primarySoft,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: dayStyle.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
                markersMaxCount: 0,
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return null;
                  final hasService = events.any((e) => !e.isBreak);
                  final hasBreak = events.any((e) => e.isBreak);
                  return Positioned(
                    bottom: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasService) _MarkerDot(color: colors.success),
                        if (hasBreak) _MarkerDot(color: colors.warning),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const _Legend(),
        ],
      ),
    );
  }
}

/// Légende des points : forme + mot, jamais la couleur seule.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = Theme.of(context).textTheme.labelSmall;

    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.xs,
          AppSpacing.base,
          AppSpacing.md,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MarkerDot(color: colors.success),
            const SizedBox(width: AppSpacing.xs),
            Text('Service', style: style),
            const SizedBox(width: AppSpacing.lg),
            _MarkerDot(color: colors.warning),
            const SizedBox(width: AppSpacing.xs),
            Text('Pause', style: style),
          ],
        ),
      ),
    );
  }
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

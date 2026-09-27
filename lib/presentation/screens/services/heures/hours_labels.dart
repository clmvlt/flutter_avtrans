import '../../../../core/utils/display_format.dart';
import '../../../../core/utils/time_format.dart';
import 'hours_period.dart';

/// Libellés de la carte hero pour la période affichée : titre, sous-ligne,
/// et le lien qui ramène à la période en cours.
class HoursHeroLabels {
  const HoursHeroLabels({
    required this.title,
    required this.subtitle,
    required this.isCurrent,
    required this.resetLabel,
  });

  final String title;
  final String? subtitle;

  /// La période affichée est la période en cours (pas de lien de retour).
  final bool isCurrent;
  final String resetLabel;

  /// Jour : « Aujourd'hui » ou « Mercredi 12 mars » (+ année si besoin).
  factory HoursHeroLabels.day(DateTime? selected, DateTime now) {
    final custom = selected != null &&
            !(selected.year == now.year &&
                selected.month == now.month &&
                selected.day == now.day)
        ? selected
        : null;
    return HoursHeroLabels(
      title: custom == null
          ? 'Aujourd\'hui'
          : custom.year == now.year
              ? TimeFormat.dateLong(custom)
              : '${TimeFormat.dateLong(custom)} ${custom.year}',
      subtitle: custom == null ? TimeFormat.dateLong(now) : null,
      isCurrent: custom == null,
      resetLabel: 'Revenir à aujourd\'hui',
    );
  }

  /// Semaine : « Cette semaine » ou « Semaine 36 », avec ses dates.
  factory HoursHeroLabels.week(int week, int year, DateTime now) {
    final isCurrent = week == HoursWeeks.weekNumber(now) && year == now.year;
    final range = HoursWeeks.formatRange(week, year);
    return HoursHeroLabels(
      title: isCurrent ? 'Cette semaine' : 'Semaine $week',
      subtitle: isCurrent ? 'Semaine $week · $range' : range,
      isCurrent: isCurrent,
      resetLabel: 'Revenir à cette semaine',
    );
  }

  /// Mois : « Ce mois », « Mois dernier » ou « Mars 2025 ».
  factory HoursHeroLabels.month(int? month, int? year, DateTime now) {
    final m = month ?? now.month;
    final y = year ?? now.year;
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final isCurrent = m == now.month && y == now.year;
    final isLast = m == lastMonth.month && y == lastMonth.year;
    final label = DisplayFormat.monthYear(DateTime(y, m));
    return HoursHeroLabels(
      title: isCurrent
          ? 'Ce mois'
          : isLast
              ? 'Mois dernier'
              : label,
      subtitle: isCurrent || isLast ? label : null,
      isCurrent: isCurrent,
      resetLabel: 'Revenir à ce mois',
    );
  }

  /// Année : « Cette année » ou « 2024 ».
  factory HoursHeroLabels.year(int? year, DateTime now) {
    final y = year ?? now.year;
    final isCurrent = y == now.year;
    return HoursHeroLabels(
      title: isCurrent ? 'Cette année' : '$y',
      subtitle: isCurrent ? '$y' : null,
      isCurrent: isCurrent,
      resetLabel: 'Revenir à cette année',
    );
  }
}

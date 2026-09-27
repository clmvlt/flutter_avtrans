import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Période affichée par l'écran Mes heures (segments du haut).
enum HoursPeriod {
  day('Jour', 'Choisir un jour', Icons.today_rounded),
  week('Semaine', 'Choisir une semaine', Icons.view_week_rounded),
  month('Mois', 'Choisir un mois', Icons.calendar_month_rounded),
  year('Année', 'Choisir une année', Icons.event_note_rounded);

  const HoursPeriod(this.label, this.pickLabel, this.icon);

  final String label;

  /// Libellé du bouton du dock qui ouvre le choix de la période.
  final String pickLabel;
  final IconData icon;
}

/// Raccourcis de la carte « Mes totaux » (valeurs de la vue d'ensemble).
enum HoursShortcut { today, week, month, lastMonth, year }

/// Calculs de semaines, repris tels quels de l'écran d'origine.
abstract final class HoursWeeks {
  /// Numéro de semaine « ISO 8601 » : la semaine 1 contient le 4 janvier.
  static int weekNumber(DateTime date) {
    final jan4 = DateTime(date.year, 1, 4);
    final daysSinceMonday = (jan4.weekday - 1) % 7;
    final firstMondayOfYear = jan4.subtract(Duration(days: daysSinceMonday));

    final daysSinceFirstMonday = date.difference(firstMondayOfYear).inDays;
    if (daysSinceFirstMonday < 0) {
      // La date est dans la dernière semaine de l'année précédente
      return weekNumber(DateTime(date.year - 1, 12, 31));
    }
    return (daysSinceFirstMonday / 7).floor() + 1;
  }

  /// Lundi et dimanche de la semaine [weekNumber] de [year].
  static (DateTime start, DateTime end) weekRange(int weekNumber, int year) {
    final jan4 = DateTime(year, 1, 4);
    final daysSinceMonday = (jan4.weekday - 1) % 7;
    final firstMondayOfYear = jan4.subtract(Duration(days: daysSinceMonday));

    final monday = firstMondayOfYear.add(Duration(days: (weekNumber - 1) * 7));
    final sunday = monday.add(const Duration(days: 6));
    return (monday, sunday);
  }

  /// « du 15 septembre au 21 septembre » (+ l'année si ce n'est pas
  /// l'année courante).
  static String formatRange(int weekNumber, int year) {
    final (start, end) = weekRange(weekNumber, year);
    final startFormat = DateFormat('d MMMM', 'fr_FR').format(start);
    final endFormat = DateFormat('d MMMM', 'fr_FR').format(end);
    if (year != DateTime.now().year) {
      return 'du $startFormat au $endFormat $year';
    }
    return 'du $startFormat au $endFormat';
  }

  /// La semaine affichée n'est pas encore la semaine en cours.
  static bool canGoForward(int weekNumber, int year, DateTime now) {
    final currentWeek = HoursWeeks.weekNumber(now);
    final currentYear = now.year;
    if (year < currentYear) return true;
    if (year == currentYear && weekNumber < currentWeek) return true;
    return false;
  }

  /// Semaine voisine ([direction] = -1 ou +1), passage d'année compris.
  static (int week, int year) shift(int weekNumber, int year, int direction) {
    var week = weekNumber + direction;
    var y = year;
    if (week < 1) {
      y--;
      week = HoursWeeks.weekNumber(DateTime(y, 12, 31));
    } else if (week > 52) {
      // Vérifier si la semaine 53 existe pour cette année
      final maxWeek = HoursWeeks.weekNumber(DateTime(y, 12, 31));
      if (week > maxWeek) {
        y++;
        week = 1;
      }
    }
    return (week, y);
  }
}

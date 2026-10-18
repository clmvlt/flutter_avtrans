import 'package:intl/intl.dart';

import 'time_format.dart';

/// Formats d'affichage partagés (dates, nombres, montants) en français.
///
/// Les dates sont toujours converties en heure locale avant formatage.
/// `initializeDateFormatting('fr_FR')` est appelé dans `main()`.
abstract final class DisplayFormat {
  static const String _locale = 'fr_FR';

  /// `12 mars 2025`
  static String date(DateTime d) =>
      DateFormat('d MMMM yyyy', _locale).format(d.toLocal());

  /// `12 mars` (année courante) ou `12 mars 2024` (autre année).
  static String dateSmart(DateTime d, {DateTime? now}) {
    final local = d.toLocal();
    final ref = (now ?? DateTime.now()).toLocal();
    return local.year == ref.year
        ? DateFormat('d MMMM', _locale).format(local)
        : date(local);
  }

  /// Date abrégée : `12 sept.` (année courante) ou `12 sept. 2024`.
  static String dateCompact(DateTime d, {DateTime? now}) {
    final local = d.toLocal();
    final ref = (now ?? DateTime.now()).toLocal();
    return DateFormat(local.year == ref.year ? 'd MMM' : 'd MMM yyyy', _locale)
        .format(local);
  }

  /// `12/03/2025`
  static String dateShort(DateTime d) =>
      DateFormat('dd/MM/yyyy', _locale).format(d.toLocal());

  /// `mer. 12 mars`
  static String dayShort(DateTime d) =>
      DateFormat('EEE d MMM', _locale).format(d.toLocal());

  /// `lun. 12/10`
  static String dayNumeric(DateTime d) =>
      DateFormat('EEE dd/MM', _locale).format(d.toLocal());

  /// Titre d'une journée de travail : « Aujourd'hui », ou pour un salarié
  /// de nuit encore sur la veille « Journée du lun. 12/10 (service de nuit) ».
  static String workingDay(DateTime date, {required bool today}) => today
      ? 'Aujourd\'hui'
      : 'Journée du ${dayNumeric(date)} (service de nuit)';

  /// Heure, suivie de son jour si elle ne tombe pas le jour [day] :
  /// `21:00`, `06:00 (mar. 13/10)`.
  static String hmOn(DateTime t, DateTime? day) {
    if (day == null || _sameDay(t, day)) return TimeFormat.hm(t);
    return '${TimeFormat.hm(t)} (${dayNumeric(t)})';
  }

  /// Plage horaire d'une journée [day] : `21:00 → 06:00 (mar. 13/10)` ; le
  /// jour n'est écrit qu'une fois si les deux bornes tombent le même jour.
  static String hmRangeOn(DateTime start, DateTime end, DateTime? day) {
    if (day != null && !_sameDay(start, day) && _sameDay(start, end)) {
      return '${TimeFormat.hm(start)} → ${hmOn(end, day)}';
    }
    return '${hmOn(start, day)} → ${hmOn(end, day)}';
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  /// `Mars 2025`
  static String monthYear(DateTime d) {
    final s = DateFormat('MMMM yyyy', _locale).format(d.toLocal());
    return s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  }

  /// « Aujourd'hui », « Hier », « Demain » ou `12 mars` / `12 mars 2024`.
  static String relativeDay(DateTime d, {DateTime? now}) {
    final local = d.toLocal();
    final ref = (now ?? DateTime.now()).toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(ref.year, ref.month, ref.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Aujourd\'hui';
    if (diff == -1) return 'Hier';
    if (diff == 1) return 'Demain';
    return dateSmart(local, now: ref);
  }

  /// Entier avec séparateur de milliers : `150 000`.
  static String integer(num value) =>
      NumberFormat.decimalPattern(_locale).format(value.round());

  /// Kilométrage : `150 000 km`.
  static String km(num value) => '${integer(value)} km';

  /// Montant en euros : `1 234,50 €`.
  static String euros(num value) =>
      NumberFormat.currency(locale: _locale, symbol: '€', decimalDigits: 2)
          .format(value);

  /// Taille de fichier : `512 o`, `12,4 Ko`, `3,1 Mo`.
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    final kb = bytes / 1024;
    if (kb < 1024) return '${_oneDecimal(kb)} Ko';
    return '${_oneDecimal(kb / 1024)} Mo';
  }

  /// « 1 entretien », « 3 entretiens ».
  static String plural(int count, String singular, [String? plural]) =>
      '$count ${count > 1 ? (plural ?? '${singular}s') : singular}';

  static String _oneDecimal(double v) =>
      NumberFormat('0.#', _locale).format(v);
}

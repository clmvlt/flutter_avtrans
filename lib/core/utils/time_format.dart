/// Formatage des durées et heures pour l'affichage (pointage, heures, historique).
///
/// Regroupe les helpers dupliqués jusqu'ici dans plusieurs écrans
/// (`_formatHours`, `_fmtHours`, `_formatDuration`…).
abstract final class TimeFormat {
  /// Heures décimales de l'API (ex. `7.25`) → `7h15`, `45 min`, `7h`, `0h`.
  static String hoursDecimal(double? hours) {
    if (hours == null || hours <= 0) return '0h';
    return durationShort(Duration(minutes: (hours * 60).round()));
  }

  /// Durée compacte → `7h15`, `45 min`, `7h`, `0 min`.
  static String durationShort(Duration d) {
    final totalMinutes = d.isNegative ? 0 : d.inMinutes;
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  /// Durée façon chronomètre → `5:12:37` (heures non bornées, pas de zéro de
  /// tête sur les heures : `0:04:09`).
  static String clock(Duration d) {
    final total = d.isNegative ? 0 : d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Durée en heures/minutes façon chronomètre → `5:12` (sans secondes).
  static String clockHm(Duration d) {
    final total = d.isNegative ? 0 : d.inMinutes;
    final h = total ~/ 60;
    final m = total % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  /// Heure locale → `08:30`.
  static String hm(DateTime d) {
    final local = d.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Plage horaire → `07:42 → 12:00`.
  static String hmRange(DateTime start, DateTime end) =>
      '${hm(start)} → ${hm(end)}';

  /// Date longue en français → `Lundi 8 septembre`.
  static String dateLong(DateTime d) {
    const weekdays = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
    ];
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    final local = d.toLocal();
    return '${weekdays[local.weekday - 1]} ${local.day} ${months[local.month - 1]}';
  }
}

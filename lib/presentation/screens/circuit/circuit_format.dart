/// Formatte une distance en mètres → « 450 m » / « 12,3 km » / « 184 km ».
String formatDistance(double? meters) {
  if (meters == null) return '—';
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  final text = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
  return '${text.replaceAll('.', ',')} km';
}

/// Formatte une durée en secondes → « 2 h 15 » / « 45 min » / « < 1 min ».
String formatDuration(int? seconds) {
  if (seconds == null) return '—';
  final h = seconds ~/ 3600;
  final min = (seconds % 3600) ~/ 60;
  if (h > 0) return min > 0 ? '$h h ${min.toString().padLeft(2, '0')}' : '$h h';
  if (min > 0) return '$min min';
  return '< 1 min';
}

/// Formatte une heure (locale) → « 09:42 ». Chaîne vide si null.
String formatTime(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

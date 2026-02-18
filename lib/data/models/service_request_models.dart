/// Modèle pour les requêtes de service avec coordonnées GPS
class ServiceGpsRequest {
  final double latitude;
  final double longitude;
  final String? userUuid;

  const ServiceGpsRequest({
    required this.latitude,
    required this.longitude,
    this.userUuid,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (userUuid != null) 'userUuid': userUuid,
    };
  }
}

/// Alias pour la requête de démarrage de service
typedef StartServiceRequest = ServiceGpsRequest;

/// Alias pour la requête de fin de service
typedef EndServiceRequest = ServiceGpsRequest;

/// Alias pour la requête de démarrage de pause
typedef StartBreakRequest = ServiceGpsRequest;

/// Alias pour la requête de fin de pause
typedef EndBreakRequest = ServiceGpsRequest;

/// Période pour les heures travaillées
enum WorkedHoursPeriod {
  day('day'),
  week('week'),
  month('month'),
  year('year');

  final String value;
  const WorkedHoursPeriod(this.value);
}

/// Paramètres pour récupérer les heures travaillées
class WorkedHoursParams {
  final WorkedHoursPeriod? period;
  final int? year;
  final int? month;
  final int? week;
  final int? day;

  const WorkedHoursParams({
    this.period,
    this.year,
    this.month,
    this.week,
    this.day,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (period != null) params['period'] = period!.value;
    if (year != null) params['year'] = year.toString();
    if (month != null) params['month'] = month.toString();
    if (week != null) params['week'] = week.toString();
    if (day != null) params['day'] = day.toString();
    return params;
  }
}

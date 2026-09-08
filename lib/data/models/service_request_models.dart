/// Body commun aux 4 actions de pointage (contrat API §4.2) :
/// `POST /services/start|end|break/start|break/end`.
///
/// Les coordonnées sont optionnelles (null accepté).
/// `userUuid` est réservé aux administrateurs : un client non-admin qui le
/// renseigne reçoit un 403. Ne jamais le renseigner depuis l'application.
class ServiceGpsRequest {
  final double? latitude;
  final double? longitude;
  final String? userUuid;

  const ServiceGpsRequest({
    this.latitude,
    this.longitude,
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

/// Période pour `GET /services/hours` (valeurs acceptées par l'API, insensibles à la casse)
enum WorkedHoursPeriod {
  day('day'),
  week('week'),
  month('month'),
  year('year'),
  lastMonth('lastmonth');

  final String value;
  const WorkedHoursPeriod(this.value);
}

/// Paramètres pour récupérer les heures travaillées.
///
/// ⚠ `week` avec un `year` différent de l'année courante peut donner une plage
/// incorrecte côté serveur : n'utiliser `week` que pour l'année courante.
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

import 'package:equatable/equatable.dart';

/// Modèle représentant un pointage : un service OU une pause (ServiceDTO, contrat API §2.4).
///
/// `isBreak == false` → service, `isBreak == true` → pause (enregistrement séparé).
/// `fin == null` → en cours ; `duree` (secondes) est alors calculée à la volée par le serveur.
class Service extends Equatable {
  final String uuid;
  final DateTime debut;
  final DateTime? fin;

  /// Durée en secondes. Figée si `fin != null`, sinon `now - debut` à l'instant de la réponse.
  final int? duree;
  final bool isBreak;

  /// GPS de début (peut être null)
  final double? latitude;
  final double? longitude;

  /// GPS de fin (peut être null)
  final double? latitudeEnd;
  final double? longitudeEnd;

  /// true si créé/démarré par un administrateur
  final bool isAdmin;
  final String userUuid;

  const Service({
    required this.uuid,
    required this.debut,
    this.fin,
    this.duree,
    required this.isBreak,
    this.latitude,
    this.longitude,
    this.latitudeEnd,
    this.longitudeEnd,
    required this.isAdmin,
    required this.userUuid,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      uuid: json['uuid'] as String,
      debut: DateTime.parse(json['debut'] as String),
      fin: json['fin'] != null ? DateTime.parse(json['fin'] as String) : null,
      duree: (json['duree'] as num?)?.toInt(),
      isBreak: json['isBreak'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      latitudeEnd: (json['latitudeEnd'] as num?)?.toDouble(),
      longitudeEnd: (json['longitudeEnd'] as num?)?.toDouble(),
      isAdmin: json['isAdmin'] as bool? ?? false,
      userUuid: json['userUuid'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'debut': debut.toIso8601String(),
      'fin': fin?.toIso8601String(),
      'duree': duree,
      'isBreak': isBreak,
      'latitude': latitude,
      'longitude': longitude,
      'latitudeEnd': latitudeEnd,
      'longitudeEnd': longitudeEnd,
      'isAdmin': isAdmin,
      'userUuid': userUuid,
    };
  }

  /// Vérifie si le service est en cours (pas encore terminé)
  bool get isActive => fin == null;

  /// Calcule la durée en heures
  double? get durationInHours {
    if (duree == null) return null;
    return duree! / 3600; // seconds to hours
  }

  /// Copie le service avec de nouvelles valeurs
  Service copyWith({
    String? uuid,
    DateTime? debut,
    DateTime? fin,
    int? duree,
    bool? isBreak,
    double? latitude,
    double? longitude,
    double? latitudeEnd,
    double? longitudeEnd,
    bool? isAdmin,
    String? userUuid,
  }) {
    return Service(
      uuid: uuid ?? this.uuid,
      debut: debut ?? this.debut,
      fin: fin ?? this.fin,
      duree: duree ?? this.duree,
      isBreak: isBreak ?? this.isBreak,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      latitudeEnd: latitudeEnd ?? this.latitudeEnd,
      longitudeEnd: longitudeEnd ?? this.longitudeEnd,
      isAdmin: isAdmin ?? this.isAdmin,
      userUuid: userUuid ?? this.userUuid,
    );
  }

  @override
  List<Object?> get props => [
        uuid,
        debut,
        fin,
        duree,
        isBreak,
        latitude,
        longitude,
        latitudeEnd,
        longitudeEnd,
        isAdmin,
        userUuid,
      ];
}

/// Heures travaillées (WorkedHoursDto, contrat API §4.2 `GET /services/hours`).
///
/// Heures décimales (services − pauses), arrondies à 2 décimales, potentiellement négatives.
/// Seuls les champs non null sont sérialisés par le serveur : sans `period`, les 5 clés
/// sont présentes ; avec `period=month`, seule `month` l'est.
class WorkedHours extends Equatable {
  final double? year;
  final double? month;
  final double? lastMonth;
  final double? week;
  final double? day;

  const WorkedHours({
    this.year,
    this.month,
    this.lastMonth,
    this.week,
    this.day,
  });

  factory WorkedHours.fromJson(Map<String, dynamic> json) {
    return WorkedHours(
      year: (json['year'] as num?)?.toDouble(),
      month: (json['month'] as num?)?.toDouble(),
      lastMonth: (json['lastMonth'] as num?)?.toDouble(),
      week: (json['week'] as num?)?.toDouble(),
      day: (json['day'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (year != null) 'year': year,
      if (month != null) 'month': month,
      if (lastMonth != null) 'lastMonth': lastMonth,
      if (week != null) 'week': week,
      if (day != null) 'day': day,
    };
  }

  @override
  List<Object?> get props => [year, month, lastMonth, week, day];
}

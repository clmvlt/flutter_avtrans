import 'package:equatable/equatable.dart';

import '../../core/utils/live_counter.dart';

/// Modèle représentant un pointage : un service de travail OU une pause
/// (ServiceDTO).
///
/// `isBreak == false` → service de travail, qui porte ses [pauses] ;
/// `isBreak == true` → pause, rattachée à son service par
/// [serviceParentUuid] (même si elle commence après minuit).
///
/// Toutes les durées viennent de l'API, calculées à [calculeLe]. L'app ne
/// fait que les avancer entre deux appels (`live…`, à partir de [anchor]).
class Service extends Equatable {
  final String uuid;
  final DateTime debut;
  final DateTime? fin;
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

  /// Durée brute en secondes à [calculeLe] (en cours : `calculeLe − debut`).
  final int duree;

  /// Instant du calcul côté serveur — affichage et debug seulement.
  final DateTime? calculeLe;

  /// La ligne n'a pas de fin.
  final bool enCours;

  // ---- service de travail uniquement ----

  /// Pauses du service, par début croissant.
  final List<Service> pauses;

  /// Durée des pauses (bornées au service, chevauchements fusionnés), en s.
  final int dureePauses;

  /// Temps net en secondes : `duree − dureePauses`.
  final int dureeTravail;

  /// Service en cours ET une pause en cours.
  final bool enPause;

  // ---- pause uniquement ----

  /// Service de travail auquel la pause appartient.
  final String? serviceParentUuid;

  /// Réception de la réponse (horloge monotone) : point de départ des
  /// valeurs en direct. Hors égalité.
  final LiveAnchor anchor;

  const Service({
    required this.uuid,
    required this.debut,
    this.fin,
    required this.isBreak,
    this.latitude,
    this.longitude,
    this.latitudeEnd,
    this.longitudeEnd,
    required this.isAdmin,
    required this.userUuid,
    this.duree = 0,
    this.calculeLe,
    bool? enCours,
    this.pauses = const [],
    this.dureePauses = 0,
    this.dureeTravail = 0,
    this.enPause = false,
    this.serviceParentUuid,
    this.anchor = const LiveAnchor.frozen(),
  }) : enCours = enCours ?? fin == null;

  /// [anchor] : réception de la réponse ; par défaut, maintenant.
  factory Service.fromJson(Map<String, dynamic> json, {LiveAnchor? anchor}) {
    final a = anchor ?? LiveAnchor.now();
    final fin = json['fin'] != null ? DateTime.parse(json['fin'] as String) : null;
    final pauses = json['pauses'] as List?;
    return Service(
      uuid: json['uuid'] as String,
      debut: DateTime.parse(json['debut'] as String),
      fin: fin,
      isBreak: json['isBreak'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      latitudeEnd: (json['latitudeEnd'] as num?)?.toDouble(),
      longitudeEnd: (json['longitudeEnd'] as num?)?.toDouble(),
      isAdmin: json['isAdmin'] as bool? ?? false,
      userUuid: json['userUuid'] as String? ?? '',
      duree: (json['duree'] as num?)?.toInt() ?? 0,
      calculeLe: json['calculeLe'] != null
          ? DateTime.parse(json['calculeLe'] as String)
          : null,
      enCours: json['enCours'] as bool? ?? fin == null,
      pauses: pauses == null
          ? const []
          : [
              for (final p in pauses)
                Service.fromJson(p as Map<String, dynamic>, anchor: a),
            ],
      dureePauses: (json['dureePauses'] as num?)?.toInt() ?? 0,
      dureeTravail: (json['dureeTravail'] as num?)?.toInt() ?? 0,
      enPause: json['enPause'] as bool? ?? false,
      serviceParentUuid: json['serviceParentUuid'] as String?,
      anchor: a,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'debut': debut.toIso8601String(),
      'fin': fin?.toIso8601String(),
      'isBreak': isBreak,
      'latitude': latitude,
      'longitude': longitude,
      'latitudeEnd': latitudeEnd,
      'longitudeEnd': longitudeEnd,
      'isAdmin': isAdmin,
      'userUuid': userUuid,
      'duree': duree,
      'calculeLe': calculeLe?.toIso8601String(),
      'enCours': enCours,
      if (!isBreak) ...{
        'pauses': [for (final p in pauses) p.toJson()],
        'dureePauses': dureePauses,
        'dureeTravail': dureeTravail,
        'enPause': enPause,
      },
      if (isBreak) 'serviceParentUuid': serviceParentUuid,
    };
  }

  /// Pause en cours (`null` hors pause).
  Service? get pauseEnCours {
    for (final p in pauses.reversed) {
      if (p.enCours) return p;
    }
    return null;
  }

  // ---- valeurs en direct ----

  /// Durée brute : avance tant que la ligne est en cours.
  LiveCounter get liveDuree => LiveCounter(
        Duration(seconds: duree),
        running: enCours,
        anchor: anchor,
      );

  /// Temps net : avance en service, figé pendant une pause.
  LiveCounter get liveTravail => LiveCounter(
        Duration(seconds: dureeTravail),
        running: enCours && !enPause,
        anchor: anchor,
      );

  /// Temps de pause : avance pendant une pause.
  LiveCounter get livePauses => LiveCounter(
        Duration(seconds: dureePauses),
        running: enPause,
        anchor: anchor,
      );

  /// Copie le service avec de nouvelles valeurs
  Service copyWith({
    String? uuid,
    DateTime? debut,
    DateTime? fin,
    bool? isBreak,
    double? latitude,
    double? longitude,
    double? latitudeEnd,
    double? longitudeEnd,
    bool? isAdmin,
    String? userUuid,
    int? duree,
    DateTime? calculeLe,
    bool? enCours,
    List<Service>? pauses,
    int? dureePauses,
    int? dureeTravail,
    bool? enPause,
    String? serviceParentUuid,
    LiveAnchor? anchor,
  }) {
    return Service(
      uuid: uuid ?? this.uuid,
      debut: debut ?? this.debut,
      fin: fin ?? this.fin,
      isBreak: isBreak ?? this.isBreak,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      latitudeEnd: latitudeEnd ?? this.latitudeEnd,
      longitudeEnd: longitudeEnd ?? this.longitudeEnd,
      isAdmin: isAdmin ?? this.isAdmin,
      userUuid: userUuid ?? this.userUuid,
      duree: duree ?? this.duree,
      calculeLe: calculeLe ?? this.calculeLe,
      enCours: enCours ?? this.enCours,
      pauses: pauses ?? this.pauses,
      dureePauses: dureePauses ?? this.dureePauses,
      dureeTravail: dureeTravail ?? this.dureeTravail,
      enPause: enPause ?? this.enPause,
      serviceParentUuid: serviceParentUuid ?? this.serviceParentUuid,
      anchor: anchor ?? this.anchor,
    );
  }

  @override
  List<Object?> get props => [
        uuid,
        debut,
        fin,
        isBreak,
        latitude,
        longitude,
        latitudeEnd,
        longitudeEnd,
        isAdmin,
        userUuid,
        duree,
        calculeLe,
        enCours,
        pauses,
        dureePauses,
        dureeTravail,
        enPause,
        serviceParentUuid,
      ];
}

/// Total d'heures d'une période (HeuresPeriodeDTO).
class HeuresPeriode extends Equatable {
  /// Temps net en secondes, à `calculeLe`.
  final int secondes;

  /// Même total en heures décimales.
  final double heures;

  /// Un service de la période est en cours hors pause : le total avance
  /// d'une seconde par seconde.
  final bool enCours;

  /// Réception de la réponse. Hors égalité.
  final LiveAnchor anchor;

  const HeuresPeriode({
    required this.secondes,
    required this.heures,
    this.enCours = false,
    this.anchor = const LiveAnchor.frozen(),
  });

  /// Construit à partir de secondes (heures déduites).
  const HeuresPeriode.seconds(
    this.secondes, {
    this.enCours = false,
    this.anchor = const LiveAnchor.frozen(),
  }) : heures = secondes / 3600;

  factory HeuresPeriode.fromJson(Map<String, dynamic> json, {LiveAnchor? anchor}) {
    final secondes = (json['secondes'] as num?)?.toInt() ?? 0;
    return HeuresPeriode(
      secondes: secondes,
      heures: (json['heures'] as num?)?.toDouble() ?? secondes / 3600,
      enCours: json['enCours'] as bool? ?? false,
      anchor: anchor ?? LiveAnchor.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'secondes': secondes,
        'heures': heures,
        'enCours': enCours,
      };

  /// Total en direct.
  LiveCounter get live => LiveCounter(
        Duration(seconds: secondes),
        running: enCours,
        anchor: anchor,
      );

  @override
  List<Object?> get props => [secondes, heures, enCours];
}

/// Date `yyyy-MM-dd` de l'API → minuit local de ce jour.
DateTime? _parseDay(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final d = DateTime.parse(value);
  return DateTime(d.year, d.month, d.day);
}

String _formatDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Journée de travail en cours (`GET /services/user/daily`).
///
/// Calculée par l'API : jour de début du dernier service qui touche
/// aujourd'hui (commencé aujourd'hui, en cours, ou terminé aujourd'hui après
/// minuit), sinon aujourd'hui. Un salarié de nuit voit donc encore son
/// service de la veille après minuit ; la journée bascule sur aujourd'hui dès
/// qu'il commence un nouveau service.
class JourneeTravail extends Equatable {
  /// Jour de la journée (minuit local).
  final DateTime date;

  /// La journée est aujourd'hui.
  final bool aujourdhui;

  /// Temps net de la journée ; avance si `heures.enCours`.
  final HeuresPeriode heures;

  /// Services de travail de la journée, pauses imbriquées, par début
  /// croissant.
  final List<Service> services;

  /// Instant du calcul côté serveur — affichage et debug seulement.
  final DateTime? calculeLe;

  const JourneeTravail({
    required this.date,
    required this.aujourdhui,
    required this.heures,
    this.services = const [],
    this.calculeLe,
  });

  /// [anchor] : réception de la réponse ; par défaut, maintenant.
  factory JourneeTravail.fromJson(
    Map<String, dynamic> json, {
    LiveAnchor? anchor,
  }) {
    final a = anchor ?? LiveAnchor.now();
    final heures = json['heures'];
    final services = json['services'] as List?;
    return JourneeTravail(
      date: _parseDay(json['date']) ?? DateTime.now(),
      aujourdhui: json['aujourdhui'] as bool? ?? true,
      heures: heures is Map<String, dynamic>
          ? HeuresPeriode.fromJson(heures, anchor: a)
          : HeuresPeriode(secondes: 0, heures: 0, anchor: a),
      services: services == null
          ? const []
          : [
              for (final s in services)
                Service.fromJson(s as Map<String, dynamic>, anchor: a),
            ],
      calculeLe: json['calculeLe'] != null
          ? DateTime.parse(json['calculeLe'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': _formatDay(date),
        'aujourdhui': aujourdhui,
        'heures': heures.toJson(),
        'services': [for (final s in services) s.toJson()],
        if (calculeLe != null) 'calculeLe': calculeLe!.toIso8601String(),
      };

  /// Copie avec un service remplacé par sa version plus récente (même
  /// uuid), par exemple celle renvoyée par une action.
  JourneeTravail withService(Service service) => JourneeTravail(
        date: date,
        aujourdhui: aujourdhui,
        heures: heures,
        services: [
          for (final s in services) s.uuid == service.uuid ? service : s,
        ],
        calculeLe: calculeLe,
      );

  @override
  List<Object?> get props => [date, aujourdhui, heures, services, calculeLe];
}

/// Heures travaillées (`GET /services/hours`).
///
/// Sans `period`, les cinq périodes sont présentes ; avec `period=month`,
/// seule `month` l'est. Sans date en paramètre, `day` est la journée de
/// travail en cours (voir [jour]) ; avec une date, le jour demandé.
class WorkedHours extends Equatable {
  final HeuresPeriode? year;
  final HeuresPeriode? month;
  final HeuresPeriode? lastMonth;
  final HeuresPeriode? week;
  final HeuresPeriode? day;

  /// Jour de [day] (minuit local) : la journée de travail en cours, qui
  /// peut être la veille pour un salarié de nuit.
  final DateTime? jour;

  /// Instant du calcul côté serveur — affichage et debug seulement.
  final DateTime? calculeLe;

  const WorkedHours({
    this.year,
    this.month,
    this.lastMonth,
    this.week,
    this.day,
    this.jour,
    this.calculeLe,
  });

  /// [anchor] : réception de la réponse ; par défaut, maintenant.
  factory WorkedHours.fromJson(Map<String, dynamic> json, {LiveAnchor? anchor}) {
    final a = anchor ?? LiveAnchor.now();
    HeuresPeriode? period(String key) {
      final value = json[key];
      return value is Map<String, dynamic>
          ? HeuresPeriode.fromJson(value, anchor: a)
          : null;
    }

    return WorkedHours(
      year: period('year'),
      month: period('month'),
      lastMonth: period('lastMonth'),
      week: period('week'),
      day: period('day'),
      jour: _parseDay(json['jour']),
      calculeLe: json['calculeLe'] != null
          ? DateTime.parse(json['calculeLe'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (calculeLe != null) 'calculeLe': calculeLe!.toIso8601String(),
      if (jour != null) 'jour': _formatDay(jour!),
      if (year != null) 'year': year!.toJson(),
      if (month != null) 'month': month!.toJson(),
      if (lastMonth != null) 'lastMonth': lastMonth!.toJson(),
      if (week != null) 'week': week!.toJson(),
      if (day != null) 'day': day!.toJson(),
    };
  }

  /// Au moins une période avance.
  bool get anyRunning => [year, month, lastMonth, week, day]
      .any((p) => p?.enCours ?? false);

  @override
  List<Object?> get props =>
      [year, month, lastMonth, week, day, jour, calculeLe];
}

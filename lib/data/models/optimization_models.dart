import 'geo_point.dart';

/// Une visite à inclure dans l'optimisation.
class OptimizeVisit {
  final String id;
  final String name;
  final double lat;
  final double lon;

  const OptimizeVisit({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lon': lon,
      };
}

/// Requête d'optimisation (TSP : 1 véhicule, capacité illimitée).
class OptimizeRequest {
  final GeoPoint depot;
  final List<OptimizeVisit> visits;

  const OptimizeRequest({required this.depot, required this.visits});

  Map<String, dynamic> toJson() => {
        'depot': depot.toJson(),
        'vehicleCount': 1,
        'includeGeometry': true,
        'geometryFormat': 'POINTS',
        'visits': visits.map((v) => v.toJson()).toList(),
      };
}

/// Un arrêt dans une tournée optimisée (avec cumuls et horaires).
class OptimizedStop {
  final String visitId;
  final String? name;
  final double lat;
  final double lon;
  final double cumulativeDistanceMeters;
  final int cumulativeDrivingSeconds;
  final DateTime? arrivalTime;
  final DateTime? departureTime;

  const OptimizedStop({
    required this.visitId,
    this.name,
    required this.lat,
    required this.lon,
    required this.cumulativeDistanceMeters,
    required this.cumulativeDrivingSeconds,
    this.arrivalTime,
    this.departureTime,
  });

  factory OptimizedStop.fromJson(Map<String, dynamic> json) => OptimizedStop(
        visitId: json['visitId']?.toString() ?? '',
        name: json['name'] as String?,
        lat: _toDouble(json['lat']),
        lon: _toDouble(json['lon']),
        cumulativeDistanceMeters: _toDouble(json['cumulativeDistanceMeters']),
        cumulativeDrivingSeconds: _toInt(json['cumulativeDrivingSeconds']),
        arrivalTime: _toDate(json['arrivalTime']),
        departureTime: _toDate(json['departureTime']),
      );
}

/// Une tournée optimisée pour un véhicule.
class OptimizedRoute {
  final String vehicleId;
  final int drivingTimeSeconds;
  final double distanceMeters;
  final List<OptimizedStop> stops;

  /// Trace complète (dépôt → arrêts → dépôt) au format points.
  final List<GeoPoint> geometry;

  const OptimizedRoute({
    required this.vehicleId,
    required this.drivingTimeSeconds,
    required this.distanceMeters,
    required this.stops,
    required this.geometry,
  });

  factory OptimizedRoute.fromJson(Map<String, dynamic> json) => OptimizedRoute(
        vehicleId: json['vehicleId']?.toString() ?? '',
        drivingTimeSeconds: _toInt(json['drivingTimeSeconds']),
        distanceMeters: _toDouble(json['distanceMeters']),
        stops: (json['stops'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(OptimizedStop.fromJson)
            .toList(),
        geometry: _parseGeometry(json['geometry']),
      );
}

/// Une visite écartée (non rattachable au réseau routier).
class SkippedVisit {
  final String visitId;
  final String? name;
  final String reason; // UNROUTABLE | TOO_FAR
  final double? snapDistanceMeters;

  const SkippedVisit({
    required this.visitId,
    this.name,
    required this.reason,
    this.snapDistanceMeters,
  });

  factory SkippedVisit.fromJson(Map<String, dynamic> json) => SkippedVisit(
        visitId: json['visitId']?.toString() ?? '',
        name: json['name'] as String?,
        reason: json['reason']?.toString() ?? 'UNROUTABLE',
        snapDistanceMeters: json['snapDistanceMeters'] == null
            ? null
            : _toDouble(json['snapDistanceMeters']),
      );
}

/// Réponse complète de l'optimisation.
class OptimizeResult {
  final int totalDrivingTimeSeconds;
  final double totalDistanceMeters;
  final List<OptimizedRoute> routes;
  final List<SkippedVisit> skippedVisits;

  const OptimizeResult({
    required this.totalDrivingTimeSeconds,
    required this.totalDistanceMeters,
    required this.routes,
    required this.skippedVisits,
  });

  /// Première (et unique en TSP) tournée, ou `null` si toutes écartées.
  OptimizedRoute? get primaryRoute => routes.isEmpty ? null : routes.first;

  factory OptimizeResult.fromJson(Map<String, dynamic> json) => OptimizeResult(
        totalDrivingTimeSeconds: _toInt(json['totalDrivingTimeSeconds']),
        totalDistanceMeters: _toDouble(json['totalDistanceMeters']),
        routes: (json['routes'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(OptimizedRoute.fromJson)
            .toList(),
        skippedVisits: (json['skippedVisits'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SkippedVisit.fromJson)
            .toList(),
      );
}

// ─── Helpers de parsing ──────────────────────────────────────

List<GeoPoint> _parseGeometry(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<List<dynamic>>()
      .where((p) => p.length >= 2)
      .map(GeoPoint.fromList)
      .toList();
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _toDate(dynamic value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}

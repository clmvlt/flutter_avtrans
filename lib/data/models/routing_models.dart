import 'geo_point.dart';

/// Résultat d'un calcul d'itinéraire multi-points ordonné (`/routing/route`).
///
/// L'itinéraire passe par tous les points DANS L'ORDRE FOURNI (aucune
/// réoptimisation) — utilisé pour rafraîchir le tracé après un ajustement
/// manuel de l'ordre des arrêts.
class RouteResult {
  final double distanceMeters;
  final int durationSeconds;
  final List<GeoPoint> geometry;

  const RouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.geometry,
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) => RouteResult(
        distanceMeters: _toDouble(json['distanceMeters']),
        durationSeconds: _toInt(json['durationSeconds']),
        geometry: _parseGeometry(json['geometry']),
      );

  static List<GeoPoint> _parseGeometry(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<List<dynamic>>()
        .where((p) => p.length >= 2)
        .map(GeoPoint.fromList)
        .toList();
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

import 'dart:convert';

import 'geo_point.dart';
import 'tour_stop.dart';

/// État d'une tournée dans son cycle de vie.
enum TourStatus {
  /// En cours de construction : ajout d'adresses et choix de l'ordre.
  draft,

  /// Validée : mode livraison, lecture seule + navigation.
  delivery,
}

/// Une tournée : un point de départ (dépôt), une liste ordonnée d'arrêts, et —
/// après optimisation/calcul — un tracé routier et ses totaux.
///
/// Modèle persisté localement (voir `TourService`).
class Tour {
  final String id;
  String name;
  final DateTime createdAt;
  final List<TourStop> stops;

  /// Étape du cycle de vie (édition vs livraison).
  TourStatus status;

  /// Point de départ ET de retour de la tournée (aller-retour). Demandé à
  /// l'utilisateur lors de l'optimisation. `null` tant qu'aucune optimisation.
  GeoPoint? depot;

  /// L'ordre actuel provient d'une optimisation automatique (vs ajusté à la main).
  bool optimized;

  /// Totaux du dernier tracé calculé (optimisation ou recalcul manuel).
  double? totalDistanceMeters;
  int? totalDrivingSeconds;

  /// Tracé complet (dépôt → arrêts → dépôt) pour l'affichage carte.
  List<GeoPoint> routeGeometry;

  Tour({
    required this.id,
    required this.name,
    required this.createdAt,
    List<TourStop>? stops,
    this.status = TourStatus.draft,
    this.depot,
    this.optimized = false,
    this.totalDistanceMeters,
    this.totalDrivingSeconds,
    List<GeoPoint>? routeGeometry,
  })  : stops = stops ?? [],
        routeGeometry = routeGeometry ?? [];

  int get stopCount => stops.length;

  bool get isDraft => status == TourStatus.draft;
  bool get isDelivery => status == TourStatus.delivery;

  /// Arrêts effectivement routables (non écartés par l'optimisation).
  List<TourStop> get activeStops => stops.where((s) => !s.skipped).toList();

  /// Arrêts écartés (non rattachables au réseau routier).
  List<TourStop> get skippedStops => stops.where((s) => s.skipped).toList();

  bool get hasRoute => routeGeometry.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'stops': stops.map((s) => s.toJson()).toList(),
        if (depot != null) 'depot': depot!.toJson(),
        'optimized': optimized,
        if (totalDistanceMeters != null)
          'totalDistanceMeters': totalDistanceMeters,
        if (totalDrivingSeconds != null)
          'totalDrivingSeconds': totalDrivingSeconds,
        if (routeGeometry.isNotEmpty)
          'routeGeometry': routeGeometry.map((p) => p.toJson()).toList(),
      };

  factory Tour.fromJson(Map<String, dynamic> json) {
    return Tour(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: TourStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TourStatus.draft,
      ),
      stops: (json['stops'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TourStop.fromJson)
          .toList(),
      depot: json['depot'] is Map
          ? GeoPoint.fromJson(json['depot'] as Map<String, dynamic>)
          : null,
      optimized: json['optimized'] == true,
      totalDistanceMeters: (json['totalDistanceMeters'] as num?)?.toDouble(),
      totalDrivingSeconds: (json['totalDrivingSeconds'] as num?)?.toInt(),
      routeGeometry: (json['routeGeometry'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GeoPoint.fromJson)
          .toList(),
    );
  }

  /// Sérialise une liste de tournées en JSON.
  static String encodeList(List<Tour> tours) =>
      jsonEncode(tours.map((t) => t.toJson()).toList());

  /// Désérialise une liste de tournées depuis JSON.
  static List<Tour> decodeList(String source) {
    final list = jsonDecode(source) as List<dynamic>;
    return list.whereType<Map<String, dynamic>>().map(Tour.fromJson).toList();
  }
}

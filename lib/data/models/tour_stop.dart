import 'address_suggestion.dart';

/// Un arrêt d'une tournée : une adresse + ses métadonnées de routage
/// (renseignées après optimisation / calcul d'itinéraire).
class TourStop {
  /// Identifiant stable (= `visitId` envoyé à l'optimisation).
  final String id;
  final AddressSuggestion address;

  /// Distance cumulée depuis le départ (m), après optimisation. `null` sinon.
  double? cumulativeDistanceMeters;

  /// Temps de conduite cumulé depuis le départ (s), après optimisation.
  int? cumulativeDrivingSeconds;

  /// Heure d'arrivée estimée, après optimisation.
  DateTime? arrivalTime;

  /// Arrêt écarté par l'optimisation (non rattachable au réseau routier).
  bool skipped;
  String? skipReason; // UNROUTABLE | TOO_FAR

  TourStop({
    required this.id,
    required this.address,
    this.cumulativeDistanceMeters,
    this.cumulativeDrivingSeconds,
    this.arrivalTime,
    this.skipped = false,
    this.skipReason,
  });

  double get lat => address.lat;
  double get lon => address.lon;
  String get label => address.label;

  static int _counter = 0;

  /// Génère un identifiant d'arrêt unique.
  static String newId() {
    _counter = (_counter + 1) % 100000;
    return '${DateTime.now().microsecondsSinceEpoch}-$_counter';
  }

  /// Réinitialise les métadonnées de routage (ordre devenu obsolète).
  void clearRouting() {
    cumulativeDistanceMeters = null;
    cumulativeDrivingSeconds = null;
    arrivalTime = null;
    skipped = false;
    skipReason = null;
  }

  TourStop withAddress(AddressSuggestion newAddress) => TourStop(
        id: id,
        address: newAddress,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'address': address.toJson(),
        if (cumulativeDistanceMeters != null)
          'cumulativeDistanceMeters': cumulativeDistanceMeters,
        if (cumulativeDrivingSeconds != null)
          'cumulativeDrivingSeconds': cumulativeDrivingSeconds,
        if (arrivalTime != null) 'arrivalTime': arrivalTime!.toIso8601String(),
        if (skipped) 'skipped': true,
        if (skipReason != null) 'skipReason': skipReason,
      };

  factory TourStop.fromJson(Map<String, dynamic> json) {
    // Nouveau format : { id, address: {...}, ...routage }
    if (json['address'] is Map) {
      return TourStop(
        id: json['id']?.toString() ?? newId(),
        address:
            AddressSuggestion.fromJson(json['address'] as Map<String, dynamic>),
        cumulativeDistanceMeters: (json['cumulativeDistanceMeters'] as num?)
            ?.toDouble(),
        cumulativeDrivingSeconds:
            (json['cumulativeDrivingSeconds'] as num?)?.toInt(),
        arrivalTime: json['arrivalTime'] is String
            ? DateTime.tryParse(json['arrivalTime'] as String)
            : null,
        skipped: json['skipped'] == true,
        skipReason: json['skipReason'] as String?,
      );
    }
    // Ancien format : l'objet EST une AddressSuggestion.
    return TourStop(id: newId(), address: AddressSuggestion.fromJson(json));
  }
}

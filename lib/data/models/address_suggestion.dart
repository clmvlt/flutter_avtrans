import 'package:equatable/equatable.dart';

/// Adresse normalisée renvoyée par l'API de geocoding ORS.
///
/// Représente une adresse résolue (saisie manuellement ou scannée) avec son
/// point GPS, utilisée comme arrêt d'une tournée.
class AddressSuggestion extends Equatable {
  /// Libellé complet prêt à afficher, ex. « 12 Rue du Bocage, 35000 Rennes ».
  final String label;
  final String? houseNumber;
  final String? street;
  final String? postcode;
  final String? city;
  final double lat;
  final double lon;

  /// Score de pertinence ORS (tri décroissant) — peut être absent.
  final double? score;

  /// Distance (en mètres) à la position de référence fournie à la recherche
  /// (`lat`/`lon`). `null` si aucune position n'a été fournie.
  final double? distanceMeters;

  /// Niveau du résultat : `"street"` (voie agrégée, sans numéro) ou
  /// `"housenumber"` (adresse précise). `null` pour un point manuel.
  final String? type;

  const AddressSuggestion({
    required this.label,
    this.houseNumber,
    this.street,
    this.postcode,
    this.city,
    required this.lat,
    required this.lon,
    this.score,
    this.distanceMeters,
    this.type,
  });

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    return AddressSuggestion(
      label: (json['label'] as String?)?.trim() ?? '',
      houseNumber: json['houseNumber'] as String?,
      street: json['street'] as String?,
      postcode: json['postcode'] as String?,
      city: json['city'] as String?,
      lat: _toDouble(json['lat']),
      lon: _toDouble(json['lon']),
      score: json['score'] == null ? null : _toDouble(json['score']),
      distanceMeters:
          json['distanceMeters'] == null ? null : _toDouble(json['distanceMeters']),
      type: json['type'] as String?,
    );
  }

  /// Sérialisation pour la persistance (la distance est contextuelle à la
  /// position de l'utilisateur au moment de la recherche : non persistée).
  Map<String, dynamic> toJson() => {
        'label': label,
        if (houseNumber != null) 'houseNumber': houseNumber,
        if (street != null) 'street': street,
        if (postcode != null) 'postcode': postcode,
        if (city != null) 'city': city,
        'lat': lat,
        'lon': lon,
        if (score != null) 'score': score,
        if (type != null) 'type': type,
      };

  /// Ligne secondaire (rue / ville) quand le label n'est pas suffisant.
  String get secondaryLine {
    final parts = <String>[
      if ((postcode ?? '').isNotEmpty) postcode!,
      if ((city ?? '').isNotEmpty) city!,
    ];
    return parts.join(' ');
  }

  /// Distance formatée pour l'affichage (ex. « 740 m », « 9,0 km »), ou `null`.
  /// Les mètres sont arrondis à la dizaine pour un affichage plus lisible.
  String? get distanceLabel {
    final meters = distanceMeters;
    if (meters == null) return null;
    if (meters < 1000) {
      final rounded = (meters / 10).round() * 10;
      if (rounded < 1000) return '$rounded m';
    }
    final km = meters / 1000;
    return km < 10
        ? '${km.toStringAsFixed(1).replaceAll('.', ',')} km'
        : '${km.round()} km';
  }

  /// Résultat « voie agrégée » (liste des rues, sans numéro).
  bool get isStreet => type == 'street';

  /// Résultat « adresse précise » (avec numéro de voie).
  bool get isHouseNumber => type == 'housenumber';

  /// Indique un point posé manuellement sur la carte (sans adresse résolue).
  bool get isManualPoint => street == null && postcode == null && city == null;

  /// Crée un point GPS posé manuellement sur la carte (pas d'adresse).
  factory AddressSuggestion.manualPoint(double lat, double lon) {
    return AddressSuggestion(
      label: 'Point GPS · ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
      lat: lat,
      lon: lon,
    );
  }

  /// Copie en remplaçant les coordonnées (point ajusté sur la carte).
  AddressSuggestion copyWith({double? lat, double? lon}) => AddressSuggestion(
        label: label,
        houseNumber: houseNumber,
        street: street,
        postcode: postcode,
        city: city,
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        score: score,
        distanceMeters: distanceMeters,
        type: type,
      );

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  @override
  List<Object?> get props =>
      [label, houseNumber, street, postcode, city, lat, lon];
}

import 'dart:convert';

import 'address_suggestion.dart';

/// Une tournée : un nom et une liste ordonnée d'arrêts (adresses).
///
/// Modèle persisté localement (voir `TourService`). Les arrêts restent tant
/// qu'ils ne sont pas explicitement supprimés.
class Tour {
  final String id;
  String name;
  final DateTime createdAt;
  final List<AddressSuggestion> stops;

  Tour({
    required this.id,
    required this.name,
    required this.createdAt,
    List<AddressSuggestion>? stops,
  }) : stops = stops ?? [];

  int get stopCount => stops.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'stops': stops.map((s) => s.toJson()).toList(),
      };

  factory Tour.fromJson(Map<String, dynamic> json) {
    return Tour(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      stops: (json['stops'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AddressSuggestion.fromJson)
          .toList(),
    );
  }

  /// Sérialise une liste de tournées en JSON.
  static String encodeList(List<Tour> tours) =>
      jsonEncode(tours.map((t) => t.toJson()).toList());

  /// Désérialise une liste de tournées depuis JSON.
  static List<Tour> decodeList(String source) {
    final list = jsonDecode(source) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(Tour.fromJson)
        .toList();
  }
}

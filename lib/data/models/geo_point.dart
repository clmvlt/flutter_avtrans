/// Point géographique simple (couche data, sans dépendance carto).
class GeoPoint {
  final double lat;
  final double lon;

  const GeoPoint(this.lat, this.lon);

  factory GeoPoint.fromJson(Map<String, dynamic> json) =>
      GeoPoint(_toDouble(json['lat']), _toDouble(json['lon']));

  /// Depuis un couple `[lat, lon]` (format `geometry` de l'API routing).
  factory GeoPoint.fromList(List<dynamic> pair) =>
      GeoPoint(_toDouble(pair[0]), _toDouble(pair[1]));

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon};

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

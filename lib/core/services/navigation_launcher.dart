import 'package:url_launcher/url_launcher.dart';

/// Applications de navigation GPS prises en charge.
enum NavigationApp { googleMaps, waze, appleMaps, system }

extension NavigationAppX on NavigationApp {
  /// Clé stable pour la persistance.
  String get key => name;

  String get label => switch (this) {
        NavigationApp.googleMaps => 'Google Maps',
        NavigationApp.waze => 'Waze',
        NavigationApp.appleMaps => 'Plans (Apple)',
        NavigationApp.system => 'Application par défaut',
      };

  static NavigationApp fromKey(String? key) {
    return NavigationApp.values.firstWhere(
      (a) => a.key == key,
      orElse: () => NavigationApp.googleMaps,
    );
  }
}

/// Construit les liens et lance la navigation vers un point dans l'app choisie.
abstract class NavigationLauncher {
  /// URI de navigation (mode conduite) vers un point unique.
  static Uri pointUri(NavigationApp app, double lat, double lon, {String? label}) {
    switch (app) {
      case NavigationApp.googleMaps:
        return Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
        );
      case NavigationApp.waze:
        return Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
      case NavigationApp.appleMaps:
        return Uri.parse('https://maps.apple.com/?daddr=$lat,$lon&dirflg=d');
      case NavigationApp.system:
        final q = label == null ? '$lat,$lon' : '$lat,$lon(${Uri.encodeComponent(label)})';
        return Uri.parse('geo:$lat,$lon?q=$q');
    }
  }

  /// URI d'itinéraire multi-arrêts (Google Maps gère les waypoints ; les autres
  /// retombent sur la navigation vers le premier arrêt).
  static Uri routeUri(
    NavigationApp app,
    List<({double lat, double lon})> stops, {
    ({double lat, double lon})? origin,
  }) {
    if (stops.isEmpty) {
      return Uri.parse('https://www.google.com/maps');
    }
    if (app == NavigationApp.googleMaps) {
      final destination = stops.last;
      final waypoints = stops
          .take(stops.length - 1)
          .map((s) => '${s.lat},${s.lon}')
          .join('|');
      final params = <String, String>{
        'api': '1',
        'destination': '${destination.lat},${destination.lon}',
        'travelmode': 'driving',
        if (origin != null) 'origin': '${origin.lat},${origin.lon}',
        if (waypoints.isNotEmpty) 'waypoints': waypoints,
      };
      return Uri.https('www.google.com', '/maps/dir/', params);
    }
    // Autres apps : naviguer vers le premier arrêt.
    final first = stops.first;
    return pointUri(app, first.lat, first.lon);
  }

  /// Ouvre la navigation vers un point. Renvoie `false` si aucune app n'a pu
  /// ouvrir le lien.
  static Future<bool> openPoint(
    NavigationApp app,
    double lat,
    double lon, {
    String? label,
  }) async {
    final uri = pointUri(app, lat, lon, label: label);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return true;
    }
    // Repli : ouverture web Google Maps.
    return launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon'),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Ouvre l'itinéraire complet de la tournée.
  static Future<bool> openRoute(
    NavigationApp app,
    List<({double lat, double lon})> stops, {
    ({double lat, double lon})? origin,
  }) async {
    if (stops.isEmpty) return false;
    final uri = routeUri(app, stops, origin: origin);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

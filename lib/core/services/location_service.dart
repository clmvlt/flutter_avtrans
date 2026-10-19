import 'package:geolocator/geolocator.dart';

/// Service de géolocalisation optimisé
class LocationService {
  /// Délai maximal d'une recherche de position : un premier fix (téléphone
  /// redémarré, aucune app n'a localisé depuis) dépasse souvent 3 s.
  static const Duration fixTimeout = Duration(seconds: 10);

  /// Une dernière position connue plus récente est utilisée telle quelle.
  static const Duration lastKnownMaxAge = Duration(minutes: 2);

  /// Précision haute : sur Android, le fournisseur fusionné allume aussi le
  /// GPS. En `medium`, il s'en tient au Wi-Fi et aux antennes et ne répond
  /// jamais sans eux (émulateur, Wi-Fi coupé, dépôt mal couvert).
  static const LocationSettings fixSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: fixTimeout,
  );

  /// Vérifie et demande les permissions de localisation.
  ///
  /// Pas de cache : un refus mémorisé masquait la permission accordée ou la
  /// localisation activée juste après (retour des réglages).
  Future<bool> requestPermission() async {
    try {
      // Vérifie si le service de localisation est activé
      if (!await Geolocator.isLocationServiceEnabled()) return false;

      // Vérifie les permissions
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      // `unableToDetermine` (Web) : le navigateur demandera lui-même.
      return permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (e) {
      // Demande déjà en cours, déclaration manquante…
      return false;
    }
  }

  /// Récupère la position actuelle
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        return null;
      }
      return await Geolocator.getCurrentPosition(locationSettings: fixSettings);
    } catch (e) {
      return null;
    }
  }

  /// Récupère la dernière position connue (instantané)
  Future<Position?> getLastKnownPosition() async {
    try {
      // Pas besoin de vérifier les permissions pour la dernière position
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      // Non supportée sur le Web, permission absente…
      return null;
    }
  }

  /// Récupère la position rapidement avec stratégie optimisée. Ne lève
  /// jamais : sans position, [LocationData.isReal] est à `false`.
  Future<LocationData> getLocation() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return LocationData.unavailable;

    // Stratégie : utiliser la dernière position connue d'abord si récente
    final lastPosition = await getLastKnownPosition();
    if (lastPosition != null &&
        DateTime.now().difference(lastPosition.timestamp) < lastKnownMaxAge) {
      return LocationData.fromPosition(lastPosition);
    }

    // Sinon, récupérer une nouvelle position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: fixSettings,
      );
      return LocationData.fromPosition(position);
    } catch (e) {
      // En cas d'échec, utiliser la dernière position même si ancienne
      if (lastPosition != null) return LocationData.fromPosition(lastPosition);
      return LocationData.unavailable;
    }
  }

  /// Vérifie si le service de localisation est disponible
  Future<LocationStatus> checkStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationStatus.serviceDisabled;
    }

    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.denied:
        return LocationStatus.permissionDenied;
      case LocationPermission.deniedForever:
        return LocationStatus.permissionDeniedForever;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationStatus.granted;
      case LocationPermission.unableToDetermine:
        return LocationStatus.permissionDenied;
    }
  }

  /// Ouvre les paramètres de localisation du téléphone
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Ouvre les paramètres de l'application
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}

/// Données de localisation
class LocationData {
  final double latitude;
  final double longitude;
  final bool isReal;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.isReal,
  });

  LocationData.fromPosition(Position position)
    : this(
        latitude: position.latitude,
        longitude: position.longitude,
        isReal: true,
      );

  /// Aucune position disponible.
  static const LocationData unavailable = LocationData(
    latitude: 0.0,
    longitude: 0.0,
    isReal: false,
  );
}

/// Statut de la localisation
enum LocationStatus {
  granted,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
}

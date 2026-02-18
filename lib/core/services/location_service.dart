import 'package:geolocator/geolocator.dart';

/// Service de géolocalisation optimisé
class LocationService {
  // Cache des permissions pour éviter les vérifications répétées
  bool? _hasPermission;
  DateTime? _lastPermissionCheck;

  /// Vérifie et demande les permissions de localisation (avec cache)
  Future<bool> requestPermission() async {
    // Utilise le cache si vérifié il y a moins de 30 secondes
    if (_hasPermission != null &&
        _lastPermissionCheck != null &&
        DateTime.now().difference(_lastPermissionCheck!).inSeconds < 30) {
      return _hasPermission!;
    }

    bool serviceEnabled;
    LocationPermission permission;

    // Vérifie si le service de localisation est activé
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _hasPermission = false;
      _lastPermissionCheck = DateTime.now();
      return false;
    }

    // Vérifie les permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _hasPermission = false;
        _lastPermissionCheck = DateTime.now();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _hasPermission = false;
      _lastPermissionCheck = DateTime.now();
      return false;
    }

    _hasPermission = true;
    _lastPermissionCheck = DateTime.now();
    return true;
  }

  /// Récupère la position actuelle (optimisé)
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        return null;
      }

      // Utilise une précision moyenne pour plus de rapidité
      // La précision "medium" utilise le WiFi/réseau au lieu du GPS pur
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,  // Plus rapide que high
          timeLimit: Duration(seconds: 5),     // Timeout réduit
        ),
      );
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
      return null;
    }
  }

  /// Récupère la position rapidement avec stratégie optimisée
  Future<LocationData> getLocation() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      return const LocationData(
        latitude: 0.0,
        longitude: 0.0,
        isReal: false,
      );
    }

    // Stratégie : utiliser la dernière position connue d'abord si récente
    final lastPosition = await Geolocator.getLastKnownPosition();

    // Si on a une position récente (< 2 minutes), l'utiliser directement
    if (lastPosition != null) {
      final age = DateTime.now().difference(lastPosition.timestamp);
      if (age.inMinutes < 2) {
        return LocationData(
          latitude: lastPosition.latitude,
          longitude: lastPosition.longitude,
          isReal: true,
        );
      }
    }

    // Sinon, récupérer une nouvelle position avec timeout court
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),  // Très court
        ),
      );
      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        isReal: true,
      );
    } catch (e) {
      // En cas d'échec, utiliser la dernière position même si ancienne
      if (lastPosition != null) {
        return LocationData(
          latitude: lastPosition.latitude,
          longitude: lastPosition.longitude,
          isReal: true,
        );
      }
    }

    // Valeur par défaut si aucune position disponible
    return const LocationData(
      latitude: 0.0,
      longitude: 0.0,
      isReal: false,
    );
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
}

/// Statut de la localisation
enum LocationStatus {
  granted,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
}

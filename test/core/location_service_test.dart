import 'dart:async';

import 'package:av_pointage/core/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// Géolocalisation du téléphone simulée, sans plugin natif.
class _FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;

  /// Réponse de l'utilisateur au dialogue de permission.
  LocationPermission answer = LocationPermission.denied;
  Object? requestError;

  Position? lastKnown;
  Object? lastKnownError;

  /// Fix renvoyé ; `null` = aucun fix avant la limite de temps.
  Position? fix;
  LocationSettings? fixSettings;
  int fixes = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    if (requestError != null) throw requestError!;
    return permission = answer;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    if (lastKnownError != null) throw lastKnownError!;
    return lastKnown;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    fixes++;
    fixSettings = locationSettings;
    return fix ?? (throw TimeoutException(null, locationSettings?.timeLimit));
  }
}

Position _position(
  double latitude,
  double longitude, {
  Duration age = Duration.zero,
}) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime.now().subtract(age),
  accuracy: 12,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  final original = GeolocatorPlatform.instance;
  late _FakeGeolocator geo;
  late LocationService service;

  setUp(() {
    geo = _FakeGeolocator();
    GeolocatorPlatform.instance = geo;
    service = LocationService();
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  test('should_ask_high_accuracy_fix_when_no_recent_position', () async {
    geo.fix = _position(48.11, -1.68);

    final location = await service.getLocation();

    expect(location.isReal, isTrue);
    expect(location.latitude, 48.11);
    expect(location.longitude, -1.68);
    // En `medium`, Android n'allume pas le GPS : aucun fix sans Wi-Fi.
    expect(geo.fixSettings?.accuracy, LocationAccuracy.high);
    expect(geo.fixSettings?.timeLimit, LocationService.fixTimeout);
  });

  test('should_use_last_known_position_when_recent', () async {
    geo.lastKnown = _position(48.11, -1.68, age: const Duration(seconds: 30));

    final location = await service.getLocation();

    expect(location.isReal, isTrue);
    expect(location.latitude, 48.11);
    expect(geo.fixes, 0);
  });

  test('should_use_old_position_when_no_fix_in_time', () async {
    geo.lastKnown = _position(47.2, -1.55, age: const Duration(hours: 1));

    final location = await service.getLocation();

    expect(geo.fixes, 1);
    expect(location.isReal, isTrue);
    expect(location.latitude, 47.2);
  });

  test('should_return_unavailable_when_no_fix_and_no_last_position', () async {
    final location = await service.getLocation();

    expect(location.isReal, isFalse);
  });

  test('should_search_fix_when_last_position_unsupported', () async {
    // Le Web ne connaît pas de dernière position : le plugin lève.
    geo.lastKnownError = UnsupportedError('getLastKnownPosition');
    geo.fix = _position(48.11, -1.68);

    final location = await service.getLocation();

    expect(location.isReal, isTrue);
  });

  test('should_return_unavailable_when_location_disabled', () async {
    geo.serviceEnabled = false;
    geo.fix = _position(48.11, -1.68);

    final location = await service.getLocation();

    expect(location.isReal, isFalse);
    expect(geo.fixes, 0);
  });

  test('should_find_position_when_location_enabled_right_after', () async {
    geo.serviceEnabled = false;
    geo.fix = _position(48.11, -1.68);
    expect((await service.getLocation()).isReal, isFalse);

    // Retour des réglages, quelques secondes plus tard.
    geo.serviceEnabled = true;

    expect((await service.getLocation()).isReal, isTrue);
  });

  test(
    'should_find_position_when_permission_granted_right_after_refusal',
    () async {
      geo.permission = LocationPermission.denied;
      geo.fix = _position(48.11, -1.68);
      expect((await service.getLocation()).isReal, isFalse);

      // « Autoriser » : le dialogue est de nouveau proposé et accepté.
      geo.answer = LocationPermission.whileInUse;

      expect(await service.requestPermission(), isTrue);
      expect((await service.getLocation()).isReal, isTrue);
    },
  );

  test('should_return_unavailable_when_permission_request_fails', () async {
    geo.permission = LocationPermission.denied;
    geo.requestError = const PermissionRequestInProgressException('en cours');

    final location = await service.getLocation();

    expect(location.isReal, isFalse);
  });

  test('should_let_browser_ask_when_permission_undetermined', () async {
    geo.permission = LocationPermission.unableToDetermine;
    geo.fix = _position(48.11, -1.68);

    expect((await service.getLocation()).isReal, isTrue);
  });
}

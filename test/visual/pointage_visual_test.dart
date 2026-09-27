// Capture de la page Pointage (référence du design), pour vérifier qu'elle
// n'a pas bougé avec le dock partagé. Opt-in : VISUAL=1 flutter test test/visual
import 'dart:io';

import 'package:av_pointage/core/services/location_service.dart';
import 'package:av_pointage/presentation/screens/services/pointage_controller.dart';
import 'package:av_pointage/presentation/screens/services/services_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_app_data.dart';
import 'fake_data.dart';
import 'visual_harness.dart';

final _skip = Platform.environment['VISUAL'] == null;

/// Position toujours disponible, sans plugin natif.
class _FakeLocation extends LocationService {
  @override
  Future<LocationStatus> checkStatus() async => LocationStatus.granted;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<LocationData> getLocation() async =>
      const LocationData(latitude: 48.11, longitude: -1.68, isReal: true);
}

void main() {
  setUpAll(loadAppFonts);

  for (final dark in [false, true]) {
    testWidgets('pointage${dark ? '_dark' : ''}', (tester) async {
      await setUpApp(user: fakeUser(), routes: appRoutes());
      final controller = PointageController(
        locationService: _FakeLocation(),
        now: () => DateTime(2026, 9, 27, 10, 0),
      );
      await pumpScreen(
        tester,
        ServicesScreen(controller: controller),
        dark: dark,
      );
      await capture(tester, 'pointage${dark ? '_dark' : ''}');
      // Arrête l'horloge 1 Hz avant la fin du test.
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }, skip: _skip);
  }
}

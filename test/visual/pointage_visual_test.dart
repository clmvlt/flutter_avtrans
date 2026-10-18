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
import 'fake_services.dart';
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

  // 6 h de travail sans pause : carte « Pause conseillée ».
  testWidgets('pointage_pause', (tester) async {
    final service = fakeWorkService(
      's1',
      DateTime(2026, 9, 27, 4, 0),
      now: DateTime(2026, 9, 27, 10, 5),
    );
    await setUpApp(user: fakeUser(), routes: [
      FakeRoute('GET', '/services/active',
          (_, _) => {'success': true, 'service': service}),
      FakeRoute('GET', '/services/user/daily', (_, _) => fakeJournee(
            DateTime(2026, 9, 27),
            now: DateTime(2026, 9, 27, 10, 5),
            services: [service],
          )),
      ...appRoutes(),
    ]);
    final controller = PointageController(
      locationService: _FakeLocation(),
      now: () => DateTime(2026, 9, 27, 10, 5),
    );
    await pumpScreen(tester, ServicesScreen(controller: controller));
    await capture(tester, 'pointage_pause');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  }, skip: _skip);

  // Service de nuit : commencé la veille à 21:00, pause de 01:00 à 02:00, il
  // est 03:00. La journée affichée est celle de la veille.
  testWidgets('pointage_nuit', (tester) async {
    final now = DateTime(2026, 10, 13, 3);
    final service = fakeWorkService(
      's1',
      DateTime(2026, 10, 12, 21),
      now: now,
      pauses: [(DateTime(2026, 10, 13, 1), DateTime(2026, 10, 13, 2))],
    );
    await setUpApp(user: fakeUser(), routes: [
      FakeRoute('GET', '/services/active',
          (_, _) => {'success': true, 'service': service}),
      // Après minuit, la journée reste celle du 12/10.
      FakeRoute('GET', '/services/user/daily', (_, _) => fakeJournee(
            DateTime(2026, 10, 12),
            now: now,
            services: [service],
          )),
      FakeRoute('GET', '/services/hours', (_, _) => {
            'jour': '2026-10-12',
            'day': fakeHeures(5 * 3600, enCours: true),
            'week': fakeHeures(5 * 3600, enCours: true),
            'month': fakeHeures(5 * 3600, enCours: true),
            'lastMonth': fakeHeuresDecimal(151.75),
            'year': fakeHeuresDecimal(1203.5, enCours: true),
          }),
      ...appRoutes(),
    ]);
    final controller = PointageController(
      locationService: _FakeLocation(),
      now: () => now,
    );
    await pumpScreen(tester, ServicesScreen(controller: controller));
    await capture(tester, 'pointage_nuit');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  }, skip: _skip);

}

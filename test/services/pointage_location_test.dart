import 'dart:async';

import 'package:av_pointage/core/services/break_reminder_service.dart';
import 'package:av_pointage/core/services/location_service.dart';
import 'package:av_pointage/presentation/screens/services/pointage_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual/fake_data.dart';
import '../visual/fake_services.dart';
import '../visual/visual_harness.dart';

/// Rappel sans plugin natif.
class _SilentReminder extends BreakReminderService {
  _SilentReminder() : super(enabled: false);

  @override
  Future<void> scheduleAt(DateTime at) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> requestPermission() async {}
}

/// Localisation pilotée par le test : chaque recherche attend [search].
class _ScriptedLocation extends LocationService {
  LocationStatus status = LocationStatus.granted;

  /// Statut après la recherche (permission accordée dans le dialogue).
  LocationStatus? statusAfterSearch;
  Completer<LocationData> search = Completer();
  int searches = 0;

  @override
  Future<LocationStatus> checkStatus() async => status;

  @override
  Future<bool> requestPermission() async => status == LocationStatus.granted;

  @override
  Future<LocationData> getLocation() async {
    searches++;
    final location = await search.future;
    status = statusAfterSearch ?? status;
    return location;
  }
}

const _here = LocationData(latitude: 48.11, longitude: -1.68, isReal: true);

// Heures UTC : le test ne dépend pas du fuseau de la machine.
DateTime _at(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 9, 27, hour, minute);

/// En service depuis 8 h ; la pause démarre à 10 h.
List<FakeRoute> _routes() {
  final service = fakeWorkService('s1', _at(8), now: _at(10));
  return [
    FakeRoute(
      'GET',
      '/services/active',
      (_, _) => {'success': true, 'service': service},
    ),
    FakeRoute(
      'GET',
      '/services/hours',
      (_, _) => {'day': fakeHeures(2 * 3600, enCours: true)},
    ),
    FakeRoute(
      'GET',
      '/services/user/daily',
      (_, _) => fakeJournee(_at(0), now: _at(10), services: [service]),
    ),
    FakeRoute(
      'POST',
      '/services/break/start',
      (_, _) => fakeWorkService(
        's1',
        _at(8),
        now: _at(10),
        pauses: [(_at(10), null)],
      ),
    ),
  ];
}

void main() {
  late _ScriptedLocation location;

  setUp(() async {
    location = _ScriptedLocation();
    await setUpApp(user: fakeUser(), routes: _routes());
  });

  PointageController controller() => PointageController(
    breakReminder: _SilentReminder(),
    locationService: location,
    now: () => _at(10),
    prerequisitesTimeout: const Duration(milliseconds: 100),
  );

  test('should_share_one_search_when_action_starts_during_preload', () async {
    final c = controller();
    final resumed = c.onAppResumed();
    await pumpEventQueue();
    expect(location.searches, 1);

    final action = c.startBreak();
    await pumpEventQueue();

    expect(c.actionPhase, PointageActionPhase.locating);
    expect(location.searches, 1);

    location.search.complete(_here);

    expect(await action, isA<PointageActionSuccess>());
    await resumed;
    expect(location.searches, 1);
    expect(c.locationReadiness, LocationReadiness.ready);
    c.dispose();
  });

  test(
    'should_not_ask_permission_again_when_app_resumes_after_refusal',
    () async {
      location.status = LocationStatus.permissionDenied;
      final c = controller();

      await c.onAppResumed();

      expect(location.searches, 0);
      expect(c.locationStatus, LocationStatus.permissionDenied);
      c.dispose();
    },
  );

  test(
    'should_show_granted_when_permission_given_during_first_search',
    () async {
      location
        ..status = LocationStatus.permissionDenied
        ..statusAfterSearch = LocationStatus.granted
        ..search.complete(_here);
      final c = controller();

      await c.init();

      expect(c.locationStatus, LocationStatus.granted);
      expect(c.locationReadiness, LocationReadiness.ready);
      c.dispose();
    },
  );

  test('should_report_no_location_when_search_fails', () async {
    location.search.complete(LocationData.unavailable);
    final c = controller();

    final result = await c.startBreak();

    expect(result, isA<PointageActionNoLocation>());
    expect(c.locationReadiness, LocationReadiness.notFound);
    c.dispose();
  });

  test('should_find_position_when_retrying_after_not_found', () async {
    location.search.complete(LocationData.unavailable);
    final c = controller();
    await c.onAppResumed();
    expect(c.locationReadiness, LocationReadiness.notFound);

    location.search = Completer()..complete(_here);
    await c.onAppResumed();

    expect(location.searches, 2);
    expect(c.locationReadiness, LocationReadiness.ready);
    c.dispose();
  });
}

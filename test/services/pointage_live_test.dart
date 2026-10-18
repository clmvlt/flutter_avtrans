import 'package:av_pointage/core/services/break_reminder_service.dart';
import 'package:av_pointage/core/services/location_service.dart';
import 'package:av_pointage/core/utils/live_counter.dart';
import 'package:av_pointage/presentation/screens/services/pointage_controller.dart';
import 'package:av_pointage/presentation/screens/services/services_screen.dart';
import 'package:flutter/widgets.dart';
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

/// Serveur simulé : un service de travail (ou aucun), calculé à [now].
class _Server {
  _Server(this.now);

  DateTime now;
  DateTime? debut;
  List<FakePause> pauses = [];

  /// Totaux de la période : (secondes, enCours) à l'instant [now].
  Map<String, dynamic> Function(_Server server) hours = (_) => {};

  /// Le service compte-t-il dans « aujourd'hui » (débuté aujourd'hui) ?
  bool startedToday = true;

  Map<String, dynamic>? get service => debut == null
      ? null
      : fakeWorkService('s1', debut!, now: now, pauses: pauses);

  List<FakeRoute> get routes => [
    FakeRoute(
      'GET',
      '/services/active',
      (_, _) => {'success': true, 'service': service},
    ),
    FakeRoute('GET', '/services/hours', (_, _) => hours(this)),
    FakeRoute(
      'GET',
      '/services/user/daily',
      (_, _) => [if (startedToday && service != null) service],
    ),
    FakeRoute('POST', '/services/break/start', (_, _) {
      pauses = [...pauses, (now, null)];
      return service;
    }),
  ];
}

void main() {
  var monotonic = Duration.zero;

  setUp(() {
    monotonic = Duration.zero;
    LiveClock.debugSource = () => monotonic;
  });
  tearDown(() => LiveClock.debugSource = null);

  PointageController controller(_Server server) => PointageController(
    breakReminder: _SilentReminder(),
    locationService: _FakeLocation(),
    now: () => server.now,
  );

  void tick([Duration d = const Duration(seconds: 1)]) => monotonic += d;

  group('service de nuit en cours', () {
    // 12/10 21:00, pause le 13/10 de 01:00 à 02:00, il est 03:00.
    _Server nightServer() => _Server(DateTime(2026, 10, 13, 3))
      ..debut = DateTime(2026, 10, 12, 21)
      ..pauses = [(DateTime(2026, 10, 13, 1), DateTime(2026, 10, 13, 2))]
      ..startedToday = false
      ..hours = (s) => {
        'calculeLe': s.now.toIso8601String(),
        // Le service compte sur le 12/10 : rien aujourd'hui.
        'day': fakeHeures(0),
        'week': fakeHeures(5 * 3600, enCours: true),
        'month': fakeHeures(5 * 3600, enCours: true),
        'lastMonth': fakeHeures(0),
        'year': fakeHeures(5 * 3600, enCours: true),
      };

    test('should_show_5h_and_advance_when_night_service_in_progress', () async {
      final server = nightServer();
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);

      await c.load();

      expect(c.status, PointageStatus.onDuty);
      expect(c.activeStartedOtherDay, isTrue);
      expect(c.workedTime, const Duration(hours: 5));
      expect(c.workedHours!.week!.live.value, const Duration(hours: 5));
      expect(c.workedHours!.day!.live.value, Duration.zero);
      expect(c.isLive, isTrue);

      tick();

      expect(c.workedTime, const Duration(hours: 5, seconds: 1));
      expect(
        c.workedHours!.week!.live.value,
        const Duration(hours: 5, seconds: 1),
      );
      // « Aujourd'hui » reste à 0 : le service compte sur son jour de début.
      expect(c.workedHours!.day!.live.value, Duration.zero);
      c.dispose();
    });

    test('should_never_show_negative_values_when_night_service', () async {
      final server = nightServer();
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);

      await c.load();
      tick(const Duration(minutes: 3));

      expect(c.breakTime, const Duration(hours: 1));
      expect(c.breakCount, 1);
      expect(c.serviceCount, 1);
      expect(c.amplitudeToday, const Duration(hours: 6, minutes: 3));
      expect(c.segments, hasLength(2));
      for (final seg in c.segments) {
        expect(seg.duration.isNegative, isFalse);
        expect(seg.end.isBefore(seg.start), isFalse);
      }
      c.dispose();
    });

    testWidgets('should_display_start_day_when_service_began_yesterday', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final server = nightServer();
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);

      await pumpScreen(tester, ServicesScreen(controller: c));

      expect(find.text('Depuis le 12/10 à 21:00'), findsOneWidget);
      expect(find.text('Travaillé sur ce service'), findsOneWidget);
      expect(find.textContaining('5:00'), findsWidgets);
      // Bandeau : semaine et mois à 5h.
      expect(find.text('5h'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    });
  });

  group('pendant une pause', () {
    _Server breakServer() => _Server(DateTime(2026, 10, 13, 11, 30))
      ..debut = DateTime(2026, 10, 13, 8)
      ..pauses = [(DateTime(2026, 10, 13, 11), null)]
      ..hours = (s) => {
        'day': fakeHeures(3 * 3600),
        'week': fakeHeures(20 * 3600),
      };

    test('should_freeze_worked_time_and_advance_break_when_on_break', () async {
      final server = breakServer();
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);

      await c.load();

      expect(c.status, PointageStatus.onBreak);
      expect(c.workedTime, const Duration(hours: 3));
      expect(c.breakTime, const Duration(minutes: 30));

      tick(const Duration(minutes: 1));

      expect(c.workedTime, const Duration(hours: 3));
      expect(c.breakTime, const Duration(minutes: 31));
      expect(c.currentSegmentElapsed, const Duration(minutes: 31));
      c.dispose();
    });

    test('should_use_returned_service_when_break_started', () async {
      final server = _Server(DateTime(2026, 10, 13, 11))
        ..debut = DateTime(2026, 10, 13, 8)
        ..hours = (s) => {'day': fakeHeures(3 * 3600, enCours: true)};
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);
      await c.load();
      expect(c.status, PointageStatus.onDuty);

      final result = await c.startBreak();

      expect(result, isA<PointageActionSuccess>());
      expect(c.status, PointageStatus.onBreak);
      expect(c.workedTime, const Duration(hours: 3));
      tick(const Duration(minutes: 5));
      expect(c.workedTime, const Duration(hours: 3));
      expect(c.breakTime, const Duration(minutes: 5));
      c.dispose();
    });
  });

  group('app en arrière-plan', () {
    _Server dayServer() => _Server(DateTime(2026, 10, 13, 10))
      ..debut = DateTime(2026, 10, 13, 8)
      ..hours = (s) => {
        'day': fakeHeures(
          s.now.difference(DateTime(2026, 10, 13, 8)).inSeconds,
          enCours: true,
        ),
      };

    test('should_be_right_after_10_min_in_background', () async {
      final server = dayServer();
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);
      await c.load();
      expect(c.workedTime, const Duration(hours: 2));

      // 10 min en arrière-plan : le Stopwatch continue…
      server.now = server.now.add(const Duration(minutes: 10));
      tick(const Duration(minutes: 10));
      expect(c.workedTime, const Duration(hours: 2, minutes: 10));

      // … et le retour au premier plan resynchronise.
      await c.onAppResumed();

      expect(c.workedTime, const Duration(hours: 2, minutes: 10));
      expect(
        c.workedHours!.day!.live.value,
        const Duration(hours: 2, minutes: 10),
      );
      c.dispose();
    });

    test('should_catch_up_on_resume_when_stopwatch_paused_in_sleep', () async {
      final server = dayServer();
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);
      await c.load();

      // Veille profonde : l'horloge monotone n'a pas avancé.
      server.now = server.now.add(const Duration(minutes: 10));
      expect(c.workedTime, const Duration(hours: 2));

      await c.onAppResumed();

      expect(c.workedTime, const Duration(hours: 2, minutes: 10));
      tick();
      expect(c.workedTime, const Duration(hours: 2, minutes: 10, seconds: 1));
      c.dispose();
    });
  });

  test('should_show_api_day_total_when_off_duty', () async {
    final server = _Server(DateTime(2026, 10, 13, 18))
      ..hours = (s) => {'day': fakeHeures(7 * 3600 + 30 * 60)};
    await setUpApp(user: fakeUser(), routes: server.routes);
    final c = controller(server);

    await c.load();
    tick(const Duration(minutes: 5));

    expect(c.status, PointageStatus.offDuty);
    expect(c.workedTime, const Duration(hours: 7, minutes: 30));
    expect(c.isLive, isFalse);
    c.dispose();
  });

  test('should_keep_values_when_network_fails', () async {
    await setUpApp(user: fakeUser(), routes: const []);
    final c = controller(_Server(DateTime(2026, 10, 13, 10)));

    await c.load();

    expect(c.loadError, isNotNull);
    expect(c.workedTime, isNull);
    expect(c.segments, isEmpty);
    c.dispose();
  });
}

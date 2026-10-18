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

DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

/// Serveur simulé : un service de travail (ou aucun), calculé à [now], et
/// la journée de travail en cours selon la règle de l'API.
class _Server {
  _Server(this.now);

  DateTime now;
  DateTime? debut;
  DateTime? fin;
  List<FakePause> pauses = [];

  Map<String, dynamic>? get service => debut == null
      ? null
      : fakeWorkService('s1', debut!, now: now, fin: fin, pauses: pauses);

  /// Jour de début du service s'il touche aujourd'hui (commencé aujourd'hui,
  /// en cours, ou terminé aujourd'hui après minuit), sinon aujourd'hui.
  DateTime get jour {
    final today = _date(now);
    final d = debut;
    if (d == null) return today;
    final touches = !d.isBefore(today) ||
        fin == null ||
        (!fin!.isBefore(today) && !fin!.isAfter(now));
    return touches ? _date(d) : today;
  }

  Map<String, dynamic> get journee => fakeJournee(
    jour,
    now: now,
    services: [
      if (service != null && _date(debut!) == jour) service!,
    ],
  );

  List<FakeRoute> get routes => [
    FakeRoute(
      'GET',
      '/services/active',
      (_, _) => {'success': true, 'service': fin == null ? service : null},
    ),
    FakeRoute('GET', '/services/hours', (_, _) {
      final day = journee['heures'];
      final j = journee['date'];
      return {
        'calculeLe': now.toIso8601String(),
        'jour': j,
        'day': day,
        'week': day,
        'month': day,
        'lastMonth': fakeHeures(0),
        'year': day,
      };
    }),
    FakeRoute('GET', '/services/user/daily', (_, _) => journee),
    FakeRoute('POST', '/services/start', (_, _) {
      debut = now;
      fin = null;
      pauses = [];
      return service;
    }),
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

  Future<void> unmount(WidgetTester tester, PointageController c) async {
    // Arrête l'horloge 1 Hz avant la fin du test.
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  }

  group('service de nuit terminé (13/10 à 06:30)', () {
    // 12/10 21:00 → 13/10 06:00, pause de 02:00 à 03:00.
    _Server endedServer() => _Server(DateTime(2026, 10, 13, 6, 30))
      ..debut = DateTime(2026, 10, 12, 21)
      ..fin = DateTime(2026, 10, 13, 6)
      ..pauses = [(DateTime(2026, 10, 13, 2), DateTime(2026, 10, 13, 3))];

    test('should_keep_previous_day_with_8h_frozen_when_night_service_ended', () async {
      final server = endedServer();
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);

      await c.load();

      expect(c.journeeIsToday, isFalse);
      expect(c.journeeDate, DateTime(2026, 10, 12));
      expect(c.journeeTitle, 'Journée du lun. 12/10 (service de nuit)');
      expect(c.moment, PointageMoment.dayDone);
      expect(c.serviceCount, 1);
      expect(c.breakCount, 1);
      expect(c.workedTime, const Duration(hours: 8));
      expect(c.isLive, isFalse);

      tick(const Duration(minutes: 5));

      expect(c.workedTime, const Duration(hours: 8));
      c.dispose();
    });

    testWidgets('should_show_night_day_with_its_service_and_break', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final server = endedServer();
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);

      await pumpScreen(tester, ServicesScreen(controller: c));

      expect(
        find.text('Journée du lun. 12/10 (service de nuit)'),
        findsOneWidget,
      );
      expect(find.text('Aucun pointage pour l\'instant'), findsNothing);
      expect(find.text('21:00 → 06:00 (mar. 13/10)'), findsOneWidget);
      expect(find.text('02:00 → 03:00 (mar. 13/10)'), findsOneWidget);
      expect(find.text('Travaillé · journée du lun. 12/10'), findsOneWidget);
      expect(find.textContaining('8:00'), findsWidgets);
      await unmount(tester, c);
    });
  });

  group('service de nuit en cours (13/10 à 03:30)', () {
    // 12/10 21:00, pause terminée de 02:00 à 03:00.
    _Server runningServer() => _Server(DateTime(2026, 10, 13, 3, 30))
      ..debut = DateTime(2026, 10, 12, 21)
      ..pauses = [(DateTime(2026, 10, 13, 2), DateTime(2026, 10, 13, 3))];

    test('should_keep_previous_day_and_advance_when_night_service_running', () async {
      final server = runningServer();
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);

      await c.load();

      expect(c.status, PointageStatus.onDuty);
      expect(c.journeeIsToday, isFalse);
      expect(c.journeeDate, DateTime(2026, 10, 12));
      // 21:00 → 03:30 moins 1 h de pause.
      expect(c.workedTime, const Duration(hours: 5, minutes: 30));
      expect(
        c.workedHours!.day!.live.value,
        const Duration(hours: 5, minutes: 30),
      );
      expect(c.workedHours!.jour, DateTime(2026, 10, 12));
      expect(c.isLive, isTrue);

      tick();

      expect(c.workedTime, const Duration(hours: 5, minutes: 30, seconds: 1));
      c.dispose();
    });

    test('should_never_show_negative_values_when_night_service', () async {
      final server = runningServer();
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);

      await c.load();
      tick(const Duration(minutes: 3));

      expect(c.breakTime, const Duration(hours: 1));
      expect(c.amplitude, const Duration(hours: 6, minutes: 33));
      expect(c.segments, hasLength(2));
      for (final seg in c.segments) {
        expect(seg.duration.isNegative, isFalse);
        expect(seg.end.isBefore(seg.start), isFalse);
      }
      c.dispose();
    });

    testWidgets('should_label_night_day_when_service_running', (tester) async {
      addTearDown(tester.view.reset);
      final server = runningServer();
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);

      await pumpScreen(tester, ServicesScreen(controller: c));

      expect(
        find.text('Journée du lun. 12/10 (service de nuit)'),
        findsOneWidget,
      );
      expect(find.text('Depuis 21:00'), findsOneWidget);
      expect(find.text('02:00 → 03:00 (mar. 13/10)'), findsOneWidget);
      expect(find.textContaining('5:30'), findsWidgets);
      await unmount(tester, c);
    });
  });

  test('should_switch_to_today_when_new_service_started', () async {
    // Le 13/10 à 21:00, après le service de nuit terminé à 06:00.
    final server = _Server(DateTime(2026, 10, 13, 21))
      ..debut = DateTime(2026, 10, 12, 21)
      ..fin = DateTime(2026, 10, 13, 6)
      ..pauses = [(DateTime(2026, 10, 13, 2), DateTime(2026, 10, 13, 3))];
    await setUpApp(user: fakeUser(), routes: server.routes);
    final c = controller(server);
    await c.load();
    expect(c.journeeIsToday, isFalse);

    final result = await c.startService();
    // Rechargement de la journée et des heures, lancé après l'action.
    await pumpEventQueue();

    expect(result, isA<PointageActionSuccess>());
    expect(c.status, PointageStatus.onDuty);
    expect(c.journeeIsToday, isTrue);
    expect(c.journeeTitle, 'Aujourd\'hui');
    expect(c.journeeDate, DateTime(2026, 10, 13));
    expect(c.serviceCount, 1);
    expect(c.workedTime, Duration.zero);
    tick();
    expect(c.workedTime, const Duration(seconds: 1));
    c.dispose();
  });

  group('salarié de jour', () {
    test('should_show_empty_today_when_day_worker_passes_midnight', () async {
      // Service de la veille 08:00 → 16:00 : il ne touche pas aujourd'hui.
      final server = _Server(DateTime(2026, 10, 13, 0, 30))
        ..debut = DateTime(2026, 10, 12, 8)
        ..fin = DateTime(2026, 10, 12, 16);
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);

      await c.load();

      expect(c.journeeIsToday, isTrue);
      expect(c.journeeTitle, 'Aujourd\'hui');
      expect(c.segments, isEmpty);
      expect(c.moment, PointageMoment.notStarted);
      expect(c.workedTime, Duration.zero);
      c.dispose();
    });

    testWidgets('should_show_today_empty_state_when_no_service', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final server = _Server(DateTime(2026, 10, 13, 0, 30));
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);

      await pumpScreen(tester, ServicesScreen(controller: c));

      expect(find.text('Aujourd\'hui'), findsOneWidget);
      expect(find.text('Aucun pointage pour l\'instant'), findsOneWidget);
      await unmount(tester, c);
    });
  });

  group('pendant une pause', () {
    test('should_freeze_worked_time_and_advance_break_when_on_break', () async {
      final server = _Server(DateTime(2026, 10, 13, 11, 30))
        ..debut = DateTime(2026, 10, 13, 8)
        ..pauses = [(DateTime(2026, 10, 13, 11), null)];
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
        ..debut = DateTime(2026, 10, 13, 8);
      await setUpApp(user: fakeUser(), routes: server.routes);
      final c = controller(server);
      await c.load();
      expect(c.status, PointageStatus.onDuty);

      final result = await c.startBreak();

      expect(result, isA<PointageActionSuccess>());
      expect(c.status, PointageStatus.onBreak);
      // La pause apparaît tout de suite dans la journée.
      expect(c.breakCount, 1);
      tick(const Duration(minutes: 5));
      expect(c.breakTime, const Duration(minutes: 5));
      await pumpEventQueue();
      expect(c.workedTime, const Duration(hours: 3));
      c.dispose();
    });
  });

  group('app en arrière-plan', () {
    _Server dayServer() => _Server(DateTime(2026, 10, 13, 10))
      ..debut = DateTime(2026, 10, 13, 8);

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

  test('should_keep_values_when_network_fails', () async {
    await setUpApp(user: fakeUser(), routes: const []);
    final c = controller(_Server(DateTime(2026, 10, 13, 10)));

    await c.load();

    expect(c.loadError, isNotNull);
    expect(c.workedTime, isNull);
    expect(c.segments, isEmpty);
    expect(c.journeeTitle, 'Aujourd\'hui');
    c.dispose();
  });
}

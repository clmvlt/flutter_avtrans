import 'package:av_pointage/core/services/break_reminder_service.dart';
import 'package:av_pointage/core/services/location_service.dart';
import 'package:av_pointage/presentation/screens/services/pointage_controller.dart';
import 'package:av_pointage/presentation/screens/services/services_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual/fake_data.dart';
import '../visual/visual_harness.dart';

/// Rappel enregistré en mémoire, sans plugin natif.
class _FakeReminder extends BreakReminderService {
  _FakeReminder() : super(enabled: false);

  final List<DateTime> scheduled = [];
  int cancels = 0;

  @override
  Future<void> scheduleAt(DateTime at) async => scheduled.add(at);

  @override
  Future<void> cancel() async => cancels++;

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

// Heures UTC : le test ne dépend pas du fuseau de la machine.
DateTime _at(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 9, 27, hour, minute);

Map<String, dynamic> _pointage(
  String uuid,
  DateTime debut, {
  DateTime? fin,
  bool isBreak = false,
}) => {
  'uuid': uuid,
  'debut': debut.toIso8601String(),
  'fin': fin?.toIso8601String(),
  'isBreak': isBreak,
  'userUuid': 'u-1',
};

/// Journée simulée : pointage ouvert [active] et liste du jour [daily].
List<FakeRoute> _routes({
  Map<String, dynamic>? active,
  required List<Map<String, dynamic>> daily,
}) => [
  FakeRoute(
    'GET',
    '/services/active',
    (_, _) => {'success': true, 'service': active},
  ),
  FakeRoute('GET', '/services/hours', (_, _) => {'day': 6.0}),
  FakeRoute('GET', '/services/user/daily', (_, _) => daily),
];

void main() {
  late _FakeReminder reminder;

  setUp(() => reminder = _FakeReminder());

  PointageController controller(DateTime now) => PointageController(
    breakReminder: reminder,
    locationService: _FakeLocation(),
    now: () => now,
  );

  test('should_ask_for_a_break_when_6h_worked_without_break', () async {
    final service = _pointage('s1', _at(5));
    await setUpApp(
      user: fakeUser(),
      routes: _routes(active: service, daily: [service]),
    );
    final c = controller(_at(11, 5));

    await c.load();

    expect(c.continuousWorkStart, _at(5));
    expect(c.breakDue, isTrue);
    expect(reminder.scheduled, [_at(11)]);
    c.dispose();
  });

  test('should_restart_count_when_break_taken', () async {
    final service = _pointage('s1', _at(5));
    await setUpApp(
      user: fakeUser(),
      routes: _routes(
        active: service,
        daily: [
          service,
          _pointage('b1', _at(8), fin: _at(8, 20), isBreak: true),
        ],
      ),
    );
    final c = controller(_at(12));

    await c.load();

    expect(c.continuousWorkStart, _at(8, 20));
    expect(c.continuousWork, const Duration(hours: 3, minutes: 40));
    expect(c.breakDue, isFalse);
    expect(reminder.scheduled, [_at(14, 20)]);
    c.dispose();
  });

  test('should_cancel_reminder_when_on_break', () async {
    final pause = _pointage('b1', _at(10), isBreak: true);
    await setUpApp(
      user: fakeUser(),
      routes: _routes(active: pause, daily: [_pointage('s1', _at(4)), pause]),
    );
    final c = controller(_at(11));

    await c.load();

    expect(c.breakDue, isFalse);
    expect(reminder.scheduled, isEmpty);
    expect(reminder.cancels, 1);
    c.dispose();
  });

  test('should_cancel_reminder_when_off_duty', () async {
    await setUpApp(
      user: fakeUser(),
      routes: _routes(daily: [_pointage('s1', _at(4), fin: _at(12))]),
    );
    final c = controller(_at(13));

    await c.load();

    expect(c.breakDue, isFalse);
    expect(reminder.cancels, 1);
    c.dispose();
  });

  test('should_keep_scheduled_reminder_when_network_fails', () async {
    await setUpApp(user: fakeUser(), routes: const []);
    final c = controller(_at(13));

    await c.load();

    expect(c.loadError, isNotNull);
    expect(reminder.scheduled, isEmpty);
    expect(reminder.cancels, 0);
    c.dispose();
  });

  for (final (name, now, shown) in [
    ('should_show_break_card_when_6h_worked', _at(11, 5), true),
    ('should_hide_break_card_when_under_6h', _at(10), false),
  ]) {
    testWidgets(name, (tester) async {
      addTearDown(tester.view.reset);
      final service = _pointage('s1', _at(5));
      await setUpApp(
        user: fakeUser(),
        routes: _routes(active: service, daily: [service]),
      );
      final c = controller(now);

      await pumpScreen(tester, ServicesScreen(controller: c));

      expect(
        find.text('Prends une pause'),
        shown ? findsOneWidget : findsNothing,
      );
      // Arrête l'horloge 1 Hz avant la fin du test.
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    });
  }
}

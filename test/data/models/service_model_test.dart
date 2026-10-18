import 'package:av_pointage/core/utils/live_counter.dart';
import 'package:av_pointage/data/models/service_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Service de nuit en cours : 12/10 21:00, pause le 13/10 de 01:00 à 02:00,
/// calculé le 13/10 à 03:00.
const _nightService = {
  'uuid': 's1',
  'debut': '2026-10-12T21:00:00+02:00',
  'fin': null,
  'isBreak': false,
  'latitude': 48.1,
  'longitude': -1.6,
  'latitudeEnd': null,
  'longitudeEnd': null,
  'isAdmin': false,
  'userUuid': 'u-1',
  'modifiedAt': null,
  'modifiedByUuid': null,
  'modifiedByName': null,
  'duree': 21600,
  'calculeLe': '2026-10-13T03:00:00+02:00',
  'enCours': true,
  'pauses': [
    {
      'uuid': 'p1',
      'debut': '2026-10-13T01:00:00+02:00',
      'fin': '2026-10-13T02:00:00+02:00',
      'isBreak': true,
      'isAdmin': false,
      'userUuid': 'u-1',
      'duree': 3600,
      'calculeLe': '2026-10-13T03:00:00+02:00',
      'enCours': false,
      'serviceParentUuid': 's1',
    },
  ],
  'dureePauses': 3600,
  'dureeTravail': 18000,
  'enPause': false,
};

void main() {
  var monotonic = Duration.zero;

  setUp(() {
    monotonic = Duration.zero;
    LiveClock.debugSource = () => monotonic;
  });
  tearDown(() => LiveClock.debugSource = null);

  group('Service.fromJson', () {
    test('should_read_nested_pauses_when_work_service', () {
      final s = Service.fromJson(_nightService);

      expect(s.isBreak, isFalse);
      expect(s.enCours, isTrue);
      expect(s.enPause, isFalse);
      expect(s.duree, 21600);
      expect(s.dureePauses, 3600);
      expect(s.dureeTravail, 18000);
      expect(s.calculeLe, DateTime.parse('2026-10-13T03:00:00+02:00'));
      expect(s.pauses, hasLength(1));
      final pause = s.pauses.single;
      expect(pause.uuid, 'p1');
      expect(pause.isBreak, isTrue);
      expect(pause.enCours, isFalse);
      expect(pause.duree, 3600);
      expect(pause.serviceParentUuid, 's1');
      expect(s.pauseEnCours, isNull);
    });

    test('should_read_parent_uuid_when_pause', () {
      final pause = Service.fromJson({
        'uuid': 'p2',
        'debut': '2026-10-13T10:00:00+02:00',
        'fin': null,
        'isBreak': true,
        'isAdmin': false,
        'userUuid': 'u-1',
        'duree': 600,
        'calculeLe': '2026-10-13T10:10:00+02:00',
        'enCours': true,
        'serviceParentUuid': 's1',
      });

      expect(pause.isBreak, isTrue);
      expect(pause.enCours, isTrue);
      expect(pause.serviceParentUuid, 's1');
      expect(pause.pauses, isEmpty);
      expect(pause.dureeTravail, 0);
    });

    test('should_share_anchor_with_pauses_when_parsed', () {
      final s = Service.fromJson(_nightService);

      expect(identical(s.anchor, s.pauses.single.anchor), isTrue);
    });
  });

  group('valeurs en direct', () {
    test('should_advance_net_time_when_on_duty_outside_break', () {
      final s = Service.fromJson(_nightService);

      monotonic += const Duration(seconds: 1);

      expect(s.liveTravail.value, const Duration(hours: 5, seconds: 1));
      expect(s.liveDuree.value, const Duration(hours: 6, seconds: 1));
      expect(s.livePauses.value, const Duration(hours: 1));
    });

    test('should_freeze_net_time_and_advance_break_when_on_break', () {
      final s = Service.fromJson({
        ..._nightService,
        'duree': 23400,
        'dureePauses': 5400,
        'dureeTravail': 18000,
        'enPause': true,
        'pauses': [
          ...(_nightService['pauses'] as List),
          {
            'uuid': 'p2',
            'debut': '2026-10-13T03:00:00+02:00',
            'fin': null,
            'isBreak': true,
            'userUuid': 'u-1',
            'duree': 1800,
            'enCours': true,
            'serviceParentUuid': 's1',
          },
        ],
      });

      monotonic += const Duration(minutes: 1);

      expect(s.liveTravail.value, const Duration(hours: 5));
      expect(s.livePauses.value, const Duration(hours: 1, minutes: 31));
      expect(s.pauseEnCours?.uuid, 'p2');
      expect(s.pauseEnCours!.liveDuree.value, const Duration(minutes: 31));
      expect(s.liveDuree.value, const Duration(hours: 6, minutes: 31));
    });
  });

  group('JourneeTravail.fromJson', () {
    test('should_read_night_day_when_service_from_previous_day', () {
      final ended = {
        ..._nightService,
        'fin': '2026-10-13T06:00:00+02:00',
        'duree': 32400,
        'calculeLe': '2026-10-13T06:30:00+02:00',
        'enCours': false,
        'dureeTravail': 28800,
      };
      final j = JourneeTravail.fromJson({
        'success': true,
        'date': '2026-10-12',
        'aujourdhui': false,
        'heures': {'secondes': 28800, 'heures': 8.0, 'enCours': false},
        'services': [ended],
        'calculeLe': '2026-10-13T06:30:00+02:00',
      });

      expect(j.date, DateTime(2026, 10, 12));
      expect(j.aujourdhui, isFalse);
      expect(j.heures.secondes, 28800);
      expect(j.heures.enCours, isFalse);
      expect(j.calculeLe, DateTime.parse('2026-10-13T06:30:00+02:00'));
      expect(j.services, hasLength(1));
      final s = j.services.single;
      expect(s.uuid, 's1');
      expect(s.enCours, isFalse);
      expect(s.dureeTravail, 28800);
      expect(s.pauses.single.serviceParentUuid, 's1');
      expect(identical(s.anchor, j.heures.anchor), isTrue);

      monotonic += const Duration(minutes: 5);
      expect(j.heures.live.value, const Duration(hours: 8));
    });

    test('should_be_today_and_empty_when_no_service', () {
      final j = JourneeTravail.fromJson({
        'success': true,
        'date': '2026-10-13',
        'aujourdhui': true,
        'heures': {'secondes': 0, 'heures': 0.0, 'enCours': false},
        'services': <Object>[],
      });

      expect(j.aujourdhui, isTrue);
      expect(j.date, DateTime(2026, 10, 13));
      expect(j.services, isEmpty);
    });
  });

  group('WorkedHours.fromJson', () {
    test('should_read_working_day_when_jour_present', () {
      final h = WorkedHours.fromJson({
        'jour': '2026-10-12',
        'day': {'secondes': 28800, 'heures': 8.0, 'enCours': false},
      });

      expect(h.jour, DateTime(2026, 10, 12));
      expect(h.day?.secondes, 28800);
    });

    test('should_read_periods_when_full_overview', () {
      final h = WorkedHours.fromJson({
        'calculeLe': '2026-10-13T03:00:00+02:00',
        'year': {'secondes': 3600000, 'heures': 1000.0, 'enCours': true},
        'month': {'secondes': 180000, 'heures': 50.0, 'enCours': true},
        'week': {'secondes': 18000, 'heures': 5.0, 'enCours': true},
        'day': {'secondes': 0, 'heures': 0.0, 'enCours': false},
        'lastMonth': {'secondes': 540000, 'heures': 150.0, 'enCours': false},
      });

      expect(h.calculeLe, DateTime.parse('2026-10-13T03:00:00+02:00'));
      expect(h.week, const HeuresPeriode(secondes: 18000, heures: 5, enCours: true));
      expect(h.day?.secondes, 0);
      expect(h.day?.enCours, isFalse);
      expect(h.lastMonth?.heures, 150);
      expect(h.anyRunning, isTrue);

      monotonic += const Duration(seconds: 2);
      expect(h.week!.live.value, const Duration(hours: 5, seconds: 2));
      expect(h.day!.live.value, Duration.zero);
    });

    test('should_keep_only_requested_period_when_filtered', () {
      final h = WorkedHours.fromJson({
        'calculeLe': '2026-10-13T03:00:00+02:00',
        'month': {'secondes': 180000, 'heures': 50.0, 'enCours': false},
      });

      expect(h.month?.heures, 50);
      expect(h.day, isNull);
      expect(h.week, isNull);
      expect(h.anyRunning, isFalse);
    });
  });
}

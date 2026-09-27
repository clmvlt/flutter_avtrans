import 'package:av_pointage/data/models/entretien_model.dart';
import 'package:av_pointage/data/models/vehicule_model.dart';
import 'package:av_pointage/presentation/screens/entretiens/logic/fleet_status.dart';
import 'package:av_pointage/presentation/screens/entretiens/widgets/history_filters_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Vehicule _vehicule(String id, String immat) => Vehicule(
      id: id,
      immat: immat,
      createdAt: DateTime(2024),
    );

VehiculeProchainEntretien _prochain(
  Vehicule v, {
  AlerteEntretien? km,
  AlerteEntretien? date,
}) =>
    VehiculeProchainEntretien(vehicule: v, prochainKm: km, prochaineDate: date);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('computeFleetStatus', () {
    final a = _vehicule('a', 'AA-111-AA');
    final b = _vehicule('b', 'BB-222-BB');
    final c = _vehicule('c', 'CC-333-CC');
    final d = _vehicule('d', 'DD-444-DD');

    test('should_rank_late_then_soon_then_ok_when_fleet_is_mixed', () {
      final fleet = computeFleetStatus(
        [d, c, b, a],
        [
          _prochain(a, km: const AlerteEntretien(kmRestants: -500, enRetard: true)),
          _prochain(b, date: const AlerteEntretien(joursRestants: 30)),
          _prochain(c, km: const AlerteEntretien(kmRestants: 25000)),
        ],
      );

      expect(fleet.map((f) => f.vehicule.id), ['a', 'b', 'c', 'd']);
      expect(fleet.map((f) => f.level), [
        FleetLevel.late,
        FleetLevel.soon,
        FleetLevel.ok,
        FleetLevel.ok,
      ]);
      expect(fleet.last.isTracked, isFalse);
    });

    test('should_apply_10000_km_and_90_days_thresholds', () {
      expect(FleetAlert.km(const AlerteEntretien(kmRestants: 10000)).level,
          FleetLevel.soon);
      expect(FleetAlert.km(const AlerteEntretien(kmRestants: 10001)).level,
          FleetLevel.ok);
      expect(FleetAlert.date(const AlerteEntretien(joursRestants: 90)).level,
          FleetLevel.soon);
      expect(FleetAlert.date(const AlerteEntretien(joursRestants: 91)).level,
          FleetLevel.ok);
    });

    test('should_include_every_vehicle_when_api_returns_none', () {
      final fleet = computeFleetStatus([a, b], const []);
      expect(fleet, hasLength(2));
      expect(fleet.every((f) => f.level == FleetLevel.ok), isTrue);
    });
  });

  group('FleetAlert.dueLabel', () {
    test('should_say_late_only_when_overdue', () {
      expect(
        FleetAlert.km(const AlerteEntretien(kmRestants: -2300, enRetard: true))
            .dueLabel,
        startsWith('En retard de 2'),
      );
      expect(
        FleetAlert.date(const AlerteEntretien(joursRestants: 30)).dueLabel,
        'Dans 30 jours',
      );
      expect(
        FleetAlert.date(const AlerteEntretien(joursRestants: 1)).dueLabel,
        'Dans 1 jour',
      );
      expect(
        FleetAlert.date(const AlerteEntretien(joursRestants: 0)).dueLabel,
        'Aujourd\'hui',
      );
    });
  });

  group('formatPeriodicite', () {
    test('should_use_exact_units_when_divisible', () {
      expect(formatPeriodicite(PeriodiciteType.temporel, 365), 'Tous les ans');
      expect(formatPeriodicite(PeriodiciteType.temporel, 730), 'Tous les 2 ans');
      expect(formatPeriodicite(PeriodiciteType.temporel, 180), 'Tous les 6 mois');
      expect(formatPeriodicite(PeriodiciteType.temporel, 30), 'Tous les mois');
      expect(formatPeriodicite(PeriodiciteType.temporel, 45), 'Tous les 45 jours');
      expect(formatPeriodicite(PeriodiciteType.temporel, 1), 'Tous les jours');
    });

    test('should_format_kilometres_with_grouping', () {
      expect(
        formatPeriodicite(PeriodiciteType.kilometrage, 30000)
            .replaceAll(RegExp(r'\s'), ' '),
        'Tous les 30 000 km',
      );
    });
  });

  group('saisie', () {
    test('should_parse_french_numbers', () {
      expect(parseIntInput('150 000'), 150000);
      expect(parseIntInput(''), isNull);
      expect(parseAmountInput('120,50'), 120.5);
      expect(parseAmountInput('1 234,5 €'), 1234.5);
      expect(parseAmountInput('abc'), isNull);
    });
  });

  group('requêtes', () {
    test('should_send_local_day_at_noon_without_offset', () {
      final json = EntretienCreateRequest(
        vehiculeId: 'v',
        typeEntretienId: 't',
        dateEntretien: DateTime(2026, 3, 29, 0, 30),
        kilometrage: 1000,
      ).toJson();
      expect(json['dateEntretien'], '2026-03-29T12:00:00');
      expect(json.containsKey('cout'), isFalse);
      expect(json.containsKey('files'), isFalse);
    });

    test('should_keep_empty_comment_on_update_to_clear_it', () {
      final json = const EntretienUpdateRequest(commentaire: '').toJson();
      expect(json['commentaire'], '');
      expect(json.containsKey('cout'), isFalse);
    });

    test('should_count_active_filters_without_vehicle', () {
      final q = EntretienHistoryQuery(
        vehiculeId: 'v',
        dossierId: 'd',
        startDate: DateTime(2026),
        kmMax: 100,
      );
      expect(q.activeFilterCount, 3);
      final json = q.withPage(2).toJson();
      expect(json['page'], 2);
      expect(json['startDate'], '2026-01-01');
      expect(json['sortBy'], 'dateEntretien');
      expect(json['sortDirection'], 'desc');
    });
  });

  group('parsing', () {
    test('should_read_history_entry_with_files_and_mecanicien', () {
      final e = Entretien.fromJson({
        'id': 'e1',
        'vehiculeId': 'v1',
        'vehiculeImmat': 'AB-123-CD',
        'typeEntretien': {
          'id': 't1',
          'nom': 'Vidange',
          'dossier': {'id': 'd1', 'nom': 'Moteur'},
        },
        'mecanicien': {'uuid': 'u1', 'firstName': 'Julien', 'lastName': 'Martin'},
        'dateEntretien': '2026-09-18T12:00:00+02:00',
        'kilometrage': 97800,
        'cout': 186.4,
        'files': [
          {'id': 'f1', 'originalName': 'facture.pdf', 'mimeType': 'application/pdf', 'fileSize': 1200},
        ],
      });
      expect(e.typeEntretien?.fullLabel, 'Moteur › Vidange');
      expect(e.mecanicien?.fullName, 'Julien Martin');
      expect(e.files.single.isPdf, isTrue);
      expect(e.dateEntretien.day, 18);
    });

    test('should_ignore_missing_alerts', () {
      final p = VehiculeProchainEntretien.fromJson(const {'vehicule': null});
      expect(p.vehicule, isNull);
      expect(alertsOf(p), isEmpty);
    });
  });
}

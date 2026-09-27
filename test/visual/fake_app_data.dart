// Données simulées des écrans chauffeur (pointage, demandes, notifications…).

import 'fake_data.dart';
import 'visual_harness.dart';

String iso(DateTime d) => '${d.toIso8601String().split('.').first}+02:00';

final absenceTypes = [
  {'uuid': 'at1', 'name': 'Congés payés', 'color': '#3b82f6'},
  {'uuid': 'at2', 'name': 'Maladie', 'color': '#ef4444'},
  {'uuid': 'at3', 'name': 'RTT', 'color': '#10b981'},
];

Map<String, dynamic> absence(
  String uuid,
  int type,
  DateTime start,
  DateTime end,
  String status, {
  String reason = '',
  String? period,
}) =>
    {
      'uuid': uuid,
      'startDate': iso(start),
      'endDate': iso(end),
      'reason': reason,
      'absenceType': absenceTypes[type],
      'status': status,
      'period': period,
      'createdAt': iso(start.subtract(const Duration(days: 20))),
    };

final absences = [
  absence('a1', 0, DateTime(2026, 10, 19), DateTime(2026, 10, 23), 'PENDING',
      reason: 'Vacances de la Toussaint'),
  absence('a2', 2, DateTime(2026, 10, 2), DateTime(2026, 10, 2), 'APPROVED',
      period: 'MORNING'),
  absence('a3', 1, DateTime(2026, 9, 8), DateTime(2026, 9, 9), 'APPROVED'),
  absence('a4', 0, DateTime(2026, 8, 3), DateTime(2026, 8, 14), 'REJECTED'),
];

Map<String, dynamic> acompte(String uuid, double montant, String status, DateTime at) => {
      'uuid': uuid,
      'userUuid': 'u-1',
      'montant': montant,
      'raison': 'Avance sur salaire',
      'status': status,
      'createdAt': iso(at),
    };

final acomptes = [
  acompte('ac1', 300, 'PENDING', DateTime(2026, 9, 24)),
  acompte('ac2', 150, 'APPROVED', DateTime(2026, 8, 12)),
  acompte('ac3', 500, 'REJECTED', DateTime(2026, 6, 3)),
];

final notifications = [
  {
    'uuid': 'n1',
    'title': 'Absence validée',
    'description': 'Ta demande de RTT du 2 octobre a été validée.',
    'createdAt': iso(DateTime(2026, 9, 27, 9, 12)),
    'isRead': false,
    'refType': 'ABSENCE',
  },
  {
    'uuid': 'n2',
    'title': 'Nouveau rapport véhicule',
    'description': 'AB-123-CD : voyant moteur allumé.',
    'createdAt': iso(DateTime(2026, 9, 26, 17, 40)),
    'isRead': false,
    'refType': 'RAPPORT_VEHICULE',
  },
  {
    'uuid': 'n3',
    'title': 'Acompte approuvé',
    'description': '150,00 € seront versés avec la prochaine paie.',
    'createdAt': iso(DateTime(2026, 9, 20, 11, 5)),
    'isRead': true,
    'refType': 'ACOMPTE',
  },
];

final todoCategories = [
  {'uuid': 'tc1', 'name': 'Atelier', 'color': '#f59e0b'},
  {'uuid': 'tc2', 'name': 'Administratif', 'color': '#3b82f6'},
];

final todos = [
  {
    'uuid': 'td1',
    'title': 'Commander des plaquettes pour le Boxer',
    'category': todoCategories[0],
    'isDone': false,
    'createdAt': iso(DateTime(2026, 9, 25)),
  },
  {
    'uuid': 'td2',
    'title': 'Prendre RDV contrôle technique AB-123-CD',
    'category': todoCategories[1],
    'isDone': false,
    'createdAt': iso(DateTime(2026, 9, 22)),
  },
  {
    'uuid': 'td3',
    'title': 'Ranger le stock de pneus',
    'category': todoCategories[0],
    'isDone': true,
    'createdAt': iso(DateTime(2026, 9, 12)),
  },
];

Map<String, dynamic> todoPage(List<Map<String, dynamic>> list) => {
      'success': true,
      'todos': list,
      'currentPage': 0,
      'totalPages': 1,
      'totalElements': list.length,
    };

/// Routes des écrans chauffeur + atelier.
List<FakeRoute> appRoutes({Map<String, dynamic>? user}) => [
      ...atelierRoutes(),
      FakeRoute('GET', '/profile', (_, _) => user ?? fakeUser()),
      FakeRoute('GET', '/auth/me', (_, _) => {'success': true, 'user': user ?? fakeUser()}),
      FakeRoute('GET', '/services/active', (_, _) => {
            'success': true,
            'service': {
              'uuid': 's1',
              'debut': iso(DateTime(2026, 9, 27, 7, 42)),
              'isBreak': false,
              'userUuid': 'u-1',
            },
          }),
      FakeRoute('GET', '/services/hours', (_, _) => {
            'day': 2.3,
            'week': 31.5,
            'month': 142.25,
            'lastMonth': 151.75,
            'year': 1203.5,
          }),
      FakeRoute('GET', '/services/user/daily', (_, _) => [
            {
              'uuid': 's1',
              'debut': iso(DateTime(2026, 9, 27, 7, 42)),
              'isBreak': false,
              'userUuid': 'u-1',
            },
          ]),
      FakeRoute('GET', '/notifications/unread/count', (_, _) => {'success': true, 'count': 2}),
      FakeRoute('GET', '/notifications', (_, _) => {'success': true, 'notifications': notifications}),
      FakeRoute('GET', '/notifications/unread', (_, _) => {
            'success': true,
            'notifications': notifications.where((n) => n['isRead'] == false).toList(),
          }),
      FakeRoute('GET', '/signatures/last/summary', (_, _) => {
            'needsToSign': true,
            'heuresLastMonth': 151.75,
          }),
      FakeRoute('GET', '/signatures', (_, _) => {
            'success': true,
            'signatures': [
              {
                'uuid': 'sg1',
                'date': iso(DateTime(2026, 9, 2)),
                'heuresSignees': 148.5,
                'createdAt': iso(DateTime(2026, 9, 2)),
              },
              {
                'uuid': 'sg2',
                'date': iso(DateTime(2026, 8, 1)),
                'heuresSignees': 160.25,
                'createdAt': iso(DateTime(2026, 8, 1)),
              },
            ],
          }),
      FakeRoute('GET', '/absence-types', (_, _) => {'success': true, 'types': absenceTypes}),
      FakeRoute('POST', '/absences/my', (_, _) => {
            'success': true,
            'absences': absences,
            'currentPage': 0,
            'totalPages': 1,
            'totalElements': absences.length,
          }),
      FakeRoute('POST', '/acomptes/my', (_, _) => {
            'success': true,
            'acomptes': acomptes,
            'currentPage': 0,
            'totalPages': 1,
            'totalElements': acomptes.length,
          }),
      FakeRoute('GET', '/couchettes/me', (_, _) => {
            'success': true,
            'content': [
              {'uuid': 'co1', 'date': '2026-09-24', 'createdAt': iso(DateTime(2026, 9, 24, 20))},
              {'uuid': 'co2', 'date': '2026-09-17', 'createdAt': iso(DateTime(2026, 9, 17, 21))},
            ],
            'page': 0,
            'size': 20,
            'totalElements': 2,
            'totalPages': 1,
            'first': true,
            'last': true,
          }),
      FakeRoute('POST', '/todos/search', (_, body) {
        final done = body['isDone'];
        final list = done == null ? todos : todos.where((t) => t['isDone'] == done).toList();
        return todoPage(list);
      }),
      FakeRoute('GET', '/todo-categories', (_, _) => {'success': true, 'categories': todoCategories}),
      FakeRoute('GET', '/users/me/kilometrage', (_, _) => {
            'success': true,
            'hasEnteredToday': true,
            'lastKilometrage': null,
          }),
      FakeRoute('GET', '/users/me/notification-preferences', (_, _) => {
            'acompte': 'SITE',
            'absence': 'EMAIL',
            'userCreated': 'NONE',
            'rapportVehicule': 'SITE',
            'todo': 'SITE',
          }),
      FakeRoute('GET', '/rapports/me/latest', (_, _) => {'success': true, 'data': null}),
      FakeRoute('GET', '/services/month', (_, _) => []),
      FakeRoute('POST', '/services/history', (_, _) => {
            'success': true,
            'content': [],
            'page': 0,
            'size': 20,
            'totalElements': 0,
            'totalPages': 0,
            'first': true,
            'last': true,
          }),
    ];

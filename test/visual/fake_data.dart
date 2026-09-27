// Jeux de données simulés pour les captures (formes de l'API api_avtrans).

import 'visual_harness.dart';

const mecanicienRole = {
  'uuid': 'ccbd448a-0eef-4277-b53b-91be340b080f',
  'nom': 'Mécanicien',
  'color': '#075985',
};

const utilisateurRole = {
  'uuid': '99127dd5-f7bd-446c-9fd0-c05d4ea135b2',
  'nom': 'Utilisateur',
  'color': '#3b0764',
};

Map<String, dynamic> fakeUser({Map<String, dynamic> role = mecanicienRole}) => {
      'uuid': 'u-1',
      'email': 'julien.martin@avtrans.fr',
      'firstName': 'Julien',
      'lastName': 'Martin',
      'isMailVerified': true,
      'isActive': true,
      'createdAt': '2024-01-10T09:00:00+01:00',
      'updatedAt': '2026-09-01T09:00:00+02:00',
      'role': role,
      'isCouchette': false,
    };

String _iso(DateTime d) => '${d.toIso8601String().split('.').first}+02:00';

final DateTime today = DateTime(2026, 9, 27, 10);

Map<String, dynamic> vehicule(
  String id,
  String immat,
  String brand,
  String model,
  int? km,
) =>
    {
      'id': id,
      'immat': immat,
      'brand': brand,
      'model': model,
      'createdAt': '2023-03-01T10:00:00+01:00',
      'latestKm': km,
      'latestKmDate': km == null ? null : _iso(today.subtract(const Duration(days: 3))),
    };

final vehicules = [
  {
    ...vehicule('v1', 'AB-123-CD', 'Renault', 'Master', 152300),
    'pictureUrl': 'https://api.test/uploads/vehicules/profile/v1.jpg',
  },
  vehicule('v2', 'EF-456-GH', 'Peugeot', 'Boxer', 98450),
  vehicule('v3', 'GH-789-JK', 'Citroën', 'Jumper', 210000),
  vehicule('v4', 'KL-012-MN', 'Renault', 'Kangoo', 45600),
  vehicule('v5', 'PQ-345-RS', 'Ford', 'Transit', 130200),
];

const dossiers = [
  {'id': 'd1', 'nom': 'Moteur', 'description': 'Vidanges, courroies, filtres'},
  {'id': 'd2', 'nom': 'Freinage', 'description': null},
  {'id': 'd3', 'nom': 'Pneumatiques', 'description': null},
  {'id': 'd4', 'nom': 'Réglementaire', 'description': 'Contrôles obligatoires'},
];

Map<String, dynamic> type(String id, String nom, [int? dossier, String? desc]) => {
      'id': id,
      'nom': nom,
      'description': desc,
      'dossier': dossier == null ? null : dossiers[dossier],
    };

final types = [
  type('t1', 'Vidange', 0, 'Huile moteur et filtre à huile'),
  type('t2', 'Courroie de distribution', 0),
  type('t3', 'Plaquettes avant', 1),
  type('t4', 'Disques de frein', 1),
  type('t5', 'Pneus', 2, 'Remplacement des 4 pneus'),
  type('t6', 'Contrôle technique', 3),
  type('t7', 'Révision annuelle'),
  type('t8', 'Lavage intérieur'),
];

Map<String, dynamic> alerte(
  int typeIndex, {
  int? prochainKm,
  int? kmRestants,
  DateTime? date,
  int? jours,
  bool late = false,
}) =>
    {
      'typeEntretien': types[typeIndex],
      'prochainKilometrage': prochainKm,
      'kmRestants': kmRestants,
      'prochaineDateTemporelle': date == null ? null : _iso(date),
      'joursRestants': jours,
      'enRetard': late,
    };

final upcoming = [
  {
    'vehicule': vehicules[0],
    'prochainEntretienKm': alerte(0, prochainKm: 150000, kmRestants: -2300, late: true),
    'prochainEntretienDate': alerte(5, date: DateTime(2026, 11, 2), jours: 36),
  },
  {
    'vehicule': vehicules[1],
    'prochainEntretienKm': alerte(4, prochainKm: 100000, kmRestants: 1550),
  },
  {
    'vehicule': vehicules[2],
    'prochainEntretienKm': alerte(1, prochainKm: 240000, kmRestants: 30000),
    'prochainEntretienDate': alerte(6, date: DateTime(2027, 4, 15), jours: 200),
  },
];

Map<String, dynamic> entretien(
  String id,
  int vehiculeIndex,
  int typeIndex,
  DateTime date,
  int km, {
  double? cout,
  String? commentaire,
  int files = 0,
}) =>
    {
      'id': id,
      'vehiculeId': vehicules[vehiculeIndex]['id'],
      'vehiculeImmat': vehicules[vehiculeIndex]['immat'],
      'typeEntretien': types[typeIndex],
      'mecanicien': {
        'uuid': 'u-1',
        'firstName': 'Julien',
        'lastName': 'Martin',
      },
      'dateEntretien': _iso(date),
      'kilometrage': km,
      'cout': cout,
      'commentaire': commentaire,
      'createdAt': _iso(date),
      'files': [
        for (var i = 0; i < files; i++)
          {
            'id': '$id-f$i',
            'entretienId': id,
            'originalName': i == 0 ? 'facture-garage.pdf' : 'photo-$i.jpg',
            'mimeType': i == 0 ? 'application/pdf' : 'image/jpeg',
            'fileSize': 245000 + i * 1000000,
            'createdAt': _iso(date),
          },
      ],
    };

final history = [
  entretien('e1', 1, 2, DateTime(2026, 9, 18), 97800,
      cout: 186.40, commentaire: 'Plaquettes Bosch, disques OK.', files: 2),
  entretien('e2', 0, 5, DateTime(2026, 9, 3), 150900, cout: 78),
  entretien('e3', 2, 0, DateTime(2026, 8, 21), 205300, cout: 129.9, files: 1),
  entretien('e4', 3, 7, DateTime(2026, 8, 12), 44800),
  entretien('e5', 4, 4, DateTime(2026, 7, 30), 128000, cout: 612),
  entretien('e6', 0, 2, DateTime(2026, 7, 2), 148200, cout: 164.5),
  entretien('e7', 1, 0, DateTime(2026, 6, 14), 95000, cout: 118),
];

final configsV1 = [
  {
    'id': 'c1',
    'vehiculeId': 'v1',
    'typeEntretien': types[0],
    'periodiciteType': 'KILOMETRAGE',
    'periodiciteValeur': 30000,
    'actif': true,
  },
  {
    'id': 'c2',
    'vehiculeId': 'v1',
    'typeEntretien': types[5],
    'periodiciteType': 'TEMPOREL',
    'periodiciteValeur': 730,
    'actif': true,
  },
  {
    'id': 'c3',
    'vehiculeId': 'v1',
    'typeEntretien': types[2],
    'periodiciteType': 'KILOMETRAGE',
    'periodiciteValeur': 40000,
    'actif': false,
  },
];

Map<String, dynamic> page(List<Map<String, dynamic>> content) => {
      'success': true,
      'content': content,
      'page': 0,
      'size': 20,
      'totalElements': content.length,
      'totalPages': 1,
      'first': true,
      'last': true,
    };

/// Routes de l'atelier (véhicules, entretiens, types, suivis).
List<FakeRoute> atelierRoutes() => [
      FakeRoute('GET', '/vehicules', (_, _) => {'success': true, 'vehicules': vehicules}),
      FakeRoute('GET', '/vehicules/([^/]+)', (m, _) => {
            'success': true,
            'vehicule': vehicules.firstWhere((v) => v['id'] == m.group(1)),
          }),
      FakeRoute('GET', '/vehicules/([^/]+)/files', (_, _) => {'success': true, 'files': []}),
      FakeRoute('GET', '/entretiens/vehicules-prochains-entretiens',
          (_, _) => {'success': true, 'data': upcoming}),
      FakeRoute('GET', '/entretiens/vehicule/([^/]+)/prochains-entretiens', (m, _) {
        final data = upcoming
            .where((u) => (u['vehicule'] as Map)['id'] == m.group(1))
            .firstOrNull;
        return {'success': true, 'data': data};
      }),
      FakeRoute('POST', '/entretiens/history', (_, body) {
        var list = history;
        if (body['vehiculeId'] != null) {
          list = list.where((e) => e['vehiculeId'] == body['vehiculeId']).toList();
        }
        if (body['typeEntretienId'] != null) {
          list = list
              .where((e) => (e['typeEntretien'] as Map)['id'] == body['typeEntretienId'])
              .toList();
        }
        return page(list);
      }),
      FakeRoute('GET', '/types-entretien', (_, _) => {'success': true, 'typesEntretien': types}),
      FakeRoute('GET', '/dossiers-types-entretien', (_, _) => {'success': true, 'dossiers': dossiers}),
      FakeRoute('GET', '/vehicules-types-entretien/vehicule/v1',
          (_, _) => {'success': true, 'vehiculeTypesEntretien': configsV1}),
      FakeRoute('GET', '/vehicules-types-entretien/vehicule/([^/]+)',
          (_, _) => {'success': true, 'vehiculeTypesEntretien': []}),
    ];

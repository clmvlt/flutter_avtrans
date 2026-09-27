import 'dart:convert';

import 'package:av_pointage/data/repositories/vehicule_repository.dart';
import 'package:av_pointage/data/services/http_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Fiche complète telle que la renvoie `GET /vehicules/{id}`.
const _fiche = {
  'id': 'v1',
  'immat': 'AB-123-CD',
  'relaiImmat': 'ZZ-999-ZZ',
  'createdAt': '2023-03-01T10:00:00+01:00',
  'model': 'Master',
  'brand': 'Renault',
  'comment': 'Hayon à surveiller',
  'latestKm': 152300,
  'pictureUrl': 'https://api.test/uploads/vehicules/profile/old.jpg',
  'vin': 'VF1MA000012345678',
  'numeroCarteGrise': 'CG-42',
  'dateMiseEnCirculation': '2019-05-14',
  'typeCarburant': 'Diesel',
  'ptac': 3500,
  'numeroContratAssurance': 'AX-778',
  'assureur': 'Axa',
  'dateExpirationAssurance': '2027-01-31',
  'dateProchainControleTechnique': '2026-11-02',
};

void main() {
  group('updateVehiculePhoto', () {
    test('should_resend_every_field_with_the_photo_when_updating', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({'success': true, 'vehicule': _fiche}),
            200,
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'vehicule': {
              ..._fiche,
              'pictureUrl': 'https://api.test/uploads/vehicules/profile/new.jpg',
              'comment': body['comment'],
            },
          }),
          200,
        );
      });
      final repo = VehiculeRepository(
        httpService: HttpService(client: client, baseUrl: 'https://api.test'),
      );

      final result = await repo.updateVehiculePhoto(
        'v1',
        'data:image/jpeg;base64,AAAA',
      );

      expect(result.isRight(), isTrue);
      result.fold((_) {}, (v) {
        expect(v.pictureUrl, endsWith('new.jpg'));
      });

      // Relecture de la fiche, puis envoi complet.
      expect(requests.map((r) => r.method), ['GET', 'PUT']);
      expect(requests.last.url.path, '/vehicules/v1');
      final sent = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(sent, {
        'immat': 'AB-123-CD',
        'relaiImmat': 'ZZ-999-ZZ',
        'model': 'Master',
        'brand': 'Renault',
        'comment': 'Hayon à surveiller',
        'pictureBase64': 'data:image/jpeg;base64,AAAA',
        'vin': 'VF1MA000012345678',
        'numeroCarteGrise': 'CG-42',
        'dateMiseEnCirculation': '2019-05-14',
        'typeCarburant': 'Diesel',
        'ptac': 3500,
        'numeroContratAssurance': 'AX-778',
        'assureur': 'Axa',
        'dateExpirationAssurance': '2027-01-31',
        'dateProchainControleTechnique': '2026-11-02',
      });
    });

    test('should_not_send_update_when_reading_the_vehicle_fails', () async {
      final methods = <String>[];
      final client = MockClient((request) async {
        methods.add(request.method);
        return http.Response(
          jsonEncode({'success': false, 'message': 'Véhicule non trouvé'}),
          400,
        );
      });
      final repo = VehiculeRepository(
        httpService: HttpService(client: client, baseUrl: 'https://api.test'),
      );

      final result = await repo.updateVehiculePhoto('v1', 'data:,');

      expect(result.isLeft(), isTrue);
      expect(methods, ['GET']);
    });
  });
}

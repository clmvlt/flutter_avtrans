import 'dart:async';
import 'dart:convert';

import 'package:av_pointage/core/di/service_locator.dart';
import 'package:av_pointage/data/models/ypsium_models.dart';
import 'package:av_pointage/presentation/screens/ypsium/ypsium_home_screen.dart';
import 'package:av_pointage/presentation/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../visual/visual_harness.dart';

/// Serveur Ypsium simulé : un ordre dont l'état avance quand une
/// validation arrive. [hold] retient les envois (réseau lent).
class _FakeYpsium {
  int etat = 1;
  int listCalls = 0;
  final List<String> posts = [];
  Completer<void>? hold;

  http.Response _json(Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  http.Client get client => MockClient((request) async {
        final path = request.url.path;
        if (path.startsWith('/getParamSaisieKilometrage/')) {
          return _json({'TokenValide': true});
        }
        if (path.startsWith('/getListeTransport/')) {
          listCalls++;
          return _json({
            'data': [
              {
                'idOrdre': 12,
                'idEtat': etat,
                'client': 'Pharmacie du Port',
                'E_Nom': 'Grossiste Ouest',
                'L_Nom': 'Pharmacie du Port',
              },
            ],
          });
        }
        if (request.method == 'POST') {
          await hold?.future;
          posts.add(path);
          if (path.startsWith('/setPointEnleve/')) etat = 4;
          if (path.startsWith('/setPointLivre/')) etat = 5;
          return _json({'success': true});
        }
        // Référentiels : leur échec est ignoré par l'accueil.
        return http.Response('{}', 500);
      });
}

Future<_FakeYpsium> _setUp() async {
  await initializeDateFormatting('fr_FR', null);
  SharedPreferences.setMockInitialValues({
    'ypsium_token': 'tok',
    'ypsium_session_id_chauffeur': '7',
    'ypsium_session_login': 'jdupont',
  });
  final server = _FakeYpsium();
  await sl.initForTesting(
    client: MockClient((_) async => http.Response('{}', 404)),
    ypsiumClient: server.client,
  );
  await sl.ypsiumAuthRepository.tryRestoreSession();
  return server;
}

const _request = YpsiumSetPointEnleveRequest(
  nomRemettant: 'M. Martin',
  heureArriveeSurSite: '2026-09-28T08:00:00',
  heureDepartSite: '2026-09-28T08:10:00',
);

Finder _section(String title) => find.widgetWithText(AppSectionHeader, title);

void main() {
  testWidgets(
      'should_move_order_at_once_and_reload_when_validation_reaches_server',
      (tester) async {
    final server = await _setUp();
    await pumpScreen(tester, const YpsiumHomeScreen());

    expect(_section('À enlever'), findsOneWidget);
    expect(_section('À livrer'), findsNothing);
    final callsBefore = server.listCalls;

    // Réseau lent : la validation reste dans la file d'envoi.
    server.hold = Completer<void>();
    await sl.ypsiumTransportRepository.setPointEnleve(
      idOrdre: 12,
      request: _request,
    );
    await settle(tester);

    expect(server.posts, isEmpty);
    expect(_section('À livrer'), findsOneWidget);
    expect(_section('À enlever'), findsNothing);

    // La validation arrive au serveur : la liste est relue sans geste.
    server.hold!.complete();
    await settle(tester);

    expect(server.posts.single, startsWith('/setPointEnleve/12/'));
    expect(server.listCalls, callsBefore + 1);
    expect(_section('À livrer'), findsOneWidget);
    expect(_section('À enlever'), findsNothing);
  });

  testWidgets('should_restore_server_state_when_validation_removed_from_queue',
      (tester) async {
    final server = await _setUp();
    await pumpScreen(tester, const YpsiumHomeScreen());

    server.hold = Completer<void>();
    await sl.ypsiumTransportRepository.setPointEnleve(
      idOrdre: 12,
      request: _request,
    );
    await settle(tester);
    expect(_section('À livrer'), findsOneWidget);

    // Supprimée de la file avant l'envoi : le serveur n'a rien reçu.
    final entry = sl.ypsiumSpoolerService.entries.single;
    await sl.ypsiumSpoolerService.removeEntry(entry.id);
    await settle(tester);

    expect(_section('À enlever'), findsOneWidget);
    expect(_section('À livrer'), findsNothing);

    server.hold!.complete();
    await settle(tester);
  });

  test('should_keep_delivered_order_when_pending_etat_is_lower', () {
    const livre = YpsiumTransportOrder(
      eNom: 'A',
      lNom: 'B',
      idOrdre: 1,
      idEtat: 5,
    );
    expect(identical(livre.withEtatAtLeast(4), livre), isTrue);

    const affecte = YpsiumTransportOrder(eNom: 'A', lNom: 'B', idOrdre: 2);
    final enleve = affecte.withEtatAtLeast(YpsiumTransportOrder.etatEnleve);
    expect(enleve.isEnleve, isTrue);
    expect(enleve.idEtatSousOrdreEnlevement, YpsiumTransportOrder.sousEtatTermine);
    expect(enleve.idEtatSousOrdreLivraison, 0);
  });
}

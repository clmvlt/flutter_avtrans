import 'dart:convert';

import 'package:av_pointage/core/di/service_locator.dart';
import 'package:av_pointage/presentation/screens/auth/forgot_password_screen.dart';
import 'package:av_pointage/presentation/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../visual/visual_harness.dart';

/// API simulée : `POST /auth/password-reset/request` répond [status] ; les
/// adresses reçues sont notées dans [emails].
Future<List<String>> _setUp({int status = 200}) async {
  SharedPreferences.setMockInitialValues({});
  final emails = <String>[];
  await sl.initForTesting(
    client: MockClient((request) async {
      if (request.url.path == '/auth/password-reset/request') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        emails.add(body['email'] as String);
        return http.Response.bytes(
          utf8.encode(jsonEncode(status == 200
              ? {'success': true, 'message': 'Email de réinitialisation envoyé'}
              : {
                  'success': false,
                  'message': 'Utilisateur introuvable avec cet email : '
                      '${body['email']}',
                })),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 404);
    }),
  );
  return emails;
}

/// Premier champ : l'email, sur la connexion comme sur le mot de passe oublié.
Finder _emailField() => find.byType(TextFormField).first;

void main() {
  testWidgets('should_send_link_and_announce_it_on_login_when_email_is_known',
      (tester) async {
    final emails = await _setUp();
    await pumpScreen(tester, const LoginScreen());

    await tester.enterText(_emailField(), 'jean@avtrans.fr');
    await tester.tap(find.text('Mot de passe oublié ?'));
    await settle(tester);

    // L'email saisi sur la connexion est repris.
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('jean@avtrans.fr'), findsOneWidget);

    await tester.tap(find.text('Envoyer le lien'));
    await settle(tester);

    expect(emails, ['jean@avtrans.fr']);
    expect(find.byType(ForgotPasswordScreen), findsNothing);
    expect(find.textContaining('Email envoyé à jean@avtrans.fr'), findsOneWidget);
  });

  testWidgets('should_show_server_message_when_email_is_unknown',
      (tester) async {
    await _setUp(status: 400);
    await pumpScreen(tester, const ForgotPasswordScreen());

    await tester.enterText(_emailField(), 'inconnu@avtrans.fr');
    await tester.tap(find.text('Envoyer le lien'));
    await settle(tester);

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(
      find.textContaining('Utilisateur introuvable avec cet email'),
      findsOneWidget,
    );
  });

  testWidgets('should_not_call_api_when_email_is_invalid', (tester) async {
    final emails = await _setUp();
    await pumpScreen(tester, const ForgotPasswordScreen());

    await tester.enterText(_emailField(), 'pas-un-email');
    await tester.tap(find.text('Envoyer le lien'));
    await settle(tester);

    expect(emails, isEmpty);
    expect(find.text('Entre un email valide'), findsOneWidget);
  });
}

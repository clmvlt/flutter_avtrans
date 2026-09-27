// Captures des écrans de l'atelier. Opt-in : VISUAL=1 flutter test test/visual
import 'dart:io';

import 'package:av_pointage/presentation/screens/entretiens/entretien_form_screen.dart';
import 'package:av_pointage/presentation/screens/entretiens/entretiens_screen.dart';
import 'package:av_pointage/presentation/screens/entretiens/types_entretien_screen.dart';
import 'package:av_pointage/presentation/screens/entretiens/vehicule_entretiens_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_data.dart';
import 'visual_harness.dart';

final _skip = Platform.environment['VISUAL'] == null;

void main() {
  setUpAll(loadAppFonts);

  for (final dark in [false, true]) {
    final suffix = dark ? '_dark' : '';

    testWidgets('entretiens$suffix', (tester) async {
      await setUpApp(user: fakeUser(), routes: atelierRoutes());
      await pumpScreen(tester, const EntretiensScreen(), dark: dark);
      await capture(tester, 'entretiens_echeances$suffix');

      await tester.tap(find.text('Afficher les 3'));
      await settle(tester);
      await capture(tester, 'entretiens_echeances_ok$suffix');

      await tester.tap(find.text('Historique').first);
      await settle(tester);
      await capture(tester, 'entretiens_historique$suffix');

      await tester.tap(find.text('Plaquettes avant').first);
      await settle(tester);
      await capture(tester, 'entretien_detail$suffix');
    }, skip: _skip);

    testWidgets('vehicule$suffix', (tester) async {
      await setUpApp(user: fakeUser(), routes: atelierRoutes());
      await pumpScreen(
        tester,
        const VehiculeEntretiensScreen(vehiculeId: 'v1'),
        dark: dark,
      );
      await capture(tester, 'vehicule_entretiens$suffix');

      await tester.tap(find.text('Fait').first);
      await settle(tester);
      await capture(tester, 'vehicule_fait$suffix');
      await tester.tapAt(const Offset(20, 40));
      await settle(tester);

      await tester.tap(find.text('Suivi').first);
      await settle(tester);
      await capture(tester, 'vehicule_suivi$suffix');

      await tester.tap(find.textContaining('30').last);
      await settle(tester);
      await capture(tester, 'vehicule_suivi_edit$suffix');
    }, skip: _skip);
  }

  testWidgets('formulaire', (tester) async {
    await setUpApp(user: fakeUser(), routes: atelierRoutes());
    await pumpScreen(tester, const EntretienFormScreen());
    await capture(tester, 'form_nouvel_entretien');

    await tester.tap(find.text('Choisir le type'));
    await settle(tester);
    await capture(tester, 'form_type_picker');
  }, skip: _skip);

  testWidgets('types', (tester) async {
    await setUpApp(user: fakeUser(), routes: atelierRoutes());
    await pumpScreen(tester, const TypesEntretienScreen());
    await capture(tester, 'types_entretien');

    await tester.tap(find.text('Freinage').first);
    await settle(tester);
    await capture(tester, 'types_entretien_dossier');
  }, skip: _skip);
}

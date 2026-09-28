// Captures des écrans redessinés. Opt-in : VISUAL=1 flutter test test/visual
import 'dart:io';

import 'package:av_pointage/presentation/screens/absences/absences_screen.dart';
import 'package:av_pointage/presentation/screens/acomptes/acomptes_screen.dart';
import 'package:av_pointage/presentation/screens/auth/forgot_password_screen.dart';
import 'package:av_pointage/presentation/screens/auth/login_screen.dart';
import 'package:av_pointage/presentation/screens/couchettes/couchettes_screen.dart';
import 'package:av_pointage/presentation/screens/notifications/notifications_screen.dart';
import 'package:av_pointage/presentation/screens/profile/edit_profile_screen.dart';
import 'package:av_pointage/presentation/screens/services/kilometrage_required_screen.dart';
import 'package:av_pointage/presentation/screens/shell/home_dashboard_screen.dart';
import 'package:av_pointage/presentation/screens/shell/moi_tab.dart';
import 'package:av_pointage/presentation/screens/todos/todos_screen.dart';
import 'package:av_pointage/presentation/screens/vehicules/vehicule_details_screen.dart';
import 'package:av_pointage/presentation/screens/vehicules/vehicules_list_screen.dart';
import 'package:av_pointage/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'fake_app_data.dart';
import 'fake_data.dart';
import 'visual_harness.dart';

final _skip = Platform.environment['VISUAL'] == null;

/// Écrans capturés en entier (hauteur 1400) pour voir le bas de page.
const _tall = {'accueil'};

/// Écrans à capturer : nom → écran.
final Map<String, Widget Function()> _screens = {
  'login': () => const LoginScreen(),
  'mot_de_passe_oublie': () =>
      const ForgotPasswordScreen(initialEmail: 'jean@avtrans.fr'),
  'accueil': () => HomeDashboardScreen(onOpenPointage: () {}, onOpenMoi: () {}),
  'moi': () => ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MoiTab(),
      ),
  'vehicules': () => const VehiculesListScreen(),
  'vehicule_detail': () => const VehiculeDetailsScreen(vehiculeId: 'v1'),
  'vehicule_sans_photo': () => const VehiculeDetailsScreen(vehiculeId: 'v2'),
  'absences': () => const AbsencesScreen(),
  'acomptes': () => const AcomptesScreen(),
  'couchettes': () => const CouchettesScreen(),
  'taches': () => const TodosScreen(),
  'notifications': () => const NotificationsScreen(),
  'profil': () => const EditProfileScreen(),
};

void main() {
  setUpAll(() async {
    await loadAppFonts();
    PackageInfo.setMockInitialValues(
      appName: 'AVTRANS',
      packageName: 'fr.avtrans.pointage',
      version: '0.0.15',
      buildNumber: '15',
      buildSignature: '',
    );
  });

  for (final entry in _screens.entries) {
    for (final dark in [false, true]) {
      final name = '${entry.key}${dark ? '_dark' : ''}';
      testWidgets(name, (tester) async {
        final api = await setUpApp(user: fakeUser(), routes: appRoutes());
        await pumpScreen(
          tester,
          entry.value(),
          dark: dark,
          size: _tall.contains(entry.key)
              ? const Size(390, 1400)
              : const Size(390, 844),
        );
        await capture(tester, 'app_$name');
        if (api.missing.isNotEmpty) {
          // ignore: avoid_print
          print('[$name] routes non simulées : ${api.missing.toSet()}');
        }
      }, skip: _skip);
    }
  }

  testWidgets('vehicule_photo_feuille', (tester) async {
    await setUpApp(user: fakeUser(), routes: appRoutes());
    await pumpScreen(tester, const VehiculeDetailsScreen(vehiculeId: 'v1'));
    await tester.tap(find.text('Changer'));
    await settle(tester);
    await capture(tester, 'app_vehicule_photo_feuille');
  }, skip: _skip);

  // Clavier ouvert : le bouton du dock reste au-dessus (pavé numérique iOS).
  testWidgets('kilometrage_clavier', (tester) async {
    addTearDown(tester.view.reset);
    await setUpApp(user: fakeUser(), routes: appRoutes());
    await pumpScreen(tester, const KilometrageRequiredScreen(isRequired: true));
    await tester.tap(find.byType(TextFormField).last);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
    await settle(tester);
    await capture(tester, 'app_kilometrage_clavier');
  }, skip: _skip);

  testWidgets('vehicule_chauffeur', (tester) async {
    final driver = fakeUser(role: utilisateurRole);
    await setUpApp(user: driver, routes: appRoutes(user: driver));
    await pumpScreen(tester, const VehiculeDetailsScreen(vehiculeId: 'v2'));
    await capture(tester, 'app_vehicule_chauffeur');
  }, skip: _skip);
}

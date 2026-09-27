// Banc de captures d'écran : rend des écrans réels avec une API simulée et
// enregistre des PNG (build/visual/ par défaut, ou $VISUAL_OUT). Sert à
// vérifier le design sans appareil ni serveur.
//
//   flutter test test/visual --tags visual
//
// Les réponses simulées reprennent les formes renvoyées par api_avtrans.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:av_pointage/core/di/service_locator.dart';
import 'package:av_pointage/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Une route simulée : méthode + chemin (expression régulière) → réponse.
class FakeRoute {
  FakeRoute(this.method, String pattern, this.handler)
      : regex = RegExp('^$pattern\$');

  final String method;
  final RegExp regex;
  final Object? Function(RegExpMatch match, Map<String, dynamic> body) handler;
}

/// API simulée. Les chemins non déclarés répondent 404 et sont journalisés
/// dans [missing] (utile pour compléter les jeux de données).
class FakeApi {
  FakeApi(this.routes);

  final List<FakeRoute> routes;
  final List<String> missing = [];

  http.Client get client => MockClient((request) async {
        final path = request.url.path;
        Map<String, dynamic> body = const {};
        if (request.body.isNotEmpty) {
          final decoded = jsonDecode(request.body);
          if (decoded is Map<String, dynamic>) body = decoded;
        }
        for (final r in routes) {
          if (r.method != request.method) continue;
          final m = r.regex.firstMatch(path);
          if (m == null) continue;
          final result = r.handler(m, body);
          return http.Response.bytes(
            utf8.encode(jsonEncode(result)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        missing.add('${request.method} $path');
        return http.Response(
          jsonEncode({'success': false, 'message': 'Non simulé : $path'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });
}

String _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return env;
  // Repli : flutter est dans le PATH (…/flutter/bin/flutter).
  final result = Process.runSync(
    Platform.isWindows ? 'where' : 'which',
    ['flutter'],
    runInShell: true,
  );
  final first = (result.stdout as String).split(RegExp(r'[\r\n]+')).first.trim();
  return File(first).parent.parent.path;
}

String _packageRoot(String name) {
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final pkg = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['name'] == name);
  return Uri.parse(pkg['rootUri'] as String).toFilePath();
}

bool _fontsLoaded = false;

/// Charge la police de l'app et les polices d'icônes (sinon : carrés Ahem).
/// À appeler dans `setUpAll` : les lectures de fichiers n'aboutissent pas
/// dans la zone à horloge simulée d'un `testWidgets`.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;

  Future<void> load(String family, String path) async {
    final bytes = await File(path).readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  const jakarta = 'lib/assets/fonts/PlusJakartaSans.ttf';
  await load('Jakarta', jakarta);
  await load('Roboto', jakarta);
  final material =
      '${_flutterRoot()}/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
  await load('MaterialIcons', material);
  await load(
    'packages/cupertino_icons/CupertinoIcons',
    '${_packageRoot('cupertino_icons')}/assets/CupertinoIcons.ttf',
  );
}

/// Prépare le service locator avec l'API simulée et un utilisateur connecté.
Future<FakeApi> setUpApp({
  required Map<String, dynamic> user,
  required List<FakeRoute> routes,
}) async {
  await initializeDateFormatting('fr_FR', null);
  SharedPreferences.setMockInitialValues({
    'auth_token': 'token-de-test',
    'cached_user': jsonEncode(user),
  });
  final api = FakeApi(routes);
  await sl.initForTesting(client: api.client);
  return api;
}

final _boundaryKey = GlobalKey();

/// Monte [home] dans l'app (thème, français) à la taille d'un téléphone.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget home, {
  bool dark = false,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );
  await settle(tester);
}

/// Laisse passer requêtes simulées et animations (sans attendre les
/// animations infinies : squelettes, indicateurs).
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Enregistre l'écran courant en PNG.
Future<void> capture(WidgetTester tester, String name) async {
  final out = Platform.environment['VISUAL_OUT'] ?? 'build/visual';
  await tester.runAsync(() async {
    final boundary = _boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$out/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

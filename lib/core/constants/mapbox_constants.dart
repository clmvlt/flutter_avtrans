import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';

/// Configuration Mapbox pour l'affichage des cartes (feature Circuit).
///
/// On affiche les **tuiles raster Mapbox** via `flutter_map` (pur Dart, compatible
/// avec un simple token public `pk.`, sans SDK natif). Le cache de tuiles
/// intégré de flutter_map est configuré pour éviter de re-télécharger la carte à
/// chaque ouverture (persistant entre les sessions).
abstract class MapboxConstants {
  /// Token public Mapbox (sert uniquement à afficher la carte).
  /// Lu depuis `.env` (jamais committé) — voir `.env.example`.
  static String get accessToken => dotenv.env['MAPBOX_TOKEN'] ?? '';

  /// Style de carte utilisé.
  static const String styleId = 'streets-v12';

  /// Gabarit d'URL des tuiles (256px @2x = net sur écrans retina).
  static String get tileUrlTemplate =>
      'https://api.mapbox.com/styles/v1/mapbox/$styleId/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken';

  static const String attribution = '© Mapbox  © OpenStreetMap';

  static const String _userAgent = 'com.example.av_pointage';

  /// Initialise le cache de tuiles (à appeler au démarrage de l'app).
  ///
  /// Utilise un répertoire persistant dédié (et non le cache OS, qui peut être
  /// vidé), plafonné à 300 Mo. Le provider est un singleton : les `TileLayer`
  /// le réutilisent automatiquement.
  static Future<void> initCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      BuiltInMapCachingProvider.getOrCreateInstance(
        cacheDirectory: '${dir.path}/mapbox_tiles',
        maxCacheSize: 300 * 1024 * 1024,
      );
    } catch (_) {
      // En cas d'échec, flutter_map retombe sur son cache par défaut.
    }
  }

  /// Construit la couche de tuiles Mapbox (cache intégré activé).
  static TileLayer tileLayer() => TileLayer(
        urlTemplate: tileUrlTemplate,
        userAgentPackageName: _userAgent,
        maxNativeZoom: 22,
        tileProvider: NetworkTileProvider(
          cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(),
        ),
      );
}

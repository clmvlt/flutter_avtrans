import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/update_check_response.dart';
import '../di/service_locator.dart';

/// Service pour vérifier les mises à jour de l'application
/// Gère le stockage du dernier check et la logique de 24h
class UpdateCheckerService {
  static const String _lastCheckKey = 'update_last_check_timestamp';
  static const String _skippedVersionKey = 'update_skipped_version';
  static const String _firstLaunchKey = 'update_first_launch_done';
  static const Duration _checkInterval = Duration(hours: 24);

  final SharedPreferences _prefs;
  PackageInfo? _packageInfo;

  UpdateCheckerService(this._prefs);

  /// Crée une instance du service
  static Future<UpdateCheckerService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return UpdateCheckerService(prefs);
  }

  /// Récupère les informations du package (version actuelle)
  Future<PackageInfo> get packageInfo async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!;
  }

  /// Récupère le versionCode actuel de l'app
  Future<int> get currentVersionCode async {
    final info = await packageInfo;
    return int.tryParse(info.buildNumber) ?? 1;
  }

  /// Récupère le versionName actuel de l'app
  Future<String> get currentVersionName async {
    final info = await packageInfo;
    return info.version;
  }

  /// Timestamp du dernier check
  DateTime? get lastCheckTime {
    final timestamp = _prefs.getInt(_lastCheckKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Sauvegarde le timestamp du dernier check
  Future<void> _saveLastCheckTime() async {
    await _prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Vérifie si c'est le premier lancement de l'app
  bool get isFirstLaunch {
    return !_prefs.containsKey(_firstLaunchKey);
  }

  /// Marque le premier lancement comme effectué
  Future<void> _markFirstLaunchDone() async {
    await _prefs.setBool(_firstLaunchKey, true);
  }

  /// Vérifie si un check est nécessaire (plus de 24h depuis le dernier)
  bool shouldCheckForUpdate() {
    // Pas de check au premier lancement
    if (isFirstLaunch) return false;

    final lastCheck = lastCheckTime;
    if (lastCheck == null) return true;

    final elapsed = DateTime.now().difference(lastCheck);
    return elapsed >= _checkInterval;
  }

  /// Version ignorée par l'utilisateur
  int? get skippedVersionCode {
    return _prefs.getInt(_skippedVersionKey);
  }

  /// Marque une version comme ignorée
  Future<void> skipVersion(int versionCode) async {
    await _prefs.setInt(_skippedVersionKey, versionCode);
  }

  /// Réinitialise la version ignorée
  Future<void> clearSkippedVersion() async {
    await _prefs.remove(_skippedVersionKey);
  }

  /// Vérifie les mises à jour auprès de l'API
  /// Retourne null si pas de mise à jour ou si erreur
  /// [forceCheck] permet de forcer la vérification même si moins de 24h
  /// Note: Désactivé sur iOS (mises à jour via App Store uniquement)
  Future<UpdateCheckResponse?> checkForUpdate({bool forceCheck = false}) async {
    // Sur iOS, les mises à jour se font via l'App Store
    if (Platform.isIOS) {
      return null;
    }

    // Au premier lancement, on marque comme fait et on skip la vérification
    if (isFirstLaunch) {
      await _markFirstLaunchDone();
      await _saveLastCheckTime();
      if (!forceCheck) {
        return null;
      }
    }

    // Vérifie si un check est nécessaire
    if (!forceCheck && !shouldCheckForUpdate()) {
      return null;
    }

    try {
      final versionCode = await currentVersionCode;
      final versionName = await currentVersionName;
      final result = await sl.appVersionRepository.checkForUpdate(versionCode);

      // Sauvegarde le timestamp du check
      await _saveLastCheckTime();

      return result.fold(
        (failure) => null,
        (response) {
          // Vérifie si une mise à jour est vraiment disponible
          // Ne pas afficher si la version actuelle est >= à la dernière version
          if (!response.updateAvailable ||
              response.latestVersionCode <= response.currentVersionCode) {
            return null;
          }

          // Comparaison par versionName : si le nom de version est identique,
          // pas de mise à jour (contourne le problème de buildNumber manquant)
          if (response.latestVersion != null &&
              response.latestVersion!.versionName == versionName) {
            return null;
          }

          // Vérifie si la version n'a pas été ignorée
          if (response.latestVersion != null) {
            final skipped = skippedVersionCode;
            if (skipped != null &&
                skipped >= response.latestVersion!.versionCode) {
              return null;
            }
          }
          return response;
        },
      );
    } catch (_) {
      return null;
    }
  }

  /// Réinitialise le timestamp du dernier check (pour forcer un nouveau check)
  Future<void> resetLastCheck() async {
    await _prefs.remove(_lastCheckKey);
  }
}

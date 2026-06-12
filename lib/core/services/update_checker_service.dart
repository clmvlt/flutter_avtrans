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
          if (!response.updateAvailable) return null;

          final latest = response.latestVersion;
          if (latest == null) return null;

          // Source de vérité : comparaison SÉMANTIQUE du versionName.
          // Le versionCode du device est peu fiable (Flutter met versionCode=1
          // si pas de +build dans pubspec, alors que le serveur le calcule
          // différemment), ce qui faisait proposer une mise à jour vers la
          // version déjà installée. On se fie au versionName, qui est cohérent
          // entre le device et le serveur (et c'est ce que voit l'utilisateur).
          if (!isVersionNewer(latest.versionName, versionName)) {
            return null;
          }

          // Vérifie si la version n'a pas été ignorée
          final skipped = skippedVersionCode;
          if (skipped != null && skipped >= latest.versionCode) {
            return null;
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

  /// Compare deux versionNames de façon sémantique (ex: "1.0.17", "1.2.0").
  /// Retourne `true` uniquement si [candidate] est STRICTEMENT plus récente
  /// que [current]. Versions égales ou inférieures → `false`.
  ///
  /// Robuste aux séparateurs non numériques et aux longueurs différentes
  /// ("1.2" est traité comme "1.2.0").
  static bool isVersionNewer(String candidate, String current) {
    final a = _parseVersion(candidate);
    final b = _parseVersion(current);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av > bv;
    }
    return false; // versions identiques
  }

  static List<int> _parseVersion(String version) {
    return version
        .trim()
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }
}

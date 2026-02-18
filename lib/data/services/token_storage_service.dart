import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/exceptions.dart';

/// Service de stockage sécurisé pour le token d'authentification
class TokenStorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'cached_user';

  final SharedPreferences _prefs;

  TokenStorageService(this._prefs);

  /// Factory pour créer une instance avec SharedPreferences
  static Future<TokenStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return TokenStorageService(prefs);
  }

  /// Sauvegarde le token d'authentification
  Future<void> saveToken(String token) async {
    try {
      await _prefs.setString(_tokenKey, token);
    } catch (_) {
      throw const CacheException(
        message: 'Erreur lors de la sauvegarde du token.',
      );
    }
  }

  /// Récupère le token d'authentification
  String? getToken() {
    try {
      return _prefs.getString(_tokenKey);
    } catch (_) {
      throw const CacheException(
        message: 'Erreur lors de la récupération du token.',
      );
    }
  }

  /// Supprime le token d'authentification
  Future<void> deleteToken() async {
    try {
      await _prefs.remove(_tokenKey);
    } catch (_) {
      throw const CacheException(
        message: 'Erreur lors de la suppression du token.',
      );
    }
  }

  /// Sauvegarde les données utilisateur en cache
  Future<void> saveUserData(String userData) async {
    try {
      await _prefs.setString(_userKey, userData);
    } catch (_) {
      throw const CacheException(
        message: 'Erreur lors de la sauvegarde des données utilisateur.',
      );
    }
  }

  /// Récupère les données utilisateur en cache
  String? getUserData() {
    try {
      return _prefs.getString(_userKey);
    } catch (_) {
      throw const CacheException(
        message: 'Erreur lors de la récupération des données utilisateur.',
      );
    }
  }

  /// Supprime toutes les données en cache
  Future<void> clearAll() async {
    try {
      await _prefs.remove(_tokenKey);
      await _prefs.remove(_userKey);
    } catch (_) {
      throw const CacheException(
        message: 'Erreur lors de la suppression des données.',
      );
    }
  }

  /// Vérifie si un token existe
  bool hasToken() {
    return _prefs.containsKey(_tokenKey);
  }
}

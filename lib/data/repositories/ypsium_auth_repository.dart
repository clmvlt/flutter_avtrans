import 'dart:convert';
import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/ypsium_api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/ypsium_auth_models.dart';
import '../services/ypsium_http_service.dart';

/// Repository d'authentification pour l'API Ypsium
///
/// Gère le flux d'auth en 2 étapes :
/// 1. Obtention du token de session via clé machine
/// 2. Login avec identifiant/mot de passe
///
/// Supporte le "Remember Me" pour sauvegarder les identifiants
class YpsiumAuthRepository {
  final YpsiumHttpService _httpService;
  final SharedPreferences _prefs;

  static const String _machineKeyKey = 'ypsium_machine_key';
  static const String _tokenKey = 'ypsium_token';
  static const String _sessionIdChauffeurKey = 'ypsium_session_id_chauffeur';
  static const String _sessionLoginKey = 'ypsium_session_login';
  static const String _sessionNomKey = 'ypsium_session_nom';
  static const String _loginKey = 'ypsium_saved_login';
  static const String _passwordKey = 'ypsium_saved_password';
  static const String _rememberMeKey = 'ypsium_remember_me';

  YpsiumSession? _currentSession;

  YpsiumAuthRepository({
    required YpsiumHttpService httpService,
    required SharedPreferences prefs,
  })  : _httpService = httpService,
        _prefs = prefs;

  /// Effectue le login complet en 2 étapes
  /// Le serveur retourne le profil chauffeur (dont idChauffeur) en cas de succès
  Future<Either<Failure, YpsiumSession>> login({
    required String login,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      // Étape 1 : Obtenir le token de session via la clé machine
      final machineKey = _getOrCreateMachineKey();
      final encodedKey = _encodeKeyToBase64(machineKey);

      final connexionResponse = await _httpService.get(
        YpsiumAuthEndpoints.getConnexion(encodedKey),
      );

      final connexion = YpsiumConnexionResponse.fromJson(
        connexionResponse as Map<String, dynamic>,
      );

      if (!connexion.auth) {
        return const Left(AuthFailure(
          message: 'Clé machine non reconnue par le serveur Ypsium.',
        ));
      }

      // Décoder le token pour obtenir le session_id (UUID)
      final sessionId = _decodeTokenToSessionId(connexion.token);

      // Étape 2 : Login avec identifiant/mot de passe
      final logonResponse = await _httpService.post(
        YpsiumAuthEndpoints.logon(sessionId),
        body: YpsiumLogonRequest(
          login: login.toUpperCase(),
          password: password,
        ).toJson(),
      );

      final logon = YpsiumLogonResponse.fromJson(
        logonResponse as Map<String, dynamic>,
      );

      if (!logon.auth) {
        return const Left(AuthFailure(
          message: 'Identifiant ou mot de passe incorrect.',
        ));
      }

      // Le token du logon remplace celui du getConnexion pour les requêtes API
      final sessionToken = logon.token.isNotEmpty ? logon.token : connexion.token;

      // Sauvegarder le token de session
      await _prefs.setString(_tokenKey, sessionToken);

      // Gérer le "Remember Me"
      await _saveRememberMe(
        rememberMe: rememberMe,
        login: login,
        password: password,
      );

      _currentSession = YpsiumSession(
        token: sessionToken,
        login: login.toUpperCase(),
        idChauffeur: logon.id,
        nom: logon.nom,
        typeChauff: logon.typeChauff,
        droitChauff: logon.droitChauff,
        droitEntrepot: logon.droitEntrepot,
        droitScanManuel: logon.droitScanManuel,
        droitSupOrdre: logon.droitSupOrdre,
        droitCreatOrdre: logon.droitCreatOrdre,
        signatureChauffAuto: logon.signatureChauffAuto,
      );

      // Persister la session pour restauration ultérieure
      await _saveSession(_currentSession!);

      return Right(_currentSession!);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  /// Vérifie si le serveur Ypsium est accessible
  Future<Either<Failure, bool>> ping() async {
    try {
      final response = await _httpService.get(YpsiumEndpoints.ping);
      final result = (response as Map<String, dynamic>)['result'];
      return Right(result == 1);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  /// Tente de restaurer une session précédente et vérifie sa validité
  /// Retourne la session si le token est encore valide, null sinon
  Future<YpsiumSession?> tryRestoreSession() async {
    final token = _prefs.getString(_tokenKey);
    final idChauffeur = _prefs.getString(_sessionIdChauffeurKey);
    final login = _prefs.getString(_sessionLoginKey);

    if (token == null || idChauffeur == null || login == null) return null;

    // Restaurer la session en mémoire
    _currentSession = YpsiumSession(
      token: token,
      login: login,
      idChauffeur: idChauffeur,
      nom: _prefs.getString(_sessionNomKey) ?? '',
    );

    // Vérifier la validité du token via un appel léger
    try {
      final response = await _httpService.get(
        YpsiumVehiculeEndpoints.getParamSaisieKilometrage(token),
      );
      final data = response as Map<String, dynamic>;
      if (data['TokenValide'] == true) {
        return _currentSession;
      }
    } catch (_) {
      // Token invalide ou erreur réseau
    }

    // Token invalide → nettoyer
    _currentSession = null;
    await _clearSession();
    return null;
  }

  /// Déconnexion Ypsium
  Future<void> logout() async {
    _currentSession = null;
    await _clearSession();
  }

  /// Vérifie si une session Ypsium est active
  bool isLoggedIn() => _currentSession != null;

  /// Récupère la session courante
  YpsiumSession? get currentSession => _currentSession;

  /// Récupère le token de session actuel (Base64)
  String? get sessionToken => _currentSession?.token;

  /// Vérifie si "Remember Me" est activé
  bool get isRememberMeEnabled => _prefs.getBool(_rememberMeKey) ?? false;

  /// Récupère le login sauvegardé
  String? get savedLogin => _prefs.getString(_loginKey);

  /// Récupère le mot de passe sauvegardé
  String? get savedPassword => _prefs.getString(_passwordKey);

  // --- Méthodes privées ---

  /// Génère ou récupère la clé machine unique
  String _getOrCreateMachineKey() {
    final existing = _prefs.getString(_machineKeyKey);
    if (existing != null) return existing;

    // Génère une clé hex aléatoire de 16 caractères (comme dans la capture réseau)
    final random = Random.secure();
    final bytes = List.generate(8, (_) => random.nextInt(256));
    final key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    _prefs.setString(_machineKeyKey, key);
    return key;
  }

  /// Encode la clé machine en UTF-16LE puis Base64
  /// (format attendu par l'API Ypsium)
  String _encodeKeyToBase64(String key) {
    final utf16leBytes = <int>[];
    for (final char in key.codeUnits) {
      utf16leBytes.add(char & 0xFF);
      utf16leBytes.add((char >> 8) & 0xFF);
    }
    return base64Encode(utf16leBytes);
  }

  /// Décode le token Base64 pour obtenir le session_id UUID
  String _decodeTokenToSessionId(String tokenBase64) {
    final bytes = base64Decode(tokenBase64);
    return utf8.decode(bytes);
  }

  /// Sauvegarde ou supprime les identifiants selon "Remember Me"
  Future<void> _saveRememberMe({
    required bool rememberMe,
    required String login,
    required String password,
  }) async {
    await _prefs.setBool(_rememberMeKey, rememberMe);
    if (rememberMe) {
      await _prefs.setString(_loginKey, login);
      await _prefs.setString(_passwordKey, password);
    } else {
      await _prefs.remove(_loginKey);
      await _prefs.remove(_passwordKey);
    }
  }

  /// Persiste la session pour restauration au prochain lancement
  Future<void> _saveSession(YpsiumSession session) async {
    await _prefs.setString(_tokenKey, session.token);
    await _prefs.setString(_sessionIdChauffeurKey, session.idChauffeur);
    await _prefs.setString(_sessionLoginKey, session.login);
    await _prefs.setString(_sessionNomKey, session.nom);
  }

  /// Supprime les données de session persistées
  Future<void> _clearSession() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_sessionIdChauffeurKey);
    await _prefs.remove(_sessionLoginKey);
    await _prefs.remove(_sessionNomKey);
  }
}

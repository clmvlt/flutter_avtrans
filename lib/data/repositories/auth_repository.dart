import 'dart:convert';

import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/models.dart';
import '../services/google_sign_in_service.dart';
import '../services/http_service.dart';
import '../services/token_storage_service.dart';

/// Interface du repository d'authentification
abstract class IAuthRepository {
  /// Inscrit un nouvel utilisateur
  Future<Either<Failure, RegisterResponse>> register(RegisterRequest request);

  /// Connecte un utilisateur
  Future<Either<Failure, User>> login(LoginRequest request);

  /// Connexion via Google : SDK natif → ID token → `POST /auth/google`.
  /// `Left(CancelledFailure)` si l'utilisateur ferme le sélecteur de compte.
  Future<Either<Failure, GoogleAuthResponse>> signInWithGoogle();

  /// Création de compte via Google : `POST /auth/google/register` avec le
  /// **même** `idToken` que celui renvoyé par [signInWithGoogle].
  Future<Either<Failure, GoogleAuthResponse>> registerWithGoogle(
    GoogleRegisterRequest request,
  );

  /// Déconnecte l'utilisateur
  Future<Either<Failure, void>> logout();

  /// Récupère l'utilisateur courant
  Future<Either<Failure, User>> getCurrentUser();

  /// Demande une réinitialisation de mot de passe
  Future<Either<Failure, void>> requestPasswordReset(PasswordResetRequest request);

  /// Confirme la réinitialisation de mot de passe
  Future<Either<Failure, void>> confirmPasswordReset(PasswordResetConfirmRequest request);

  /// Vérifie l'email avec un token
  Future<Either<Failure, void>> verifyEmail(String token);

  /// Met à jour le profil utilisateur
  Future<Either<Failure, User>> updateProfile(UpdateProfileRequest request);

  /// Met à jour le mot de passe
  Future<Either<Failure, void>> updatePassword(UpdatePasswordRequest request);

  /// Vérifie si l'utilisateur est connecté
  bool isLoggedIn();

  /// Récupère l'utilisateur en cache
  User? getCachedUser();

  /// Vérifie le statut d'un utilisateur par son ID (vérification email et activation)
  Future<Either<Failure, UserStatusResponse>> checkUserStatus(String userId);
}

/// Implémentation du repository d'authentification
class AuthRepository implements IAuthRepository {
  final HttpService _httpService;
  final TokenStorageService _tokenStorage;
  final GoogleSignInService _googleSignIn;
  User? _cachedUser;

  AuthRepository({
    required HttpService httpService,
    required TokenStorageService tokenStorage,
    required GoogleSignInService googleSignInService,
  })  : _httpService = httpService,
        _tokenStorage = tokenStorage,
        _googleSignIn = googleSignInService {
    // Restaure le token au démarrage
    _restoreToken();
  }

  /// Restaure le token depuis le stockage
  void _restoreToken() {
    final token = _tokenStorage.getToken();
    if (token != null) {
      _httpService.setAuthToken(token);
    }

    // Restaure l'utilisateur en cache
    final userData = _tokenStorage.getUserData();
    if (userData != null) {
      try {
        _cachedUser = User.fromJson(jsonDecode(userData) as Map<String, dynamic>);
      } catch (_) {
        // Ignore les erreurs de parsing
      }
    }
  }

  @override
  Future<Either<Failure, RegisterResponse>> register(RegisterRequest request) async {
    try {
      final response = await _httpService.post(
        AuthEndpoints.register,
        body: request.toJson(),
      );

      return Right(RegisterResponse.fromJson(response));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, User>> login(LoginRequest request) async {
    try {
      final response = await _httpService.post(
        AuthEndpoints.login,
        body: request.toJson(),
      );

      final user = User.fromJson(response['user'] as Map<String, dynamic>);
      await _persistSession(user);

      return Right(user);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  /// Stocke le token API et met l'utilisateur en cache : la connexion
  /// classique et la connexion Google renvoient le même `AuthUserDTO`.
  Future<void> _persistSession(User user) async {
    if (user.token != null) {
      await _tokenStorage.saveToken(user.token!);
      _httpService.setAuthToken(user.token!);
    }
    _cachedUser = user;
    await _tokenStorage.saveUserData(jsonEncode(user.toJson()));
  }

  /// Fiche Google §2 : l'API vérifie elle-même l'ID token (signature,
  /// expiration, audience = client Web) — aucun appel Google côté serveur.
  ///
  /// - `AUTHENTICATED` : session persistée comme pour `/auth/login`.
  /// - `NEEDS_REGISTRATION` : enchaîner sur [registerWithGoogle] avec le même
  ///   `idToken` (exposé sur la réponse, valable 1 h).
  /// - Sélecteur fermé : `Left(CancelledFailure)` — à ignorer côté UI.
  /// - `400` (`Token Google invalide`, `Le compte n'est pas activé`…) :
  ///   `Left(ServerFailure)` avec le `message` serveur à afficher tel quel.
  @override
  Future<Either<Failure, GoogleAuthResponse>> signInWithGoogle() async {
    try {
      final idToken = await _googleSignIn.requestIdToken();

      final response = await _httpService.post(
        AuthEndpoints.google,
        body: GoogleAuthRequest(idToken: idToken).toJson(),
      );

      final auth = GoogleAuthResponse.fromJson(
        response as Map<String, dynamic>,
        idToken: idToken,
      );

      if (auth.status == GoogleAuthStatus.authenticated) {
        final user = auth.user;
        if (user == null) {
          return const Left(ServerFailure(
            message: 'Réponse inattendue du serveur : utilisateur manquant.',
          ));
        }
        await _persistSession(user);
      }

      return Right(auth);
    } on OperationCancelledException catch (e) {
      return Left(CancelledFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  /// Fiche Google §3 : `firstName` / `lastName` vides → valeurs Google ;
  /// l'email et l'identifiant Google sont toujours extraits du token.
  /// Réponse attendue : `PENDING_ACTIVATION` sans token (activation admin).
  /// `400` `Un compte existe déjà pour cet email` → repasser par
  /// [signInWithGoogle].
  @override
  Future<Either<Failure, GoogleAuthResponse>> registerWithGoogle(
    GoogleRegisterRequest request,
  ) async {
    try {
      final response = await _httpService.post(
        AuthEndpoints.googleRegister,
        body: request.toJson(),
      );

      return Right(GoogleAuthResponse.fromJson(
        response as Map<String, dynamic>,
        idToken: request.idToken,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _tokenStorage.clearAll();
      _httpService.setAuthToken(null);
      _cachedUser = null;
      // Réaffiche le sélecteur de compte Google à la prochaine connexion
      await _googleSignIn.signOut();
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    }
  }

  /// Rafraîchit le profil de l'utilisateur courant.
  ///
  /// Contrat API §3.6 / §4.1 : `GET /profile` est préféré à `GET /auth/me`
  /// (qui renvoie 400 `Token invalide` ou 500 si le header manque, sans vérifier
  /// `isActive`). `/profile` renvoie un `UserDTO` nu (sans token) et un 401 propre :
  /// le token stocké est réinjecté dans l'objet retourné.
  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      final response = await _httpService.get(ProfileEndpoints.me);

      final user = User.fromJson(response as Map<String, dynamic>)
          .copyWith(token: _tokenStorage.getToken());

      // Met à jour le cache
      _cachedUser = user;
      await _tokenStorage.saveUserData(jsonEncode(user.toJson()));

      return Right(user);
    } on NetworkException catch (e) {
      // Si pas de réseau, retourne l'utilisateur en cache
      if (_cachedUser != null) {
        return Right(_cachedUser!);
      }
      return Left(NetworkFailure(message: e.message));
    } on UnauthorizedException catch (e) {
      // Token invalide / compte désactivé : nettoie la session locale
      await logout();
      return Left(AuthFailure(message: e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> requestPasswordReset(PasswordResetRequest request) async {
    try {
      await _httpService.post(
        AuthEndpoints.passwordResetRequest,
        body: request.toJson(),
      );
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> confirmPasswordReset(PasswordResetConfirmRequest request) async {
    try {
      await _httpService.post(
        AuthEndpoints.passwordResetConfirm,
        body: request.toJson(),
      );
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> verifyEmail(String token) async {
    try {
      await _httpService.get(
        AuthEndpoints.verify,
        queryParameters: {'token': token},
      );
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, User>> updateProfile(UpdateProfileRequest request) async {
    try {
      final response = await _httpService.put(
        ProfileEndpoints.update,
        body: request.toJson(),
      );

      final user = User.fromJson(response);

      // Met à jour le cache
      _cachedUser = user;
      await _tokenStorage.saveUserData(jsonEncode(user.toJson()));

      return Right(user);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updatePassword(UpdatePasswordRequest request) async {
    try {
      await _httpService.put(
        ProfileEndpoints.password,
        body: request.toJson(),
      );
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  bool isLoggedIn() {
    return _tokenStorage.hasToken();
  }

  @override
  User? getCachedUser() {
    return _cachedUser;
  }

  /// `GET /auth/status/{userId}` — DTO nu `{ isMailVerified, isActive }`.
  /// 404 avec corps vide si l'utilisateur n'existe pas.
  @override
  Future<Either<Failure, UserStatusResponse>> checkUserStatus(String userId) async {
    try {
      final response = await _httpService.get(AuthEndpoints.status(userId));

      return Right(UserStatusResponse.fromJson(response as Map<String, dynamic>));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }
}

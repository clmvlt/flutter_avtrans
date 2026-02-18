import 'dart:convert';

import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/models.dart';
import '../services/http_service.dart';
import '../services/token_storage_service.dart';

/// Interface du repository d'authentification
abstract class IAuthRepository {
  /// Inscrit un nouvel utilisateur
  Future<Either<Failure, RegisterResponse>> register(RegisterRequest request);

  /// Connecte un utilisateur
  Future<Either<Failure, User>> login(LoginRequest request);

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
  User? _cachedUser;

  AuthRepository({
    required HttpService httpService,
    required TokenStorageService tokenStorage,
  })  : _httpService = httpService,
        _tokenStorage = tokenStorage {
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

      // Sauvegarde le token
      if (user.token != null) {
        await _tokenStorage.saveToken(user.token!);
        _httpService.setAuthToken(user.token!);
      }

      // Cache l'utilisateur
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
  Future<Either<Failure, void>> logout() async {
    try {
      await _tokenStorage.clearAll();
      _httpService.setAuthToken(null);
      _cachedUser = null;
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      final response = await _httpService.get(AuthEndpoints.me);

      final user = User.fromJson(response['user'] as Map<String, dynamic>);

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
      // Token expiré, nettoie le cache
      await logout();
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

  @override
  Future<Either<Failure, UserStatusResponse>> checkUserStatus(String userId) async {
    try {
      final response = await _httpService.get(AuthEndpoints.status(userId));

      return Right(UserStatusResponse.fromJson(response));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }
}

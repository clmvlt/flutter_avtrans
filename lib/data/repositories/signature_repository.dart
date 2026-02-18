import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/models.dart';
import '../services/http_service.dart';

/// Interface du repository des signatures
abstract class ISignatureRepository {
  /// Récupère toutes mes signatures
  Future<Either<Failure, List<Signature>>> getMySignatures();

  /// Crée une signature
  Future<Either<Failure, Signature>> createSignature(
      SignatureCreateRequest request);

  /// Récupère ma dernière signature
  Future<Either<Failure, Signature>> getLastSignature();

  /// Récupère le résumé de ma dernière signature
  Future<Either<Failure, SignatureSummary>> getLastSignatureSummary();

  /// [ADMIN] Supprimer une signature
  Future<Either<Failure, void>> deleteSignature(String signatureUuid);

  /// [ADMIN] Récupérer tous les utilisateurs avec leur dernière signature
  Future<Either<Failure, List<UserWithLastSignature>>> getAllUsersWithSignatures();

  /// [ADMIN] Récupérer toutes les signatures d'un utilisateur
  Future<Either<Failure, List<Signature>>> getUserSignatures(String userUuid);
}

/// Implémentation du repository des signatures
class SignatureRepository implements ISignatureRepository {
  final HttpService _httpService;

  SignatureRepository(this._httpService);

  @override
  Future<Either<Failure, List<Signature>>> getMySignatures() async {
    try {
      final response = await _httpService.get(SignatureEndpoints.all);

      final signatures = (response['signatures'] as List)
          .map((json) => Signature.fromJson(json))
          .toList();

      return Right(signatures);
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
  Future<Either<Failure, Signature>> createSignature(
      SignatureCreateRequest request) async {
    try {
      final response = await _httpService.post(
        SignatureEndpoints.create,
        body: request.toJson(),
      );

      // Vérification de la structure de la réponse
      if (response['signature'] == null) {
        return Left(ServerFailure(
          message: 'Réponse invalide: signature manquante. Réponse: $response',
        ));
      }

      final signature = Signature.fromJson(response['signature']);
      return Right(signature);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e, stackTrace) {
      // Capture toutes les autres erreurs (notamment les erreurs de parsing)
      return Left(ServerFailure(
        message: 'Erreur de parsing: $e\nStackTrace: $stackTrace',
      ));
    }
  }

  @override
  Future<Either<Failure, Signature>> getLastSignature() async {
    try {
      final response = await _httpService.get(SignatureEndpoints.last);

      final signature = Signature.fromJson(response['signature']);
      return Right(signature);
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
  Future<Either<Failure, SignatureSummary>> getLastSignatureSummary() async {
    try {
      final response = await _httpService.get(SignatureEndpoints.lastSummary);

      final summary = SignatureSummary.fromJson(response);
      return Right(summary);
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
  Future<Either<Failure, void>> deleteSignature(String signatureUuid) async {
    try {
      await _httpService.delete(SignatureEndpoints.delete(signatureUuid));
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
  Future<Either<Failure, List<UserWithLastSignature>>> getAllUsersWithSignatures() async {
    try {
      final response = await _httpService.get(SignatureEndpoints.allUsers);

      final users = (response['users'] as List)
          .map((json) => UserWithLastSignature.fromJson(json))
          .toList();

      return Right(users);
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
  Future<Either<Failure, List<Signature>>> getUserSignatures(String userUuid) async {
    try {
      final response = await _httpService.get(SignatureEndpoints.byUser(userUuid));

      final signatures = (response['signatures'] as List)
          .map((json) => Signature.fromJson(json))
          .toList();

      return Right(signatures);
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
}

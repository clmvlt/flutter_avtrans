import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/models.dart';
import '../services/http_service.dart';

/// Interface du repository des acomptes
abstract class IAcompteRepository {
  /// Crée une demande d'acompte
  Future<Either<Failure, Acompte>> createAcompte(AcompteCreateRequest request);

  /// Récupère mes demandes d'acompte
  Future<Either<Failure, PaginatedResponse<Acompte>>> getMyAcomptes(
      AcompteListParams params);

  /// Annule une demande d'acompte
  Future<Either<Failure, bool>> cancelAcompte(String uuid);
}

/// Implémentation du repository des acomptes
class AcompteRepository implements IAcompteRepository {
  final HttpService _httpService;

  AcompteRepository(this._httpService);

  @override
  Future<Either<Failure, Acompte>> createAcompte(
      AcompteCreateRequest request) async {
    try {
      final response = await _httpService.post(
        AcompteEndpoints.create,
        body: request.toJson(),
      );

      final acompte = Acompte.fromJson(response['acompte']);
      return Right(acompte);
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
  Future<Either<Failure, PaginatedResponse<Acompte>>> getMyAcomptes(
      AcompteListParams params) async {
    try {
      // La route /acomptes/my est en POST avec un body
      final response = await _httpService.post(
        AcompteEndpoints.my,
        body: params.toJson(),
      );

      final acomptes = (response['acomptes'] as List)
          .map((json) => Acompte.fromJson(json))
          .toList();

      final paginatedResponse = PaginatedResponse<Acompte>(
        success: true,
        content: acomptes,
        page: response['currentPage'] as int? ?? params.page ?? 0,
        totalPages: response['totalPages'] as int? ?? 1,
        totalElements: response['totalElements'] as int? ?? acomptes.length,
        last: (response['currentPage'] as int? ?? params.page ?? 0) >=
            ((response['totalPages'] as int? ?? 1) - 1),
        first: (params.page ?? 0) == 0,
        size: params.size ?? 10,
      );

      return Right(paginatedResponse);
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
  Future<Either<Failure, bool>> cancelAcompte(String uuid) async {
    try {
      await _httpService.delete(
        AcompteEndpoints.cancel(uuid),
      );

      // Retourne true pour indiquer que l'annulation a réussi
      return const Right(true);
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

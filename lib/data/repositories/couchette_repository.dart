import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/models.dart';
import '../services/http_service.dart';

/// Interface du repository des couchettes
abstract class ICouchetteRepository {
  Future<Either<Failure, Couchette>> createCouchette({String? date});
  Future<Either<Failure, PaginatedResponse<Couchette>>> getMyCouchettes({
    int page = 0,
    int size = 10,
  });
  Future<Either<Failure, bool>> deleteCouchette(String uuid);
}

/// Implémentation du repository des couchettes
class CouchetteRepository implements ICouchetteRepository {
  final HttpService _httpService;

  CouchetteRepository(this._httpService);

  @override
  Future<Either<Failure, Couchette>> createCouchette({String? date}) async {
    try {
      final body = <String, dynamic>{};
      if (date != null) body['date'] = date;

      final response = await _httpService.post(
        CouchetteEndpoints.create,
        body: body.isNotEmpty ? body : null,
      );

      // La réponse peut être directement le CouchetteDTO
      final couchetteData = response is Map<String, dynamic> &&
              response.containsKey('uuid')
          ? response
          : response;
      final couchette =
          Couchette.fromJson(couchetteData as Map<String, dynamic>);
      return Right(couchette);
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
  Future<Either<Failure, PaginatedResponse<Couchette>>> getMyCouchettes({
    int page = 0,
    int size = 10,
  }) async {
    try {
      final response = await _httpService.get(
        '${CouchetteEndpoints.my}?page=$page&size=$size',
      );

      final couchettes = (response['content'] as List)
          .map((json) => Couchette.fromJson(json as Map<String, dynamic>))
          .toList();

      final paginatedResponse = PaginatedResponse<Couchette>(
        success: true,
        content: couchettes,
        page: response['page'] as int? ?? page,
        size: response['size'] as int? ?? size,
        totalElements: response['totalElements'] as int? ?? couchettes.length,
        totalPages: response['totalPages'] as int? ?? 1,
        first: response['first'] as bool? ?? (page == 0),
        last: response['last'] as bool? ?? true,
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
  Future<Either<Failure, bool>> deleteCouchette(String uuid) async {
    try {
      await _httpService.delete(CouchetteEndpoints.delete(uuid));
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

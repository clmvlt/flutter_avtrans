import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/models.dart';
import '../services/http_service.dart';

/// Interface du repository des absences
abstract class IAbsenceRepository {
  /// Récupère tous les types d'absence
  Future<Either<Failure, List<AbsenceType>>> getAbsenceTypes();

  /// Crée une demande d'absence
  Future<Either<Failure, Absence>> createAbsence(CreateAbsenceRequest request);

  /// Récupère mes demandes d'absence
  Future<Either<Failure, PaginatedResponse<Absence>>> getMyAbsences(
      AbsenceListParams params);

  /// Annule une demande d'absence
  Future<Either<Failure, Absence>> cancelAbsence(String uuid);
}

/// Implémentation du repository des absences
class AbsenceRepository implements IAbsenceRepository {
  final HttpService _httpService;

  AbsenceRepository(this._httpService);

  @override
  Future<Either<Failure, List<AbsenceType>>> getAbsenceTypes() async {
    try {
      final response = await _httpService.get(AbsenceTypeEndpoints.all);

      final types = (response['types'] as List)
          .map((json) => AbsenceType.fromJson(json))
          .toList();

      return Right(types);
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
  Future<Either<Failure, Absence>> createAbsence(
      CreateAbsenceRequest request) async {
    try {
      final response = await _httpService.post(
        AbsenceEndpoints.create,
        body: request.toJson(),
      );

      final absence = Absence.fromJson(response['absence']);
      return Right(absence);
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
  Future<Either<Failure, PaginatedResponse<Absence>>> getMyAbsences(
      AbsenceListParams params) async {
    try {
      // La route /absences/my est maintenant en POST avec un body
      final response = await _httpService.post(
        AbsenceEndpoints.my,
        body: params.toJson(),
      );

      final absences = (response['absences'] as List)
          .map((json) => Absence.fromJson(json))
          .toList();

      final paginatedResponse = PaginatedResponse<Absence>(
        success: true,
        content: absences,
        page: response['currentPage'] as int? ?? params.page,
        totalPages: response['totalPages'] as int? ?? 1,
        totalElements: response['totalElements'] as int? ?? absences.length,
        last: (response['currentPage'] as int? ?? params.page) >=
            ((response['totalPages'] as int? ?? 1) - 1),
        first: params.page == 0,
        size: params.size,
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
  Future<Either<Failure, Absence>> cancelAbsence(String uuid) async {
    try {
      final response = await _httpService.delete(
        AbsenceEndpoints.cancel(uuid),
      );

      final absence = Absence.fromJson(response['absence']);
      return Right(absence);
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

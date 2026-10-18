import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/live_counter.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/paginated_response.dart';
import '../models/service_model.dart';
import '../models/service_request_models.dart';
import '../services/http_service.dart';

/// Interface du repository des services
abstract class IServiceRepository {
  /// Démarre un nouveau service. Les quatre actions renvoient le service de
  /// travail dans son état complet après l'action (pause en cours comprise).
  Future<Either<Failure, Service>> startService(ServiceGpsRequest request);

  /// Termine le service actif
  Future<Either<Failure, Service>> endService(ServiceGpsRequest request);

  /// Démarre une pause
  Future<Either<Failure, Service>> startBreak(ServiceGpsRequest request);

  /// Termine la pause en cours
  Future<Either<Failure, Service>> endBreak(ServiceGpsRequest request);

  /// Services de travail débutés dans le mois, pauses imbriquées
  Future<Either<Failure, List<Service>>> getMonthServices({
    int? year,
    int? month,
  });

  /// Récupère les heures travaillées
  Future<Either<Failure, WorkedHours>> getWorkedHours(
    WorkedHoursParams params,
  );

  /// Service de travail en cours (jamais la ligne de pause), `null` sinon
  Future<Either<Failure, Service?>> getActiveService();

  /// Récupère l'historique paginé des services
  Future<Either<Failure, PaginatedResponse<Service>>> getHistory(
    ServiceHistoryParams params,
  );

  /// Services de travail débutés aujourd'hui, pauses imbriquées
  Future<Either<Failure, List<Service>>> getDailyServices();
}

/// Implémentation du repository des services
class ServiceRepository implements IServiceRepository {
  final HttpService _httpService;

  ServiceRepository({
    required HttpService httpService,
  }) : _httpService = httpService;

  @override
  Future<Either<Failure, Service>> startService(ServiceGpsRequest request) async {
    try {
      final response = await _httpService.post(
        ServiceEndpoints.start,
        body: request.toJson(),
      );

      return Right(Service.fromJson(response));
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
  Future<Either<Failure, Service>> endService(ServiceGpsRequest request) async {
    try {
      final response = await _httpService.post(
        ServiceEndpoints.end,
        body: request.toJson(),
      );

      return Right(Service.fromJson(response));
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
  Future<Either<Failure, Service>> startBreak(ServiceGpsRequest request) async {
    try {
      final response = await _httpService.post(
        ServiceEndpoints.breakStart,
        body: request.toJson(),
      );

      return Right(Service.fromJson(response));
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
  Future<Either<Failure, Service>> endBreak(ServiceGpsRequest request) async {
    try {
      final response = await _httpService.post(
        ServiceEndpoints.breakEnd,
        body: request.toJson(),
      );

      return Right(Service.fromJson(response));
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
  Future<Either<Failure, List<Service>>> getMonthServices({
    int? year,
    int? month,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (year != null) queryParams['year'] = year.toString();
      if (month != null) queryParams['month'] = month.toString();

      // `GET /services/month?year&month` : tableau JSON nu des services de
      // travail débutés dans le mois, avec leurs `pauses`
      final response = await _httpService.get(
        ServiceEndpoints.month,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      return Right(_parseServiceList(response));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Erreur de parsing: $e'));
    }
  }

  /// Parse un tableau JSON nu de ServiceDTO (routes `/services/month`,
  /// `/services/user/daily`) ; une seule ancre pour toute la réponse.
  List<Service> _parseServiceList(dynamic response) {
    if (response is! List) return const [];
    final anchor = LiveAnchor.now();
    return response
        .map((json) =>
            Service.fromJson(json as Map<String, dynamic>, anchor: anchor))
        .toList();
  }

  @override
  Future<Either<Failure, WorkedHours>> getWorkedHours(
    WorkedHoursParams params,
  ) async {
    try {
      final queryParams = params.toQueryParams();

      final response = await _httpService.get(
        ServiceEndpoints.hours,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      return Right(WorkedHours.fromJson(response));
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
  Future<Either<Failure, Service?>> getActiveService() async {
    try {
      final response = await _httpService.get(ServiceEndpoints.active);

      // { "success": true, "service": { ... } | null } : toujours le service
      // de travail (pauses, enPause, dureeTravail), jamais la ligne de pause
      final serviceJson = response['service'];
      if (serviceJson == null) {
        return const Right(null);
      }

      return Right(Service.fromJson(serviceJson as Map<String, dynamic>));
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
  Future<Either<Failure, PaginatedResponse<Service>>> getHistory(
    ServiceHistoryParams params,
  ) async {
    try {
      final response = await _httpService.post(
        ServiceEndpoints.history,
        body: params.toJson(),
      );

      // À plat : une pause porte `serviceParentUuid`, un service ses `pauses`.
      final anchor = LiveAnchor.now();
      return Right(PaginatedResponse.fromJson(
        response,
        (json) => Service.fromJson(json, anchor: anchor),
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

  /// `GET /services/user/daily` : services de travail débutés aujourd'hui
  /// (Paris), pauses imbriquées, par début croissant.
  @override
  Future<Either<Failure, List<Service>>> getDailyServices() async {
    try {
      final response = await _httpService.get(ServiceEndpoints.daily);

      return Right(_parseServiceList(response));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Erreur de parsing: $e'));
    }
  }
}

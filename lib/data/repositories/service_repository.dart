import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/paginated_response.dart';
import '../models/service_model.dart';
import '../models/service_request_models.dart';
import '../services/http_service.dart';

/// Interface du repository des services
abstract class IServiceRepository {
  /// Démarre un nouveau service
  Future<Either<Failure, Service>> startService(ServiceGpsRequest request);

  /// Termine le service actif
  Future<Either<Failure, Service>> endService(ServiceGpsRequest request);

  /// Démarre une pause
  Future<Either<Failure, Service>> startBreak(ServiceGpsRequest request);

  /// Termine la pause en cours
  Future<Either<Failure, Service>> endBreak(ServiceGpsRequest request);

  /// Récupère les services d'un mois
  Future<Either<Failure, List<Service>>> getMonthServices({
    int? year,
    int? month,
  });

  /// Récupère les heures travaillées
  Future<Either<Failure, WorkedHours>> getWorkedHours(
    WorkedHoursParams params,
  );

  /// Récupère le service actif
  Future<Either<Failure, Service?>> getActiveService();

  /// Récupère l'historique paginé des services
  Future<Either<Failure, PaginatedResponse<Service>>> getHistory(
    ServiceHistoryParams params,
  );

  /// Récupère les services du jour de l'utilisateur
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

      final response = await _httpService.get(
        ServiceEndpoints.month,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      print('Réponse getMonthServices: $response');
      print('Type de réponse: ${response.runtimeType}');

      // La réponse peut être directement un tableau ou contenir un champ 'data'
      List<dynamic> servicesJson;
      if (response is List) {
        servicesJson = response as List<dynamic>;
      } else if (response['data'] != null) {
        servicesJson = response['data'] as List<dynamic>;
      } else {
        // Si la réponse n'est ni un tableau ni un objet avec 'data', retourner une liste vide
        print('Format de réponse inattendu: $response');
        return const Right([]);
      }

      final services = servicesJson
          .map((json) => Service.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(services);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e, stackTrace) {
      print('Erreur inattendue dans getMonthServices: $e');
      print('StackTrace: $stackTrace');
      return Left(ServerFailure(message: 'Erreur de parsing: $e'));
    }
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

      // La réponse est { "success": true, "service": { ... } } ou { "success": true, "service": null }
      // Peut retourner null si aucun service actif
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
      // 404 peut signifier aucun service actif
      if (e.statusCode == 404) {
        return const Right(null);
      }
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

      return Right(PaginatedResponse.fromJson(
        response,
        (json) => Service.fromJson(json),
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
  Future<Either<Failure, List<Service>>> getDailyServices() async {
    try {
      print('🔵 Appel API getDailyServices vers: ${ServiceEndpoints.daily}');
      final response = await _httpService.get(ServiceEndpoints.daily);

      print('🔵 Réponse brute getDailyServices: $response');
      print('🔵 Type de réponse: ${response.runtimeType}');

      // La réponse doit être un tableau de services
      List<dynamic> servicesJson;
      if (response is List) {
        print('🔵 Réponse est une List directe');
        servicesJson = response as List<dynamic>;
      } else if (response is Map && response['data'] != null) {
        print('🔵 Réponse est une Map avec field data');
        servicesJson = response['data'] as List<dynamic>;
      } else {
        print('⚠️ Format de réponse inattendu: $response');
        return const Right([]);
      }

      print('🔵 Nombre de services JSON: ${servicesJson.length}');

      final services = <Service>[];
      for (var i = 0; i < servicesJson.length; i++) {
        try {
          final json = servicesJson[i] as Map<String, dynamic>;
          print('🔵 Parsing service $i: $json');
          final service = Service.fromJson(json);
          services.add(service);
          print('✅ Service $i parsé avec succès');
        } catch (e, st) {
          print('❌ Erreur parsing service $i: $e');
          print('   JSON: ${servicesJson[i]}');
          print('   Stack: $st');
          // Continue avec les autres services
        }
      }

      print('🔵 Total services parsés: ${services.length}');

      // Trier par ordre décroissant (plus récent en premier)
      services.sort((a, b) => b.debut.compareTo(a.debut));

      return Right(services);
    } on NetworkException catch (e) {
      print('❌ NetworkException: ${e.message}');
      return Left(NetworkFailure(message: e.message));
    } on AuthException catch (e) {
      print('❌ AuthException: ${e.message}');
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      print('❌ ServerException: ${e.message}, code: ${e.statusCode}');
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      print('❌ AppException: ${e.message}');
      return Left(ServerFailure(message: e.message));
    } catch (e, stackTrace) {
      print('❌ Erreur inattendue dans getDailyServices: $e');
      print('❌ StackTrace: $stackTrace');
      return Left(ServerFailure(message: 'Erreur de parsing: $e'));
    }
  }
}

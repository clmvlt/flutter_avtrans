import 'package:dartz/dartz.dart';

import '../../core/constants/ors_api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/geo_point.dart';
import '../models/optimization_models.dart';
import '../models/routing_models.dart';
import '../services/ors_http_service.dart';

/// Accès aux endpoints d'optimisation et de routing de l'API ORS.
abstract class IRoutingRepository {
  /// Optimise l'ordre de passage (TSP) depuis/vers un dépôt commun.
  Future<Either<Failure, OptimizeResult>> optimize(OptimizeRequest request);

  /// Calcule l'itinéraire passant par [orderedPoints] DANS L'ORDRE fourni
  /// (sans réoptimisation) — pour rafraîchir le tracé après ajustement manuel.
  Future<Either<Failure, RouteResult>> route(List<GeoPoint> orderedPoints);
}

class RoutingRepository implements IRoutingRepository {
  final OrsHttpService _httpService;

  RoutingRepository(this._httpService);

  @override
  Future<Either<Failure, OptimizeResult>> optimize(
    OptimizeRequest request,
  ) async {
    try {
      final response = await _httpService.post(
        OrsEndpoints.optimize,
        body: request.toJson(),
      );
      if (response is! Map<String, dynamic>) {
        return const Left(ServerFailure(message: 'Réponse d\'optimisation invalide.'));
      }
      return Right(OptimizeResult.fromJson(response));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(_mapServer(e));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, RouteResult>> route(
    List<GeoPoint> orderedPoints,
  ) async {
    if (orderedPoints.length < 2) {
      return const Left(ServerFailure(message: 'Au moins deux points sont requis.'));
    }
    try {
      final response = await _httpService.post(
        OrsEndpoints.route,
        body: {
          'points': orderedPoints.map((p) => p.toJson()).toList(),
          'geometryFormat': 'POINTS',
        },
      );
      if (response is! Map<String, dynamic>) {
        return const Left(ServerFailure(message: 'Itinéraire invalide.'));
      }
      return Right(RouteResult.fromJson(response));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(_mapServer(e));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  Failure _mapServer(ServerException e) {
    if (e.statusCode == 503) {
      return const ServerFailure(
        message:
            'Service d\'itinéraires momentanément indisponible. Réessaie dans un instant.',
        statusCode: 503,
      );
    }
    if (e.statusCode == 400) {
      return const ServerFailure(
        message: 'Point de départ invalide ou non rattachable au réseau routier.',
        statusCode: 400,
      );
    }
    return ServerFailure(message: e.message, statusCode: e.statusCode);
  }
}

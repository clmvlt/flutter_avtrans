import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/rapport_vehicule_model.dart';
import '../services/http_service.dart';

/// Interface du repository des rapports de véhicules
abstract class IRapportRepository {
  /// Crée un nouveau rapport de véhicule
  Future<Either<Failure, RapportVehicule>> createRapport(
    CreateRapportRequest request,
  );

  /// Récupère le dernier rapport de l'utilisateur connecté
  /// Retourne null si aucun rapport n'existe (erreur 400)
  Future<Either<Failure, RapportVehicule?>> getMyLatestRapport();

  /// Récupère tous les rapports d'un véhicule
  Future<Either<Failure, List<RapportVehicule>>> getRapportsByVehicule(
    String vehiculeId,
  );
}

/// Implémentation du repository des rapports de véhicules
class RapportRepository implements IRapportRepository {
  final HttpService _httpService;

  RapportRepository({
    required HttpService httpService,
  }) : _httpService = httpService;

  @override
  Future<Either<Failure, RapportVehicule>> createRapport(
    CreateRapportRequest request,
  ) async {
    try {
      final response = await _httpService.post(
        RapportEndpoints.create,
        body: request.toJson(),
      );

      // Debug: afficher la réponse complète
      print('📦 Réponse API complète: $response');

      // Vérifier que la réponse contient 'data'
      if (response is! Map<String, dynamic>) {
        throw Exception('Réponse API invalide: type ${response.runtimeType}');
      }

      if (!response.containsKey('data')) {
        throw Exception('Réponse API sans clé "data": $response');
      }

      final data = response['data'];
      print('📦 Données extraites: $data');

      if (data is! Map<String, dynamic>) {
        throw Exception('data n\'est pas un Map: type ${data.runtimeType}');
      }

      final rapport = RapportVehicule.fromJson(data);
      print('✅ Rapport créé avec succès: ${rapport.id}');

      return Right(rapport);
    } on ServerException catch (e) {
      print('❌ ServerException: ${e.message}');
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on NetworkException catch (e) {
      print('❌ NetworkException: ${e.message}');
      return Left(NetworkFailure(message: e.message));
    } on ValidationException catch (e) {
      print('❌ ValidationException: ${e.message}');
      return Left(ValidationFailure(
        message: e.message,
        errors: e.errors,
      ));
    } on UnauthorizedException catch (e) {
      print('❌ UnauthorizedException: ${e.message}');
      return Left(AuthFailure(message: e.message));
    } catch (e, stackTrace) {
      print('❌ Erreur inattendue: $e');
      print('📍 Stack trace: $stackTrace');
      return Left(ServerFailure(
        message: 'Erreur lors de la création du rapport: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Either<Failure, RapportVehicule?>> getMyLatestRapport() async {
    try {
      final response = await _httpService.get(RapportEndpoints.myLatest);

      final data = response['data'] as Map<String, dynamic>;
      final rapport = RapportVehicule.fromJson(data);

      return Right(rapport);
    } on ServerException catch (e) {
      // Si le code d'erreur est 400, cela signifie qu'aucun rapport n'existe
      // On retourne null au lieu d'une erreur
      if (e.statusCode == 400) {
        return const Right(null);
      }
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on UnauthorizedException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Erreur lors de la récupération du rapport: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Either<Failure, List<RapportVehicule>>> getRapportsByVehicule(
    String vehiculeId,
  ) async {
    try {
      final response = await _httpService.get(
        RapportEndpoints.byVehicule(vehiculeId),
      );

      final data = response['data'] as List<dynamic>;
      final rapports = data
          .map((json) => RapportVehicule.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(rapports);
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on UnauthorizedException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Erreur lors de la récupération des rapports: ${e.toString()}',
      ));
    }
  }
}

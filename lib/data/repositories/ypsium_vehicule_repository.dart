import 'package:dartz/dartz.dart';

import '../../core/constants/ypsium_api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/ypsium_models.dart';
import '../services/ypsium_http_service.dart';
import 'ypsium_auth_repository.dart';

/// Repository pour la gestion des véhicules Ypsium
class YpsiumVehiculeRepository {
  final YpsiumHttpService _httpService;
  final YpsiumAuthRepository _authRepository;

  YpsiumVehiculeRepository({
    required YpsiumHttpService httpService,
    required YpsiumAuthRepository authRepository,
  })  : _httpService = httpService,
        _authRepository = authRepository;

  String get _token => _authRepository.sessionToken!;
  String get _idChauffeur => _authRepository.currentSession!.idChauffeur;

  /// Récupère la liste des véhicules disponibles
  Future<Either<Failure, List<YpsiumVehicule>>> getListeVehicules() async {
    try {
      final response = await _httpService.get(
        YpsiumVehiculeEndpoints.getListeVehicules(_idChauffeur, _token),
      );

      final data = response as Map<String, dynamic>;
      final list = (data['Data'] as List<dynamic>?) ?? [];
      final vehicules = list
          .map((e) => YpsiumVehicule.fromJson(e as Map<String, dynamic>))
          .toList();
      return Right(vehicules);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  /// Récupère les paramètres de saisie du kilométrage
  Future<Either<Failure, bool>> getParamSaisieKilometrage() async {
    try {
      final response = await _httpService.get(
        YpsiumVehiculeEndpoints.getParamSaisieKilometrage(_token),
      );
      final data = response as Map<String, dynamic>;
      return Right((data['bSaisiekilometrage'] as int? ?? 0) == 1);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  /// Récupère le kilométrage d'un véhicule
  Future<Either<Failure, int>> getKilometreVehicule(int idVehicule) async {
    try {
      final response = await _httpService.get(
        YpsiumVehiculeEndpoints.getKilometreVehicule(idVehicule, _token),
      );
      final data = response as Map<String, dynamic>;
      return Right(data['Kilométrage'] as int? ?? 0);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  /// Enregistre le choix de véhicule
  Future<Either<Failure, bool>> setChoixVehicule(
    YpsiumChoixVehiculeRequest request,
  ) async {
    try {
      await _httpService.post(
        YpsiumVehiculeEndpoints.setChoixVehicule(_token),
        body: request.toJson(),
      );
      return const Right(true);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }
}

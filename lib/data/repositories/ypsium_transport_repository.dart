import 'package:dartz/dartz.dart';

import '../../core/constants/ypsium_api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/ypsium_models.dart';
import '../services/ypsium_http_service.dart';
import 'ypsium_auth_repository.dart';

/// Repository pour les opérations de transport Ypsium
class YpsiumTransportRepository {
  final YpsiumHttpService _httpService;
  final YpsiumAuthRepository _authRepository;

  YpsiumTransportRepository({
    required YpsiumHttpService httpService,
    required YpsiumAuthRepository authRepository,
  })  : _httpService = httpService,
        _authRepository = authRepository;

  String get _token => _authRepository.sessionToken!;
  String get _idChauffeur => _authRepository.currentSession!.idChauffeur;

  /// Récupère la liste des ordres de transport pour une date
  /// [date] au format YYYYMMDD, [filtre] ex: "TOUS"
  Future<Either<Failure, List<YpsiumTransportOrder>>> getListeTransport({
    String? date,
    String filtre = 'TOUS',
  }) async {
    try {
      final dateStr = date ?? _todayFormatted();
      final response = await _httpService.get(
        YpsiumTransportEndpoints.getListeTransport(
          _idChauffeur,
          dateStr,
          filtre,
          _token,
        ),
      );

      final data = response as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>?) ?? [];
      final orders = list
          .map((e) => YpsiumTransportOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      return Right(orders);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  /// Ajoute un colis au chargement d'un ordre
  Future<Either<Failure, bool>> addColisChargement({
    required int idOrdre,
    required YpsiumAddColisRequest request,
  }) async {
    try {
      final response = await _httpService.post(
        YpsiumOperationEndpoints.addColisChargement(idOrdre, _token),
        body: request.toJson(),
      );

      final data = response as Map<String, dynamic>;
      return Right(data['result'] == 'OK');
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  /// Envoie une photo au départ de l'enlèvement
  Future<Either<Failure, bool>> setPhotoEnlDepart({
    required int idOrdre,
    required List<String> photosBase64,
  }) async {
    try {
      final response = await _httpService.post(
        YpsiumOperationEndpoints.setPhotoEnlDepart(idOrdre, _token),
        body: {'tabBufPhoto': photosBase64},
      );

      final data = response as Map<String, dynamic>;
      return Right(data['result'] == 'OK');
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  /// Valide l'enlèvement d'un point
  Future<Either<Failure, bool>> setPointEnleve({
    required int idOrdre,
    required YpsiumSetPointEnleveRequest request,
  }) async {
    try {
      await _httpService.post(
        YpsiumOperationEndpoints.setPointEnleve(idOrdre, _token),
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

  /// Envoie une photo à la livraison
  Future<Either<Failure, bool>> setPhotoLivDepart({
    required int idOrdre,
    required List<String> photosBase64,
  }) async {
    try {
      final response = await _httpService.post(
        YpsiumOperationEndpoints.setPhotoLivDepart(idOrdre, _token),
        body: {'tabBufPhoto': photosBase64},
      );

      final data = response as Map<String, dynamic>;
      return Right(data['result'] == 'OK');
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  /// Valide la livraison d'un point
  Future<Either<Failure, bool>> setPointLivre({
    required int idOrdre,
    required YpsiumSetPointEnleveRequest request,
  }) async {
    try {
      await _httpService.post(
        YpsiumOperationEndpoints.setPointLivre(idOrdre, _token),
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

  /// Envoie la position GPS
  Future<Either<Failure, bool>> setPositionGPS(
    YpsiumGpsRequest request,
  ) async {
    try {
      final response = await _httpService.post(
        YpsiumGpsEndpoints.setPositionGPS,
        body: request.toJson(),
      );

      final data = response as Map<String, dynamic>;
      return Right(data['result'] == 1);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  String _todayFormatted() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

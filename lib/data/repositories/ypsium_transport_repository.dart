import 'package:dartz/dartz.dart';

import '../../core/constants/ypsium_api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/ypsium_models.dart';
import '../services/ypsium_http_service.dart';
import '../services/ypsium_spooler_service.dart';
import 'ypsium_auth_repository.dart';

/// Repository pour les opérations de transport Ypsium
class YpsiumTransportRepository {
  final YpsiumHttpService _httpService;
  final YpsiumAuthRepository _authRepository;
  final YpsiumSpoolerService _spoolerService;

  YpsiumTransportRepository({
    required YpsiumHttpService httpService,
    required YpsiumAuthRepository authRepository,
    required YpsiumSpoolerService spoolerService,
  })  : _httpService = httpService,
        _authRepository = authRepository,
        _spoolerService = spoolerService;

  String get _token => _authRepository.sessionToken!;
  String get _idChauffeur => _authRepository.currentSession!.idChauffeur;

  /// Récupère la liste des ordres de transport pour une date
  /// [date] au format YYYYMMDD, [filtre] ex: "TOUS"
  /// Note : les lectures ne passent PAS par le spooler
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

  /// Ajoute un colis au chargement d'un ordre — via spooler (optimiste)
  Future<Either<Failure, bool>> addColisChargement({
    required int idOrdre,
    required YpsiumAddColisRequest request,
  }) async {
    await _spoolerService.enqueue(
      method: 'POST',
      endpoint: YpsiumOperationEndpoints.addColisChargement(idOrdre, _token),
      body: request.toJson(),
      label: 'Ajout colis — Ordre #$idOrdre',
    );
    return const Right(true);
  }

  /// Envoie une photo au départ de l'enlèvement — via spooler (optimiste)
  Future<Either<Failure, bool>> setPhotoEnlDepart({
    required int idOrdre,
    required List<String> photosBase64,
  }) async {
    await _spoolerService.enqueue(
      method: 'POST',
      endpoint: YpsiumOperationEndpoints.setPhotoEnlDepart(idOrdre, _token),
      body: {'tabBufPhoto': photosBase64},
      label: 'Photos enlèvement — Ordre #$idOrdre',
    );
    return const Right(true);
  }

  /// Valide l'enlèvement d'un point — via spooler (optimiste)
  Future<Either<Failure, bool>> setPointEnleve({
    required int idOrdre,
    required YpsiumSetPointEnleveRequest request,
  }) async {
    await _spoolerService.enqueue(
      method: 'POST',
      endpoint: YpsiumOperationEndpoints.setPointEnleve(idOrdre, _token),
      body: request.toJson(),
      label: 'Validation enlèvement — Ordre #$idOrdre',
    );
    return const Right(true);
  }

  /// Envoie une photo à la livraison — via spooler (optimiste)
  Future<Either<Failure, bool>> setPhotoLivDepart({
    required int idOrdre,
    required List<String> photosBase64,
  }) async {
    await _spoolerService.enqueue(
      method: 'POST',
      endpoint: YpsiumOperationEndpoints.setPhotoLivDepart(idOrdre, _token),
      body: {'tabBufPhoto': photosBase64},
      label: 'Photos livraison — Ordre #$idOrdre',
    );
    return const Right(true);
  }

  /// Valide la livraison d'un point — via spooler (optimiste)
  Future<Either<Failure, bool>> setPointLivre({
    required int idOrdre,
    required YpsiumSetPointEnleveRequest request,
  }) async {
    await _spoolerService.enqueue(
      method: 'POST',
      endpoint: YpsiumOperationEndpoints.setPointLivre(idOrdre, _token),
      body: request.toJson(),
      label: 'Validation livraison — Ordre #$idOrdre',
    );
    return const Right(true);
  }

  /// Envoie la position GPS — via spooler (optimiste)
  Future<Either<Failure, bool>> setPositionGPS(
    YpsiumGpsRequest request,
  ) async {
    await _spoolerService.enqueue(
      method: 'POST',
      endpoint: YpsiumGpsEndpoints.setPositionGPS,
      body: request.toJson(),
      label: 'Position GPS',
    );
    return const Right(true);
  }

  String _todayFormatted() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

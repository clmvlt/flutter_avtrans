import 'package:dartz/dartz.dart';

import '../../core/constants/ypsium_api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/ypsium_models.dart';
import '../services/ypsium_http_service.dart';
import 'ypsium_auth_repository.dart';

/// Repository pour les données de référence Ypsium
class YpsiumReferentielRepository {
  final YpsiumHttpService _httpService;
  final YpsiumAuthRepository _authRepository;

  YpsiumReferentielData? _cachedData;

  YpsiumReferentielRepository({
    required YpsiumHttpService httpService,
    required YpsiumAuthRepository authRepository,
  })  : _httpService = httpService,
        _authRepository = authRepository;

  String get _token => _authRepository.sessionToken!;

  /// Récupère le cache des données de référence
  YpsiumReferentielData? get cachedData => _cachedData;

  /// Charge toutes les données de référence en parallèle
  Future<Either<Failure, YpsiumReferentielData>> loadAll() async {
    try {
      final results = await Future.wait([
        _getCodeAnomalie(),
        _getListeClient(),
        _getListeArticleReferenciel(),
        _getListeEntreposage(),
        _getListeEmplacement(),
        _getListeEDI(),
        _getListeTypeReglementCR(),
      ]);

      _cachedData = YpsiumReferentielData(
        anomalies: results[0] as List<YpsiumAnomalie>,
        clients: results[1] as List<YpsiumClient>,
        articles: results[2] as List<YpsiumArticle>,
        entreposages: results[3] as List<YpsiumEntreposage>,
        emplacements: results[4] as List<YpsiumEmplacement>,
        edis: results[5] as List<YpsiumEDI>,
        typesReglement: results[6] as List<YpsiumTypeReglement>,
      );

      return Right(_cachedData!);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  Future<List<YpsiumAnomalie>> _getCodeAnomalie() async {
    final response = await _httpService.get(
      YpsiumReferentielEndpoints.getCodeAnomalie(_token),
    );
    final data = response as Map<String, dynamic>;
    final list = (data['liste'] as List<dynamic>?) ?? [];
    return list
        .map((e) => YpsiumAnomalie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<YpsiumClient>> _getListeClient() async {
    final response = await _httpService.get(
      YpsiumReferentielEndpoints.getListeClient(_token),
    );
    final data = response as Map<String, dynamic>;
    final list = (data['clients'] as List<dynamic>?) ?? [];
    return list
        .map((e) => YpsiumClient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<YpsiumArticle>> _getListeArticleReferenciel() async {
    final response = await _httpService.get(
      YpsiumReferentielEndpoints.getListeArticleReferenciel(_token),
    );
    final data = response as Map<String, dynamic>;
    final list = (data['data'] as List<dynamic>?) ?? [];
    return list
        .map((e) => YpsiumArticle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<YpsiumEntreposage>> _getListeEntreposage() async {
    final response = await _httpService.get(
      YpsiumReferentielEndpoints.getListeEntreposage(_token),
    );
    final data = response as Map<String, dynamic>;
    final list = (data['lieux'] as List<dynamic>?) ?? [];
    return list
        .map((e) => YpsiumEntreposage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<YpsiumEmplacement>> _getListeEmplacement() async {
    final response = await _httpService.get(
      YpsiumReferentielEndpoints.getListeEmplacement(_token),
    );
    final data = response as Map<String, dynamic>;
    final list = (data['emplacements'] as List<dynamic>?) ?? [];
    return list
        .map((e) => YpsiumEmplacement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<YpsiumEDI>> _getListeEDI() async {
    final response = await _httpService.get(
      YpsiumStockageEndpoints.getListeEDI(_token),
    );
    // Cette route retourne directement un tableau
    if (response is List) {
      return response
          .map((e) => YpsiumEDI.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<YpsiumTypeReglement>> _getListeTypeReglementCR() async {
    final response = await _httpService.get(
      YpsiumReferentielEndpoints.getListeTypeReglementCR,
    );
    final data = response as Map<String, dynamic>;
    final list = (data['data'] as List<dynamic>?) ?? [];
    return list
        .map((e) => YpsiumTypeReglement.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

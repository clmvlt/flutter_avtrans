import 'package:dartz/dartz.dart';

import '../../core/constants/ors_api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/address_suggestion.dart';
import '../services/ors_http_service.dart';

/// Interface du repository de geocoding d'adresses.
abstract class IGeocodingRepository {
  /// Recherche des adresses correspondant au texte [query].
  ///
  /// L'autocomplétion s'applique au dernier mot. Si une position de référence
  /// ([originLat]/[originLon]) est fournie, elle est transmise à l'API (`lat`/
  /// `lon`) : le serveur biaise les résultats par proximité (le plus proche
  /// d'abord) et renvoie la distance de chaque adresse (`distanceMeters`). Les
  /// deux coordonnées partent ensemble ou pas du tout. Résultats déjà triés par
  /// le serveur — on les affiche dans l'ordre reçu.
  Future<Either<Failure, List<AddressSuggestion>>> search(
    String query, {
    int limit,
    double? originLat,
    double? originLon,
  });
}

/// Implémentation s'appuyant sur l'API publique ORS.
class GeocodingRepository implements IGeocodingRepository {
  final OrsHttpService _httpService;

  GeocodingRepository(this._httpService);

  @override
  Future<Either<Failure, List<AddressSuggestion>>> search(
    String query, {
    int limit = 10,
    double? originLat,
    double? originLon,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const Right([]);

    final params = <String, String>{
      'q': trimmed,
      'limit': limit.clamp(1, 50).toString(),
    };

    // `lat`/`lon` : envoyés ENSEMBLE et seulement dans les bornes WGS84 (sinon
    // l'API renverrait 400). Sinon recherche purement textuelle.
    if (originLat != null &&
        originLon != null &&
        originLat >= -90 &&
        originLat <= 90 &&
        originLon >= -180 &&
        originLon <= 180) {
      params['lat'] = originLat.toString();
      params['lon'] = originLon.toString();
    }

    try {
      final response = await _httpService.get(
        OrsEndpoints.geocodingSearch,
        queryParameters: params,
      );

      if (response is! List) return const Right([]);

      final suggestions = response
          .whereType<Map<String, dynamic>>()
          .map(AddressSuggestion.fromJson)
          .toList();

      return Right(suggestions);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      // 400 = paramètres invalides (position incohérente/hors bornes) ;
      // 503 = index d'adresses indisponible (message déjà posé en amont).
      if (e.statusCode == 400) {
        return const Left(ServerFailure(
          message: 'Recherche invalide. Réessaie sans la position.',
          statusCode: 400,
        ));
      }
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }
}

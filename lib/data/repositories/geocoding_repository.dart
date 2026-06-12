import 'dart:math' as math;

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
  /// L'autocomplétion s'applique au dernier mot. Si la position de l'utilisateur
  /// ([originLat]/[originLon]) est fournie, les résultats sont reclassés en
  /// combinant le score ORS et la proximité géographique (les plus pertinents
  /// ET proches d'abord). Sinon, on conserve l'ordre par score décroissant.
  /// Peut être vide.
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

  // Pondération du classement final (somme = 1) : on cherche le juste milieu
  // entre la pertinence textuelle (score ORS) et la proximité géographique.
  static const double _scoreWeight = 0.5;
  static const double _proximityWeight = 0.5;

  // Distance caractéristique de décroissance de la proximité (km) : à cette
  // distance, le facteur de proximité vaut ~0.37 ; au-delà il chute vite.
  static const double _proximityTauKm = 20;

  @override
  Future<Either<Failure, List<AddressSuggestion>>> search(
    String query, {
    int limit = 10,
    double? originLat,
    double? originLon,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const Right([]);

    try {
      final response = await _httpService.get(
        OrsEndpoints.geocodingSearch,
        queryParameters: {
          'q': trimmed,
          'limit': limit.clamp(1, 50).toString(),
        },
      );

      if (response is! List) return const Right([]);

      final suggestions = response
          .whereType<Map<String, dynamic>>()
          .map(AddressSuggestion.fromJson)
          .toList();

      final ranked = (originLat != null && originLon != null)
          ? _rankByRelevanceAndProximity(suggestions, originLat, originLon)
          : suggestions;

      return Right(ranked);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  /// Reclasse les suggestions en combinant score ORS (normalisé) et proximité.
  List<AddressSuggestion> _rankByRelevanceAndProximity(
    List<AddressSuggestion> suggestions,
    double originLat,
    double originLon,
  ) {
    if (suggestions.isEmpty) return suggestions;

    // Attache la distance à chaque suggestion.
    final withDistance = suggestions
        .map((s) => s.withDistance(
              _haversineMeters(originLat, originLon, s.lat, s.lon),
            ))
        .toList();

    final maxScore = withDistance
        .map((s) => s.score ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);

    double relevance(AddressSuggestion s) {
      final scoreNorm = maxScore > 0 ? (s.score ?? 0) / maxScore : 0.0;
      final distanceKm = (s.distanceMeters ?? 0) / 1000;
      final proximityNorm = math.exp(-distanceKm / _proximityTauKm);
      return _scoreWeight * scoreNorm + _proximityWeight * proximityNorm;
    }

    withDistance.sort((a, b) {
      final byRelevance = relevance(b).compareTo(relevance(a));
      if (byRelevance != 0) return byRelevance;
      // Égalité → le plus proche d'abord.
      return (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0);
    });

    return withDistance;
  }

  /// Distance du grand cercle (Haversine) en mètres — pur Dart, sans plugin.
  double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // mètres
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}

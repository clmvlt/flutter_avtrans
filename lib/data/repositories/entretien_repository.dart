import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/entretien_model.dart';
import '../models/paginated_response.dart';
import '../services/http_service.dart';

/// Interface du repository de l'atelier : entretiens, fichiers, échéances,
/// types, dossiers et suivis périodiques par véhicule.
abstract class IEntretienRepository {
  /// Échéances de toute la flotte.
  Future<Either<Failure, List<VehiculeProchainEntretien>>> getFleetUpcoming();

  /// Échéances d'un véhicule (`null` si aucun suivi).
  Future<Either<Failure, VehiculeProchainEntretien?>> getVehiculeUpcoming(
    String vehiculeId,
  );

  /// Historique filtré et paginé.
  Future<Either<Failure, PaginatedResponse<Entretien>>> searchHistory(
    EntretienHistoryQuery query,
  );

  Future<Either<Failure, Entretien>> createEntretien(
    EntretienCreateRequest request,
  );

  Future<Either<Failure, Entretien>> updateEntretien(
    String id,
    EntretienUpdateRequest request,
  );

  Future<Either<Failure, void>> deleteEntretien(String id);

  /// Fichiers d'un entretien, contenu base64 compris.
  Future<Either<Failure, List<EntretienFile>>> getFiles(String entretienId);

  Future<Either<Failure, EntretienFile>> addFile(
    String entretienId,
    EntretienFileUpload file,
  );

  Future<Either<Failure, void>> deleteFile(String fileId);

  Future<Either<Failure, List<TypeEntretien>>> getTypes();

  Future<Either<Failure, TypeEntretien>> createType(
    TypeEntretienRequest request,
  );

  Future<Either<Failure, TypeEntretien>> updateType(
    String id,
    TypeEntretienRequest request,
  );

  Future<Either<Failure, void>> deleteType(String id);

  Future<Either<Failure, List<DossierTypeEntretien>>> getDossiers();

  Future<Either<Failure, DossierTypeEntretien>> createDossier(
    DossierTypeEntretienRequest request,
  );

  Future<Either<Failure, DossierTypeEntretien>> updateDossier(
    String id,
    DossierTypeEntretienRequest request,
  );

  Future<Either<Failure, void>> deleteDossier(String id);

  /// Suivis périodiques d'un véhicule (actifs et inactifs).
  Future<Either<Failure, List<VehiculeTypeEntretien>>> getVehiculeConfigs(
    String vehiculeId,
  );

  Future<Either<Failure, VehiculeTypeEntretien>> createVehiculeConfig(
    VehiculeTypeEntretienCreateRequest request,
  );

  Future<Either<Failure, VehiculeTypeEntretien>> updateVehiculeConfig(
    String id,
    VehiculeTypeEntretienUpdateRequest request,
  );

  Future<Either<Failure, void>> deleteVehiculeConfig(String id);
}

/// Implémentation HTTP. Les formes de réponse varient selon la route
/// (`data`, `entretien`, `typesEntretien`, `dossiers`…) : chaque méthode lit
/// la clé que renvoie son contrôleur.
class EntretienRepository implements IEntretienRepository {
  final HttpService _http;

  EntretienRepository(this._http);

  /// Exécute un appel et convertit les exceptions en [Failure] typées.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(message: e.message, errors: e.errors));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on UnauthorizedException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on TypeError {
      return const Left(
        ServerFailure(message: 'Réponse inattendue du serveur.'),
      );
    } on FormatException {
      return const Left(
        ServerFailure(message: 'Réponse inattendue du serveur.'),
      );
    }
  }

  static Map<String, dynamic> _object(dynamic response, List<String> keys) {
    if (response is Map) {
      for (final k in keys) {
        final v = response[k];
        if (v is Map<String, dynamic>) return v;
      }
    }
    throw const ServerException(message: 'Réponse inattendue du serveur.');
  }

  static List<Map<String, dynamic>> _list(dynamic response, List<String> keys) {
    if (response is List) return response.whereType<Map<String, dynamic>>().toList();
    if (response is Map) {
      for (final k in keys) {
        final v = response[k];
        if (v is List) return v.whereType<Map<String, dynamic>>().toList();
      }
    }
    return const [];
  }

  // ---- échéances --------------------------------------------------------

  @override
  Future<Either<Failure, List<VehiculeProchainEntretien>>> getFleetUpcoming() =>
      _guard(() async {
        final res = await _http.get(EntretienEndpoints.fleetUpcoming);
        return _list(res, const ['data'])
            .map(VehiculeProchainEntretien.fromJson)
            .toList();
      });

  @override
  Future<Either<Failure, VehiculeProchainEntretien?>> getVehiculeUpcoming(
    String vehiculeId,
  ) =>
      _guard(() async {
        final res =
            await _http.get(EntretienEndpoints.vehiculeUpcoming(vehiculeId));
        final data = res is Map ? res['data'] : null;
        return data is Map<String, dynamic>
            ? VehiculeProchainEntretien.fromJson(data)
            : null;
      });

  // ---- entretiens -------------------------------------------------------

  @override
  Future<Either<Failure, PaginatedResponse<Entretien>>> searchHistory(
    EntretienHistoryQuery query,
  ) =>
      _guard(() async {
        final res = await _http.post(
          EntretienEndpoints.history,
          body: query.toJson(),
        );
        if (res is! Map<String, dynamic>) {
          throw const ServerException(message: 'Réponse inattendue du serveur.');
        }
        return PaginatedResponse.fromJson(res, Entretien.fromJson);
      });

  @override
  Future<Either<Failure, Entretien>> createEntretien(
    EntretienCreateRequest request,
  ) =>
      _guard(() async {
        final res = await _http.post(
          EntretienEndpoints.create,
          body: request.toJson(),
        );
        return Entretien.fromJson(_object(res, const ['entretien']));
      });

  @override
  Future<Either<Failure, Entretien>> updateEntretien(
    String id,
    EntretienUpdateRequest request,
  ) =>
      _guard(() async {
        final res = await _http.put(
          EntretienEndpoints.byId(id),
          body: request.toJson(),
        );
        return Entretien.fromJson(_object(res, const ['entretien']));
      });

  @override
  Future<Either<Failure, void>> deleteEntretien(String id) =>
      _guard(() => _http.delete(EntretienEndpoints.byId(id)));

  // ---- fichiers ---------------------------------------------------------

  @override
  Future<Either<Failure, List<EntretienFile>>> getFiles(String entretienId) =>
      _guard(() async {
        final res = await _http.get(EntretienEndpoints.files(entretienId));
        return _list(res, const ['files'])
            .where((f) => f['id'] != null)
            .map(EntretienFile.fromJson)
            .toList();
      });

  @override
  Future<Either<Failure, EntretienFile>> addFile(
    String entretienId,
    EntretienFileUpload file,
  ) =>
      _guard(() async {
        final res = await _http.post(
          EntretienEndpoints.files(entretienId),
          body: file.toJson(),
        );
        return EntretienFile.fromJson(_object(res, const ['file']));
      });

  @override
  Future<Either<Failure, void>> deleteFile(String fileId) =>
      _guard(() => _http.delete(EntretienEndpoints.deleteFile(fileId)));

  // ---- types ------------------------------------------------------------

  @override
  Future<Either<Failure, List<TypeEntretien>>> getTypes() => _guard(() async {
        final res = await _http.get(TypeEntretienEndpoints.all);
        final types = _list(res, const ['typesEntretien', 'data'])
            .map(TypeEntretien.fromJson)
            .toList();
        types.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
        return types;
      });

  @override
  Future<Either<Failure, TypeEntretien>> createType(
    TypeEntretienRequest request,
  ) =>
      _guard(() async {
        final res = await _http.post(
          TypeEntretienEndpoints.all,
          body: request.toJson(),
        );
        return TypeEntretien.fromJson(
          _object(res, const ['typeEntretien', 'data']),
        );
      });

  @override
  Future<Either<Failure, TypeEntretien>> updateType(
    String id,
    TypeEntretienRequest request,
  ) =>
      _guard(() async {
        final res = await _http.put(
          TypeEntretienEndpoints.byId(id),
          body: request.toJson(),
        );
        return TypeEntretien.fromJson(
          _object(res, const ['typeEntretien', 'data']),
        );
      });

  @override
  Future<Either<Failure, void>> deleteType(String id) =>
      _guard(() => _http.delete(TypeEntretienEndpoints.byId(id)));

  // ---- dossiers ---------------------------------------------------------

  @override
  Future<Either<Failure, List<DossierTypeEntretien>>> getDossiers() =>
      _guard(() async {
        final res = await _http.get(DossierTypeEntretienEndpoints.all);
        final dossiers = _list(res, const ['dossiers', 'data'])
            .map(DossierTypeEntretien.fromJson)
            .toList();
        dossiers
            .sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
        return dossiers;
      });

  @override
  Future<Either<Failure, DossierTypeEntretien>> createDossier(
    DossierTypeEntretienRequest request,
  ) =>
      _guard(() async {
        final res = await _http.post(
          DossierTypeEntretienEndpoints.all,
          body: request.toJson(),
        );
        return DossierTypeEntretien.fromJson(_object(res, const ['dossier']));
      });

  @override
  Future<Either<Failure, DossierTypeEntretien>> updateDossier(
    String id,
    DossierTypeEntretienRequest request,
  ) =>
      _guard(() async {
        final res = await _http.put(
          DossierTypeEntretienEndpoints.byId(id),
          body: request.toJson(),
        );
        return DossierTypeEntretien.fromJson(_object(res, const ['dossier']));
      });

  @override
  Future<Either<Failure, void>> deleteDossier(String id) =>
      _guard(() => _http.delete(DossierTypeEntretienEndpoints.byId(id)));

  // ---- suivis par véhicule ---------------------------------------------

  @override
  Future<Either<Failure, List<VehiculeTypeEntretien>>> getVehiculeConfigs(
    String vehiculeId,
  ) =>
      _guard(() async {
        final res = await _http
            .get(VehiculeTypeEntretienEndpoints.byVehicule(vehiculeId));
        return _list(res, const ['vehiculeTypesEntretien', 'data'])
            .map(VehiculeTypeEntretien.fromJson)
            .toList();
      });

  @override
  Future<Either<Failure, VehiculeTypeEntretien>> createVehiculeConfig(
    VehiculeTypeEntretienCreateRequest request,
  ) =>
      _guard(() async {
        final res = await _http.post(
          VehiculeTypeEntretienEndpoints.create,
          body: request.toJson(),
        );
        return VehiculeTypeEntretien.fromJson(
          _object(res, const ['vehiculeTypeEntretien', 'data']),
        );
      });

  @override
  Future<Either<Failure, VehiculeTypeEntretien>> updateVehiculeConfig(
    String id,
    VehiculeTypeEntretienUpdateRequest request,
  ) =>
      _guard(() async {
        final res = await _http.put(
          VehiculeTypeEntretienEndpoints.byId(id),
          body: request.toJson(),
        );
        return VehiculeTypeEntretien.fromJson(
          _object(res, const ['vehiculeTypeEntretien', 'data']),
        );
      });

  @override
  Future<Either<Failure, void>> deleteVehiculeConfig(String id) =>
      _guard(() => _http.delete(VehiculeTypeEntretienEndpoints.byId(id)));
}

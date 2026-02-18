import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/vehicule_model.dart';
import '../services/http_service.dart';

/// Interface du repository des véhicules
abstract class IVehiculeRepository {
  /// Récupère tous les véhicules
  Future<Either<Failure, List<Vehicule>>> getAllVehicules();

  /// Récupère un véhicule par ID
  Future<Either<Failure, Vehicule>> getVehiculeById(String id);

  /// Récupère le dernier kilométrage de l'utilisateur connecté
  Future<Either<Failure, LastKilometrageResponse>> getMyLastKilometrage();

  /// Ajoute un kilométrage
  Future<Either<Failure, Kilometrage>> addKilometrage(
    AddKilometrageRequest request,
  );

  /// Crée une information d'ajustement
  Future<Either<Failure, AdjustInfo>> createAdjustInfo(
    CreateAdjustInfoRequest request,
  );

  /// Récupère l'historique des kilométrages d'un véhicule
  Future<Either<Failure, List<Kilometrage>>> getKilometrages(String vehiculeId);

  /// Récupère les informations d'ajustement d'un véhicule
  Future<Either<Failure, List<AdjustInfo>>> getAdjustInfos(String vehiculeId);

  /// Récupère les photos d'une information d'ajustement
  Future<Either<Failure, List<AdjustPicture>>> getAdjustInfoPictures(
    String adjustInfoId,
  );

  /// Récupère les fichiers d'un véhicule
  Future<Either<Failure, List<VehiculeFile>>> getVehiculeFiles(
    String vehiculeId,
  );

  /// Uploade un fichier pour un véhicule
  Future<Either<Failure, VehiculeFile>> uploadVehiculeFile(
    String vehiculeId,
    UploadVehiculeFileRequest request,
  );

  /// Supprime un fichier de véhicule
  Future<Either<Failure, void>> deleteVehiculeFile(String fileId);
}

/// Implémentation du repository des véhicules
class VehiculeRepository implements IVehiculeRepository {
  final HttpService _httpService;

  VehiculeRepository({
    required HttpService httpService,
  }) : _httpService = httpService;

  @override
  Future<Either<Failure, List<Vehicule>>> getAllVehicules() async {
    try {
      final response = await _httpService.get(VehiculeEndpoints.all);

      if (response is Map && response['vehicules'] != null) {
        final vehiculesJson = response['vehicules'] as List<dynamic>;
        final vehicules = vehiculesJson
            .map((json) => Vehicule.fromJson(json as Map<String, dynamic>))
            .toList();
        return Right(vehicules);
      }

      return const Right([]);
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
  Future<Either<Failure, Vehicule>> getVehiculeById(String id) async {
    try {
      final response = await _httpService.get(VehiculeEndpoints.byId(id));

      if (response is Map && response['vehicule'] != null) {
        return Right(Vehicule.fromJson(response['vehicule'] as Map<String, dynamic>));
      }

      throw const ServerException(message: 'Format de réponse invalide');
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
  Future<Either<Failure, LastKilometrageResponse>> getMyLastKilometrage() async {
    try {
      final response = await _httpService.get(UserEndpoints.myKilometrage);

      if (response is Map) {
        return Right(LastKilometrageResponse.fromJson(
          response as Map<String, dynamic>,
        ));
      }

      throw const ServerException(message: 'Format de réponse invalide');
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
  Future<Either<Failure, Kilometrage>> addKilometrage(
    AddKilometrageRequest request,
  ) async {
    try {
      final response = await _httpService.post(
        VehiculeEndpoints.addKilometrage,
        body: request.toJson(),
      );

      if (response is Map && response['kilometrage'] != null) {
        return Right(Kilometrage.fromJson(
          response['kilometrage'] as Map<String, dynamic>,
        ));
      }

      throw ServerException(message: 'Format de réponse invalide: $response');
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
  Future<Either<Failure, AdjustInfo>> createAdjustInfo(
    CreateAdjustInfoRequest request,
  ) async {
    try {
      final response = await _httpService.post(
        VehiculeEndpoints.createAdjustInfo,
        body: request.toJson(),
      );

      if (response is Map && response['adjustInfo'] != null) {
        return Right(AdjustInfo.fromJson(
          response['adjustInfo'] as Map<String, dynamic>,
        ));
      }

      throw const ServerException(message: 'Format de réponse invalide');
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
  Future<Either<Failure, List<Kilometrage>>> getKilometrages(
    String vehiculeId,
  ) async {
    try {
      final response = await _httpService.get(
        VehiculeEndpoints.kilometrages(vehiculeId),
      );

      if (response is Map && response['kilometrages'] != null) {
        final kilometragesJson = response['kilometrages'] as List<dynamic>;
        final kilometrages = kilometragesJson
            .map((json) => Kilometrage.fromJson(json as Map<String, dynamic>))
            .toList();
        return Right(kilometrages);
      }

      return const Right([]);
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
  Future<Either<Failure, List<AdjustInfo>>> getAdjustInfos(
    String vehiculeId,
  ) async {
    try {
      final response = await _httpService.get(
        VehiculeEndpoints.adjustInfos(vehiculeId),
      );

      if (response is Map && response['adjustInfos'] != null) {
        final adjustInfosJson = response['adjustInfos'] as List<dynamic>;
        final adjustInfos = adjustInfosJson
            .map((json) => AdjustInfo.fromJson(json as Map<String, dynamic>))
            .toList();
        return Right(adjustInfos);
      }

      return const Right([]);
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
  Future<Either<Failure, List<AdjustPicture>>> getAdjustInfoPictures(
    String adjustInfoId,
  ) async {
    try {
      final response = await _httpService.get(
        VehiculeEndpoints.adjustInfoPictures(adjustInfoId),
      );

      if (response is Map && response['pictures'] != null) {
        final picturesJson = response['pictures'] as List<dynamic>;
        final pictures = picturesJson
            .map((json) => AdjustPicture.fromJson(json as Map<String, dynamic>))
            .toList();
        return Right(pictures);
      }

      return const Right([]);
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
  Future<Either<Failure, List<VehiculeFile>>> getVehiculeFiles(
    String vehiculeId,
  ) async {
    try {
      final response = await _httpService.get(
        VehiculeEndpoints.files(vehiculeId),
      );

      if (response is Map && response['files'] != null) {
        final filesJson = response['files'] as List<dynamic>;
        final files = filesJson
            .map((json) => VehiculeFile.fromJson(json as Map<String, dynamic>))
            .toList();
        return Right(files);
      }

      return const Right([]);
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
  Future<Either<Failure, VehiculeFile>> uploadVehiculeFile(
    String vehiculeId,
    UploadVehiculeFileRequest request,
  ) async {
    try {
      final response = await _httpService.post(
        VehiculeEndpoints.uploadFile(vehiculeId),
        body: request.toJson(),
      );

      if (response is Map && response['file'] != null) {
        return Right(VehiculeFile.fromJson(
          response['file'] as Map<String, dynamic>,
        ));
      }

      throw const ServerException(message: 'Format de réponse invalide');
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
  Future<Either<Failure, void>> deleteVehiculeFile(String fileId) async {
    try {
      await _httpService.delete(VehiculeEndpoints.deleteFile(fileId));
      return const Right(null);
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
}

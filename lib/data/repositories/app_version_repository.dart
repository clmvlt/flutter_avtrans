import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/app_version_model.dart';
import '../models/update_check_response.dart';
import '../services/download_service.dart';
import '../services/http_service.dart';

/// Interface du repository des versions d'application
abstract class IAppVersionRepository {
  Future<Either<Failure, List<AppVersion>>> getAllVersions();
  Future<Either<Failure, AppVersion>> getLatestVersion();
  Future<Either<Failure, UpdateCheckResponse>> checkForUpdate(
      int currentVersionCode);
  Future<Either<Failure, String>> downloadApk(
    String versionId,
    String fileName,
    void Function(double progress)? onProgress,
  );
}

/// Implémentation du repository des versions d'application
class AppVersionRepository implements IAppVersionRepository {
  final HttpService _httpService;
  final DownloadService _downloadService;

  AppVersionRepository({
    required HttpService httpService,
    required DownloadService downloadService,
  })  : _httpService = httpService,
        _downloadService = downloadService;

  @override
  Future<Either<Failure, List<AppVersion>>> getAllVersions() async {
    try {
      final response = await _httpService.get(AppVersionEndpoints.all);
      final Map<String, dynamic> data = response as Map<String, dynamic>;
      final List<dynamic> versionsJson = data['versions'] as List<dynamic>;
      final versions = versionsJson
          .map((json) => AppVersion.fromJson(json as Map<String, dynamic>))
          .toList();
      return Right(versions);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, AppVersion>> getLatestVersion() async {
    try {
      final response = await _httpService.get(AppVersionEndpoints.latest);
      final Map<String, dynamic> data = response as Map<String, dynamic>;
      return Right(
          AppVersion.fromJson(data['version'] as Map<String, dynamic>));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, UpdateCheckResponse>> checkForUpdate(
      int currentVersionCode) async {
    try {
      final response = await _httpService.get(
        AppVersionEndpoints.check,
        queryParameters: {'currentVersion': currentVersionCode.toString()},
      );
      return Right(
          UpdateCheckResponse.fromJson(response as Map<String, dynamic>));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, String>> downloadApk(
    String versionId,
    String fileName,
    void Function(double progress)? onProgress,
  ) async {
    try {
      final file = await _downloadService.downloadFile(
        url: AppVersionEndpoints.download(versionId),
        fileName: fileName,
        onProgress: onProgress,
      );
      return Right(file.path);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'Erreur de téléchargement: $e'));
    }
  }
}

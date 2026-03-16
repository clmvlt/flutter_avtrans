import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/models.dart';
import '../services/http_service.dart';

/// Interface du repository des notifications
abstract class INotificationRepository {
  Future<Either<Failure, List<AppNotification>>> getAllNotifications();
  Future<Either<Failure, List<AppNotification>>> getUnreadNotifications();
  Future<Either<Failure, List<AppNotification>>> getReadNotifications();
  Future<Either<Failure, int>> getUnreadCount();
  Future<Either<Failure, AppNotification>> getNotification(String uuid);
  Future<Either<Failure, AppNotification>> markAsRead(String uuid);
  Future<Either<Failure, bool>> markAllAsRead();
  Future<Either<Failure, NotificationPreferences>> getNotificationPreferences();
  Future<Either<Failure, NotificationPreferences>> updateNotificationPreferences(
      NotificationPreferences preferences);
}

/// Implémentation du repository des notifications
class NotificationRepository implements INotificationRepository {
  final HttpService _httpService;

  NotificationRepository(this._httpService);

  @override
  Future<Either<Failure, List<AppNotification>>> getAllNotifications() async {
    try {
      final response = await _httpService.get(NotificationEndpoints.all);
      final notifications = (response['notifications'] as List)
          .map((json) =>
              AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
      return Right(notifications);
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
  Future<Either<Failure, List<AppNotification>>>
      getUnreadNotifications() async {
    try {
      final response = await _httpService.get(NotificationEndpoints.unread);
      final notifications = (response['notifications'] as List)
          .map((json) =>
              AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
      return Right(notifications);
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
  Future<Either<Failure, List<AppNotification>>> getReadNotifications() async {
    try {
      final response = await _httpService.get(NotificationEndpoints.read);
      final notifications = (response['notifications'] as List)
          .map((json) =>
              AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
      return Right(notifications);
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
  Future<Either<Failure, int>> getUnreadCount() async {
    try {
      final response =
          await _httpService.get(NotificationEndpoints.unreadCount);
      final count = response['count'] as int? ?? 0;
      return Right(count);
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
  Future<Either<Failure, AppNotification>> getNotification(
      String uuid) async {
    try {
      final response =
          await _httpService.get(NotificationEndpoints.byUuid(uuid));
      final notification = AppNotification.fromJson(
          response['notification'] as Map<String, dynamic>);
      return Right(notification);
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
  Future<Either<Failure, AppNotification>> markAsRead(String uuid) async {
    try {
      final response =
          await _httpService.patch(NotificationEndpoints.markRead(uuid));
      final notification = AppNotification.fromJson(
          response['notification'] as Map<String, dynamic>);
      return Right(notification);
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
  Future<Either<Failure, bool>> markAllAsRead() async {
    try {
      await _httpService.patch(NotificationEndpoints.readAll);
      return const Right(true);
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
  Future<Either<Failure, NotificationPreferences>>
      getNotificationPreferences() async {
    try {
      final response =
          await _httpService.get(UserEndpoints.notificationPreferences);
      final prefs = NotificationPreferences.fromJson(response);
      return Right(prefs);
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
  Future<Either<Failure, NotificationPreferences>>
      updateNotificationPreferences(
          NotificationPreferences preferences) async {
    try {
      final response = await _httpService.put(
        UserEndpoints.updateNotificationPreferences,
        body: preferences.toJson(),
      );
      final prefs = NotificationPreferences.fromJson(response);
      return Right(prefs);
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

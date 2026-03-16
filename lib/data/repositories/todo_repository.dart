import 'package:dartz/dartz.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../models/models.dart';
import '../services/http_service.dart';

/// Interface du repository des todos
abstract class ITodoRepository {
  Future<Either<Failure, Todo>> createTodo(TodoCreateRequest request);
  Future<Either<Failure, Todo>> updateTodo(String uuid, TodoUpdateRequest request);
  Future<Either<Failure, Todo>> toggleTodo(String uuid);
  Future<Either<Failure, bool>> deleteTodo(String uuid);
  Future<Either<Failure, Todo>> getTodo(String uuid);
  Future<Either<Failure, PaginatedResponse<Todo>>> searchTodos(TodoSearchParams params);
  Future<Either<Failure, List<TodoCategory>>> getCategories();
  Future<Either<Failure, TodoCategory>> createCategory(TodoCategoryCreateRequest request);
  Future<Either<Failure, TodoCategory>> updateCategory(String uuid, TodoCategoryCreateRequest request);
  Future<Either<Failure, bool>> deleteCategory(String uuid);
}

/// Implémentation du repository des todos
class TodoRepository implements ITodoRepository {
  final HttpService _httpService;

  TodoRepository(this._httpService);

  @override
  Future<Either<Failure, Todo>> createTodo(TodoCreateRequest request) async {
    try {
      final response = await _httpService.post(
        TodoEndpoints.create,
        body: request.toJson(),
      );
      final todo = Todo.fromJson(response['todo'] as Map<String, dynamic>);
      return Right(todo);
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
  Future<Either<Failure, Todo>> updateTodo(
      String uuid, TodoUpdateRequest request) async {
    try {
      final response = await _httpService.put(
        TodoEndpoints.update(uuid),
        body: request.toJson(),
      );
      final todo = Todo.fromJson(response['todo'] as Map<String, dynamic>);
      return Right(todo);
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
  Future<Either<Failure, Todo>> toggleTodo(String uuid) async {
    try {
      final response = await _httpService.post(
        TodoEndpoints.toggle(uuid),
      );
      final todo = Todo.fromJson(response['todo'] as Map<String, dynamic>);
      return Right(todo);
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
  Future<Either<Failure, bool>> deleteTodo(String uuid) async {
    try {
      await _httpService.delete(TodoEndpoints.delete(uuid));
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
  Future<Either<Failure, Todo>> getTodo(String uuid) async {
    try {
      final response = await _httpService.get(TodoEndpoints.byUuid(uuid));
      final todo = Todo.fromJson(response['todo'] as Map<String, dynamic>);
      return Right(todo);
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
  Future<Either<Failure, PaginatedResponse<Todo>>> searchTodos(
      TodoSearchParams params) async {
    try {
      final response = await _httpService.post(
        TodoEndpoints.search,
        body: params.toJson(),
      );

      final todos = (response['todos'] as List)
          .map((json) => Todo.fromJson(json as Map<String, dynamic>))
          .toList();

      final paginatedResponse = PaginatedResponse<Todo>(
        success: true,
        content: todos,
        page: response['currentPage'] as int? ?? params.page ?? 0,
        totalPages: response['totalPages'] as int? ?? 1,
        totalElements: response['totalElements'] as int? ?? todos.length,
        last: (response['currentPage'] as int? ?? params.page ?? 0) >=
            ((response['totalPages'] as int? ?? 1) - 1),
        first: (params.page ?? 0) == 0,
        size: params.size ?? 10,
      );

      return Right(paginatedResponse);
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
  Future<Either<Failure, List<TodoCategory>>> getCategories() async {
    try {
      final response = await _httpService.get(TodoCategoryEndpoints.all);
      final categories = (response['categories'] as List)
          .map((json) => TodoCategory.fromJson(json as Map<String, dynamic>))
          .toList();
      return Right(categories);
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
  Future<Either<Failure, TodoCategory>> createCategory(
      TodoCategoryCreateRequest request) async {
    try {
      final response = await _httpService.post(
        TodoCategoryEndpoints.create,
        body: request.toJson(),
      );
      final category =
          TodoCategory.fromJson(response['category'] as Map<String, dynamic>);
      return Right(category);
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
  Future<Either<Failure, TodoCategory>> updateCategory(
      String uuid, TodoCategoryCreateRequest request) async {
    try {
      final response = await _httpService.put(
        TodoCategoryEndpoints.update(uuid),
        body: request.toJson(),
      );
      final category =
          TodoCategory.fromJson(response['category'] as Map<String, dynamic>);
      return Right(category);
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
  Future<Either<Failure, bool>> deleteCategory(String uuid) async {
    try {
      await _httpService.delete(TodoCategoryEndpoints.delete(uuid));
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
}

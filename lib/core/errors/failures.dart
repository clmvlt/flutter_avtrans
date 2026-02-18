import 'package:equatable/equatable.dart';

/// Classe de base pour les échecs (Failure)
/// Utilisée avec Either<Failure, Success> pour la gestion d'erreurs fonctionnelle
abstract class Failure extends Equatable {
  final String message;

  const Failure({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Échec serveur
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure({
    required super.message,
    this.statusCode,
  });

  @override
  List<Object?> get props => [message, statusCode];
}

/// Échec réseau
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Erreur de connexion. Vérifiez votre connexion internet.',
  });
}

/// Échec d'authentification
class AuthFailure extends Failure {
  const AuthFailure({required super.message});
}

/// Échec de validation
class ValidationFailure extends Failure {
  final Map<String, List<String>>? errors;

  const ValidationFailure({
    required super.message,
    this.errors,
  });

  @override
  List<Object?> get props => [message, errors];
}

/// Échec de cache
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Erreur lors de l\'accès au cache local.',
  });
}

/// Exception de base pour l'application
abstract class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException({
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => message;
}

/// Exception pour les erreurs serveur
class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.statusCode,
  });
}

/// Exception pour les erreurs réseau
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Erreur de connexion. Vérifiez votre connexion internet.',
  });
}

/// Exception pour les erreurs d'authentification
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.statusCode,
  });
}

/// Exception pour les erreurs de validation
class ValidationException extends AppException {
  final Map<String, List<String>>? errors;

  const ValidationException({
    required super.message,
    this.errors,
    super.statusCode,
  });
}

/// Exception pour les tokens invalides ou expirés
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message = 'Session expirée. Veuillez vous reconnecter.',
  }) : super(statusCode: 401);
}

/// Exception pour le cache local
class CacheException extends AppException {
  const CacheException({
    super.message = 'Erreur lors de l\'accès au cache local.',
  });
}

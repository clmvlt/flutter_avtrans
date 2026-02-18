/// Classe générique pour encapsuler les réponses API
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T? Function(Map<String, dynamic>)? fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      data: fromJsonT != null ? fromJsonT(json) : null,
    );
  }

  /// Crée une réponse de succès
  factory ApiResponse.success({
    required String message,
    T? data,
  }) {
    return ApiResponse(
      success: true,
      message: message,
      data: data,
    );
  }

  /// Crée une réponse d'erreur
  factory ApiResponse.error({
    required String message,
  }) {
    return ApiResponse(
      success: false,
      message: message,
    );
  }
}

/// Réponse spécifique pour l'enregistrement
class RegisterResponse {
  final bool success;
  final String message;
  final String? userId;

  const RegisterResponse({
    required this.success,
    required this.message,
    this.userId,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      userId: json['userId'] as String?,
    );
  }
}

/// Réponse pour vérifier le statut d'un utilisateur
class UserStatusResponse {
  final bool isMailVerified;
  final bool isActive;

  const UserStatusResponse({
    required this.isMailVerified,
    required this.isActive,
  });

  factory UserStatusResponse.fromJson(Map<String, dynamic> json) {
    return UserStatusResponse(
      isMailVerified: json['isMailVerified'] as bool,
      isActive: json['isActive'] as bool,
    );
  }
}

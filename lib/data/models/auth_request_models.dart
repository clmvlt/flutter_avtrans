/// Modèle pour la requête d'inscription
class RegisterRequest {
  final String email;
  final String password;
  final String firstName;
  final String lastName;

  const RegisterRequest({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
    };
  }
}

/// Modèle pour la requête de connexion
class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

/// Modèle pour la demande de réinitialisation de mot de passe
class PasswordResetRequest {
  final String email;

  const PasswordResetRequest({
    required this.email,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
    };
  }
}

/// Modèle pour la confirmation de réinitialisation de mot de passe
class PasswordResetConfirmRequest {
  final String token;
  final String newPassword;

  const PasswordResetConfirmRequest({
    required this.token,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'newPassword': newPassword,
    };
  }
}

/// Requête `POST /auth/google` (fiche Google §2) — sans header Authorization.
class GoogleAuthRequest {
  final String idToken;

  const GoogleAuthRequest({required this.idToken});

  Map<String, dynamic> toJson() {
    return {
      'idToken': idToken,
    };
  }
}

/// Requête `POST /auth/google/register` (fiche Google §3).
///
/// `firstName` / `lastName` sont optionnels : vides, l'API reprend les valeurs
/// Google. L'email et l'identifiant Google sont toujours extraits du token,
/// jamais du formulaire.
class GoogleRegisterRequest {
  final String idToken;
  final String? firstName;
  final String? lastName;

  const GoogleRegisterRequest({
    required this.idToken,
    this.firstName,
    this.lastName,
  });

  Map<String, dynamic> toJson() {
    final first = firstName?.trim();
    final last = lastName?.trim();
    return {
      'idToken': idToken,
      if (first != null && first.isNotEmpty) 'firstName': first,
      if (last != null && last.isNotEmpty) 'lastName': last,
    };
  }
}

import 'package:equatable/equatable.dart';

import 'user_model.dart';

/// Statut renvoyé par `POST /auth/google` et `POST /auth/google/register`
/// (fiche d'intégration §2-§3). C'est lui qui pilote la suite du parcours.
enum GoogleAuthStatus {
  /// Compte existant et actif : `user.token` est disponible.
  authenticated('AUTHENTICATED'),

  /// Aucun compte pour cet email : afficher l'inscription pré-remplie puis
  /// appeler `POST /auth/google/register` avec le **même** `idToken`.
  needsRegistration('NEEDS_REGISTRATION'),

  /// Compte créé, en attente d'activation par un administrateur (aucun token).
  pendingActivation('PENDING_ACTIVATION'),

  /// Valeur inconnue du client (évolution de l'API).
  unknown('');

  final String value;

  const GoogleAuthStatus(this.value);

  static GoogleAuthStatus fromValue(String? raw) {
    final normalized = raw?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) return GoogleAuthStatus.unknown;
    return GoogleAuthStatus.values.firstWhere(
      (status) => status.value == normalized,
      orElse: () => GoogleAuthStatus.unknown,
    );
  }
}

/// Profil Google renvoyé avec `NEEDS_REGISTRATION` pour pré-remplir
/// l'inscription (email non modifiable, prénom / nom modifiables).
class GoogleProfile extends Equatable {
  final String email;
  final String firstName;
  final String lastName;
  final String? pictureUrl;

  const GoogleProfile({
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.pictureUrl,
  });

  factory GoogleProfile.fromJson(Map<String, dynamic> json) {
    return GoogleProfile(
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      pictureUrl: json['pictureUrl'] as String?,
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  /// Initiales pour l'avatar de secours (« JD »), sinon 1re lettre de l'email.
  String get initials {
    final letters = [firstName, lastName]
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .join();
    if (letters.isNotEmpty) return letters;
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  @override
  List<Object?> get props => [email, firstName, lastName, pictureUrl];
}

/// Réponse `200` de `POST /auth/google` et `POST /auth/google/register`.
///
/// Les erreurs `400` (`Token Google invalide`, `Le compte n'est pas activé`…)
/// ne passent pas par ici : elles remontent en `Failure` avec le `message`
/// serveur, à afficher tel quel.
class GoogleAuthResponse extends Equatable {
  final bool success;
  final GoogleAuthStatus status;
  final String message;

  /// Rempli uniquement pour [GoogleAuthStatus.authenticated] — même objet que
  /// celui de `POST /auth/login` (avec `token`).
  final User? user;

  /// Rempli uniquement pour [GoogleAuthStatus.needsRegistration].
  final GoogleProfile? googleProfile;

  /// ID token Google utilisé pour cet appel. L'API ne le renvoie pas : le
  /// repository l'attache pour que l'inscription réutilise **le même** token
  /// (valable 1 h).
  final String idToken;

  const GoogleAuthResponse({
    required this.success,
    required this.status,
    required this.message,
    required this.idToken,
    this.user,
    this.googleProfile,
  });

  factory GoogleAuthResponse.fromJson(
    Map<String, dynamic> json, {
    required String idToken,
  }) {
    final rawUser = json['user'];
    final rawProfile = json['googleProfile'];
    return GoogleAuthResponse(
      success: json['success'] as bool? ?? true,
      status: GoogleAuthStatus.fromValue(json['status'] as String?),
      message: json['message'] as String? ?? '',
      user: rawUser is Map<String, dynamic> ? User.fromJson(rawUser) : null,
      googleProfile: rawProfile is Map<String, dynamic>
          ? GoogleProfile.fromJson(rawProfile)
          : null,
      idToken: idToken,
    );
  }

  @override
  List<Object?> get props =>
      [success, status, message, user, googleProfile, idToken];
}

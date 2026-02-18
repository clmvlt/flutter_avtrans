/// Modèle pour la requête de modification du profil
class UpdateProfileRequest {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? picture; // Base64 encoded image

  const UpdateProfileRequest({
    this.firstName,
    this.lastName,
    this.email,
    this.picture,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (firstName != null) json['firstName'] = firstName;
    if (lastName != null) json['lastName'] = lastName;
    if (email != null) json['email'] = email;
    if (picture != null) json['picture'] = picture;
    return json;
  }
}

/// Modèle pour la requête de modification du mot de passe
class UpdatePasswordRequest {
  final String currentPassword;
  final String newPassword;

  const UpdatePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    };
  }
}

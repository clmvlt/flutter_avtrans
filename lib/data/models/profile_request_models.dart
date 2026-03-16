import 'user_model.dart';

/// Modèle pour la requête de modification du profil
class UpdateProfileRequest {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? picture; // Base64 encoded image
  final Address? address;
  final String? driverLicenseNumber;

  const UpdateProfileRequest({
    this.firstName,
    this.lastName,
    this.email,
    this.picture,
    this.address,
    this.driverLicenseNumber,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (firstName != null) json['firstName'] = firstName;
    if (lastName != null) json['lastName'] = lastName;
    if (email != null) json['email'] = email;
    if (picture != null) json['picture'] = picture;
    if (address != null) json['address'] = address!.toJson();
    if (driverLicenseNumber != null) json['driverLicenseNumber'] = driverLicenseNumber;
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

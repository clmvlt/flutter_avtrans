import 'package:equatable/equatable.dart';
import 'role_model.dart';

/// Modèle représentant un utilisateur
class User extends Equatable {
  final String uuid;
  final String email;
  final String firstName;
  final String lastName;
  final bool isMailVerified;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Role? role;
  final String? token;
  final String? pictureUrl;

  const User({
    required this.uuid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.isMailVerified,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.role,
    this.token,
    this.pictureUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uuid: json['uuid'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      isMailVerified: json['isMailVerified'] as bool,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      role: json['role'] != null
          ? Role.fromJson(json['role'] as Map<String, dynamic>)
          : null,
      token: json['token'] as String?,
      pictureUrl: json['pictureUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'isMailVerified': isMailVerified,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'role': role?.toJson(),
      'token': token,
      'pictureUrl': pictureUrl,
    };
  }

  /// Retourne le nom complet de l'utilisateur
  String get fullName => '$firstName $lastName';

  /// Copie l'utilisateur avec de nouvelles valeurs
  User copyWith({
    String? uuid,
    String? email,
    String? firstName,
    String? lastName,
    bool? isMailVerified,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Role? role,
    String? token,
    String? pictureUrl,
  }) {
    return User(
      uuid: uuid ?? this.uuid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      isMailVerified: isMailVerified ?? this.isMailVerified,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      role: role ?? this.role,
      token: token ?? this.token,
      pictureUrl: pictureUrl ?? this.pictureUrl,
    );
  }

  @override
  List<Object?> get props => [
        uuid,
        email,
        firstName,
        lastName,
        isMailVerified,
        isActive,
        createdAt,
        updatedAt,
        role,
        token,
        pictureUrl,
      ];
}

import 'package:equatable/equatable.dart';
import 'role_model.dart';

/// Préférence de notification
enum NotificationPreference {
  none('NONE', 'Aucune'),
  inApp('IN_APP', 'Dans l\'app'),
  email('EMAIL', 'Email');

  final String value;
  final String label;

  const NotificationPreference(this.value, this.label);

  static NotificationPreference fromValue(String value) {
    final normalized = value.toUpperCase();
    return NotificationPreference.values.firstWhere(
      (p) => p.value == normalized,
      orElse: () => NotificationPreference.inApp,
    );
  }
}

/// Préférences de notification de l'utilisateur
class NotificationPreferences extends Equatable {
  final NotificationPreference acompte;
  final NotificationPreference absence;
  final NotificationPreference userCreated;
  final NotificationPreference rapportVehicule;
  final NotificationPreference todo;

  const NotificationPreferences({
    this.acompte = NotificationPreference.inApp,
    this.absence = NotificationPreference.inApp,
    this.userCreated = NotificationPreference.inApp,
    this.rapportVehicule = NotificationPreference.inApp,
    this.todo = NotificationPreference.inApp,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      acompte: NotificationPreference.fromValue(json['acompte'] as String? ?? 'IN_APP'),
      absence: NotificationPreference.fromValue(json['absence'] as String? ?? 'IN_APP'),
      userCreated: NotificationPreference.fromValue(json['userCreated'] as String? ?? 'IN_APP'),
      rapportVehicule: NotificationPreference.fromValue(json['rapportVehicule'] as String? ?? 'IN_APP'),
      todo: NotificationPreference.fromValue(json['todo'] as String? ?? 'IN_APP'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'acompte': acompte.value,
      'absence': absence.value,
      'userCreated': userCreated.value,
      'rapportVehicule': rapportVehicule.value,
      'todo': todo.value,
    };
  }

  NotificationPreferences copyWith({
    NotificationPreference? acompte,
    NotificationPreference? absence,
    NotificationPreference? userCreated,
    NotificationPreference? rapportVehicule,
    NotificationPreference? todo,
  }) {
    return NotificationPreferences(
      acompte: acompte ?? this.acompte,
      absence: absence ?? this.absence,
      userCreated: userCreated ?? this.userCreated,
      rapportVehicule: rapportVehicule ?? this.rapportVehicule,
      todo: todo ?? this.todo,
    );
  }

  @override
  List<Object?> get props => [acompte, absence, userCreated, rapportVehicule, todo];
}

/// Adresse de l'utilisateur
class Address extends Equatable {
  final String? street;
  final String? city;
  final String? postalCode;
  final String? country;

  const Address({this.street, this.city, this.postalCode, this.country});

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'] as String?,
      city: json['city'] as String?,
      postalCode: json['postalCode'] as String?,
      country: json['country'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (street != null) 'street': street,
      if (city != null) 'city': city,
      if (postalCode != null) 'postalCode': postalCode,
      if (country != null) 'country': country,
    };
  }

  @override
  List<Object?> get props => [street, city, postalCode, country];
}

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
  final bool isCouchette;
  final Address? address;
  final String? driverLicenseNumber;
  final double? heureContrat;
  final NotificationPreferences? notificationPreferences;
  final String? status;

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
    this.isCouchette = false,
    this.address,
    this.driverLicenseNumber,
    this.heureContrat,
    this.notificationPreferences,
    this.status,
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
      isCouchette: json['isCouchette'] as bool? ?? false,
      address: json['address'] != null
          ? Address.fromJson(json['address'] as Map<String, dynamic>)
          : null,
      driverLicenseNumber: json['driverLicenseNumber'] as String?,
      heureContrat: json['heureContrat'] != null
          ? (json['heureContrat'] as num).toDouble()
          : null,
      notificationPreferences: json['notificationPreferences'] != null
          ? NotificationPreferences.fromJson(
              json['notificationPreferences'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String?,
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
      'isCouchette': isCouchette,
      if (address != null) 'address': address!.toJson(),
      if (driverLicenseNumber != null) 'driverLicenseNumber': driverLicenseNumber,
      if (heureContrat != null) 'heureContrat': heureContrat,
      if (notificationPreferences != null)
        'notificationPreferences': notificationPreferences!.toJson(),
      if (status != null) 'status': status,
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
    bool? isCouchette,
    Address? address,
    String? driverLicenseNumber,
    double? heureContrat,
    NotificationPreferences? notificationPreferences,
    String? status,
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
      isCouchette: isCouchette ?? this.isCouchette,
      address: address ?? this.address,
      driverLicenseNumber: driverLicenseNumber ?? this.driverLicenseNumber,
      heureContrat: heureContrat ?? this.heureContrat,
      notificationPreferences: notificationPreferences ?? this.notificationPreferences,
      status: status ?? this.status,
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
        isCouchette,
        address,
        driverLicenseNumber,
        heureContrat,
        notificationPreferences,
        status,
      ];
}

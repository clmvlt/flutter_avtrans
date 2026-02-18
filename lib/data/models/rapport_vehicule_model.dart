class RapportVehicule {
  final String id;
  final UserSimple user;
  final VehiculeSimple vehicule;
  final String? commentaire;
  final DateTime? createdAt;
  final List<RapportPicture> pictures;

  RapportVehicule({
    required this.id,
    required this.user,
    required this.vehicule,
    this.commentaire,
    this.createdAt,
    required this.pictures,
  });

  factory RapportVehicule.fromJson(Map<String, dynamic> json) {
    return RapportVehicule(
      id: json['id'] as String,
      user: UserSimple.fromJson(json['user'] as Map<String, dynamic>),
      vehicule: VehiculeSimple.fromJson(json['vehicule'] as Map<String, dynamic>),
      commentaire: json['commentaire'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      pictures: (json['pictures'] as List<dynamic>?)
              ?.map((e) => RapportPicture.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'vehicule': vehicule.toJson(),
      'commentaire': commentaire,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      'pictures': pictures.map((e) => e.toJson()).toList(),
    };
  }
}

class UserSimple {
  final String uuid;
  final String email;
  final String firstName;
  final String lastName;
  final bool isMailVerified;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RoleSimple? role;
  final String? token;
  final String? pictureUrl;

  UserSimple({
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

  factory UserSimple.fromJson(Map<String, dynamic> json) {
    return UserSimple(
      uuid: json['uuid'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      isMailVerified: json['isMailVerified'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      role: json['role'] != null
          ? RoleSimple.fromJson(json['role'] as Map<String, dynamic>)
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
      if (role != null) 'role': role!.toJson(),
      if (token != null) 'token': token,
      if (pictureUrl != null) 'pictureUrl': pictureUrl,
    };
  }
}

class RoleSimple {
  final String uuid;
  final String nom;
  final String? color;

  RoleSimple({
    required this.uuid,
    required this.nom,
    this.color,
  });

  factory RoleSimple.fromJson(Map<String, dynamic> json) {
    return RoleSimple(
      uuid: json['uuid'] as String,
      nom: json['nom'] as String,
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'nom': nom,
      if (color != null) 'color': color,
    };
  }
}

class VehiculeSimple {
  final String id;
  final String immat;
  final DateTime createdAt;
  final String model;
  final String brand;
  final String? comment;
  final int? latestKm;
  final DateTime? latestKmDate;

  VehiculeSimple({
    required this.id,
    required this.immat,
    required this.createdAt,
    required this.model,
    required this.brand,
    this.comment,
    this.latestKm,
    this.latestKmDate,
  });

  factory VehiculeSimple.fromJson(Map<String, dynamic> json) {
    return VehiculeSimple(
      id: json['id'] as String,
      immat: json['immat'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      model: json['model'] as String,
      brand: json['brand'] as String,
      comment: json['comment'] as String?,
      latestKm: json['latestKm'] as int?,
      latestKmDate: json['latestKmDate'] != null
          ? DateTime.parse(json['latestKmDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'immat': immat,
      'createdAt': createdAt.toIso8601String(),
      'model': model,
      'brand': brand,
      if (comment != null) 'comment': comment,
      if (latestKm != null) 'latestKm': latestKm,
      if (latestKmDate != null) 'latestKmDate': latestKmDate!.toIso8601String(),
    };
  }
}

class RapportPicture {
  final String id;
  final String rapportVehiculeId;
  final String pictureUrl;
  final DateTime createdAt;

  RapportPicture({
    required this.id,
    required this.rapportVehiculeId,
    required this.pictureUrl,
    required this.createdAt,
  });

  factory RapportPicture.fromJson(Map<String, dynamic> json) {
    return RapportPicture(
      id: json['id'] as String,
      rapportVehiculeId: json['rapportVehiculeId'] as String,
      pictureUrl: json['pictureUrl'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rapportVehiculeId': rapportVehiculeId,
      'pictureUrl': pictureUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class CreateRapportRequest {
  final String vehiculeId;
  final String commentaire;
  final List<String>? picturesB64;

  CreateRapportRequest({
    required this.vehiculeId,
    required this.commentaire,
    this.picturesB64,
  });

  Map<String, dynamic> toJson() {
    return {
      'vehiculeId': vehiculeId,
      'commentaire': commentaire,
      if (picturesB64 != null) 'picturesB64': picturesB64,
    };
  }
}

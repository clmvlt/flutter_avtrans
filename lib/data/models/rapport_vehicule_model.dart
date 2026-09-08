import 'package:equatable/equatable.dart';

import 'user_model.dart';
import 'vehicule_model.dart';

/// Rapport d'état d'un véhicule signalé par un chauffeur (RapportVehiculeDTO, contrat API §2.12)
class RapportVehicule extends Equatable {
  final String id;
  final User user;
  final Vehicule vehicule;
  final String? commentaire;
  final DateTime? createdAt;
  final List<RapportPicture> pictures;

  const RapportVehicule({
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
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      vehicule: Vehicule.fromJson(json['vehicule'] as Map<String, dynamic>),
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

  @override
  List<Object?> get props => [id, user, vehicule, commentaire, createdAt, pictures];
}

/// Photo d'un rapport véhicule. `pictureUrl` est absolue (ne pas re-préfixer).
class RapportPicture extends Equatable {
  final String id;
  final String rapportVehiculeId;
  final String pictureUrl;
  final DateTime? createdAt;

  const RapportPicture({
    required this.id,
    required this.rapportVehiculeId,
    required this.pictureUrl,
    this.createdAt,
  });

  factory RapportPicture.fromJson(Map<String, dynamic> json) {
    return RapportPicture(
      id: json['id'] as String,
      rapportVehiculeId: json['rapportVehiculeId'] as String,
      pictureUrl: json['pictureUrl'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rapportVehiculeId': rapportVehiculeId,
      'pictureUrl': pictureUrl,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, rapportVehiculeId, pictureUrl, createdAt];
}

/// Body de `POST /rapports` (contrat API §4.9).
/// `vehiculeId` obligatoire ; `picturesB64` = data URIs (`data:image/jpeg;base64,...`).
class CreateRapportRequest {
  final String vehiculeId;
  final String? commentaire;
  final List<String>? picturesB64;

  const CreateRapportRequest({
    required this.vehiculeId,
    this.commentaire,
    this.picturesB64,
  });

  Map<String, dynamic> toJson() {
    return {
      'vehiculeId': vehiculeId,
      if (commentaire != null && commentaire!.isNotEmpty) 'commentaire': commentaire,
      if (picturesB64 != null && picturesB64!.isNotEmpty) 'picturesB64': picturesB64,
    };
  }
}

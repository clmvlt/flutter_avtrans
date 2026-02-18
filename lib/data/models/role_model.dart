import 'package:equatable/equatable.dart';

/// Modèle représentant un rôle utilisateur
class Role extends Equatable {
  final String uuid;
  final String nom;
  final String color;

  const Role({
    required this.uuid,
    required this.nom,
    required this.color,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      uuid: json['uuid'] as String,
      nom: json['nom'] as String,
      color: json['color'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'nom': nom,
      'color': color,
    };
  }

  @override
  List<Object?> get props => [uuid, nom, color];
}

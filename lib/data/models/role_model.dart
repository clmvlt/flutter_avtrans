import 'package:equatable/equatable.dart';

/// UUID des rôles en base (identiques à l'app web). Les rôles se comparent
/// par UUID, jamais par nom (« Mécanicien » porte un accent, la casse varie).
abstract final class RoleIds {
  static const String utilisateur = '99127dd5-f7bd-446c-9fd0-c05d4ea135b2';
  static const String administrateur = 'c10523af-a4ab-47e2-8025-5ef4e241ef08';
  static const String mecanicien = 'ccbd448a-0eef-4277-b53b-91be340b080f';
}

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
      color: json['color'] as String? ?? '',
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

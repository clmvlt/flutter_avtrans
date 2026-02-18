import 'package:equatable/equatable.dart';

/// Modèle d'un type d'absence
class AbsenceType extends Equatable {
  final String uuid;
  final String name;
  final String color;
  final DateTime? createdAt;

  const AbsenceType({
    required this.uuid,
    required this.name,
    required this.color,
    this.createdAt,
  });

  factory AbsenceType.fromJson(Map<String, dynamic> json) {
    return AbsenceType(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'color': color,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [uuid, name, color, createdAt];
}

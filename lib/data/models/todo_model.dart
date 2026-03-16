import 'package:equatable/equatable.dart';

import 'user_model.dart';

/// Modèle représentant une catégorie de todo
class TodoCategory extends Equatable {
  final String uuid;
  final String name;
  final String? color;
  final DateTime? createdAt;

  const TodoCategory({
    required this.uuid,
    required this.name,
    this.color,
    this.createdAt,
  });

  factory TodoCategory.fromJson(Map<String, dynamic> json) {
    return TodoCategory(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      if (color != null) 'color': color,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [uuid, name, color, createdAt];
}

/// Modèle représentant un todo
class Todo extends Equatable {
  final String uuid;
  final String title;
  final String? description;
  final TodoCategory? category;
  final bool isDone;
  final DateTime? completedAt;
  final User? completedBy;
  final User? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Todo({
    required this.uuid,
    required this.title,
    this.description,
    this.category,
    this.isDone = false,
    this.completedAt,
    this.completedBy,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      uuid: json['uuid'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] != null
          ? TodoCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      isDone: json['isDone'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      completedBy: json['completedBy'] != null
          ? User.fromJson(json['completedBy'] as Map<String, dynamic>)
          : null,
      createdBy: json['createdBy'] != null
          ? User.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'title': title,
      if (description != null) 'description': description,
      if (category != null) 'category': category!.toJson(),
      'isDone': isDone,
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      if (completedBy != null) 'completedBy': completedBy!.toJson(),
      if (createdBy != null) 'createdBy': createdBy!.toJson(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        uuid,
        title,
        description,
        category,
        isDone,
        completedAt,
        completedBy,
        createdBy,
        createdAt,
        updatedAt,
      ];
}

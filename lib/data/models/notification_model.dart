import 'package:equatable/equatable.dart';

import 'user_model.dart';

/// Modèle représentant une notification
class AppNotification extends Equatable {
  final String uuid;
  final User? user;
  final String title;
  final String? description;
  final DateTime? createdAt;
  final bool isRead;
  final String? refType;
  final String? refId;

  const AppNotification({
    required this.uuid,
    this.user,
    required this.title,
    this.description,
    this.createdAt,
    this.isRead = false,
    this.refType,
    this.refId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      uuid: json['uuid'] as String,
      user: json['user'] != null
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      title: json['title'] as String,
      description: json['description'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      isRead: json['isRead'] as bool? ?? false,
      refType: json['refType'] as String?,
      refId: json['refId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      if (user != null) 'user': user!.toJson(),
      'title': title,
      if (description != null) 'description': description,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      'isRead': isRead,
      if (refType != null) 'refType': refType,
      if (refId != null) 'refId': refId,
    };
  }

  @override
  List<Object?> get props => [
        uuid,
        user,
        title,
        description,
        createdAt,
        isRead,
        refType,
        refId,
      ];
}

import 'package:equatable/equatable.dart';

import 'user_model.dart';

/// Modèle représentant une couchette
class Couchette extends Equatable {
  final String uuid;
  final String? date;
  final User? user;
  final DateTime? createdAt;

  const Couchette({
    required this.uuid,
    this.date,
    this.user,
    this.createdAt,
  });

  factory Couchette.fromJson(Map<String, dynamic> json) {
    return Couchette(
      uuid: json['uuid'] as String,
      date: json['date'] as String?,
      user: json['user'] != null
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      if (date != null) 'date': date,
      if (user != null) 'user': user!.toJson(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [uuid, date, user, createdAt];
}

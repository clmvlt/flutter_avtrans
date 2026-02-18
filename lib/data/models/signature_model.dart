import 'package:equatable/equatable.dart';
import 'user_model.dart';

/// Modèle représentant une signature
class Signature extends Equatable {
  final String uuid;
  final String signatureBase64;
  final DateTime date;
  final double heuresSignees;
  final String? userUuid;
  final User? user;
  final DateTime? createdAt;

  const Signature({
    required this.uuid,
    required this.signatureBase64,
    required this.date,
    required this.heuresSignees,
    this.userUuid,
    this.user,
    this.createdAt,
  });

  factory Signature.fromJson(Map<String, dynamic> json) {
    return Signature(
      uuid: json['uuid'] as String,
      signatureBase64: json['signatureBase64'] as String,
      date: DateTime.parse(json['date'] as String),
      heuresSignees: (json['heuresSignees'] as num).toDouble(),
      userUuid: json['userUuid'] as String?,
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
      'signatureBase64': signatureBase64,
      'date': date.toIso8601String(),
      'heuresSignees': heuresSignees,
      if (userUuid != null) 'userUuid': userUuid,
      if (user != null) 'user': user!.toJson(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        uuid,
        signatureBase64,
        date,
        heuresSignees,
        userUuid,
        user,
        createdAt,
      ];
}

/// Résumé de la dernière signature
class SignatureSummary extends Equatable {
  final DateTime? date;
  final double? heuresSignees;
  final bool needsToSign;
  final double? heuresLastMonth;

  const SignatureSummary({
    this.date,
    this.heuresSignees,
    required this.needsToSign,
    this.heuresLastMonth,
  });

  factory SignatureSummary.fromJson(Map<String, dynamic> json) {
    return SignatureSummary(
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
      heuresSignees: json['heuresSignees'] != null
          ? (json['heuresSignees'] as num).toDouble()
          : null,
      needsToSign: json['needsToSign'] as bool,
      heuresLastMonth: json['heuresLastMonth'] != null
          ? (json['heuresLastMonth'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (date != null) 'date': date!.toIso8601String(),
      if (heuresSignees != null) 'heuresSignees': heuresSignees,
      'needsToSign': needsToSign,
      if (heuresLastMonth != null) 'heuresLastMonth': heuresLastMonth,
    };
  }

  @override
  List<Object?> get props => [date, heuresSignees, needsToSign, heuresLastMonth];
}

/// Utilisateur avec sa dernière signature (pour l'endpoint all-users)
class UserWithLastSignature extends Equatable {
  final User user;
  final Signature? lastSignature;

  const UserWithLastSignature({
    required this.user,
    this.lastSignature,
  });

  factory UserWithLastSignature.fromJson(Map<String, dynamic> json) {
    return UserWithLastSignature(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      lastSignature: json['lastSignature'] != null
          ? Signature.fromJson(json['lastSignature'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      if (lastSignature != null) 'lastSignature': lastSignature!.toJson(),
    };
  }

  @override
  List<Object?> get props => [user, lastSignature];
}

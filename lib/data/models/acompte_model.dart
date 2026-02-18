import 'package:equatable/equatable.dart';

import 'user_model.dart';

/// Statut d'un acompte
enum AcompteStatus {
  pending('pending', 'En attente'),
  approved('approved', 'Approuvé'),
  rejected('rejected', 'Rejeté'),
  cancelled('cancelled', 'Annulé');

  final String value;
  final String label;

  const AcompteStatus(this.value, this.label);

  static AcompteStatus fromValue(String value) {
    // Normalise en minuscules pour gérer les deux formats (PENDING et pending)
    final normalizedValue = value.toLowerCase();
    return AcompteStatus.values.firstWhere(
      (status) => status.value == normalizedValue,
      orElse: () => AcompteStatus.pending,
    );
  }
}

/// Modèle représentant un acompte
class Acompte extends Equatable {
  final String uuid;
  final String userUuid;
  final User? user;
  final double montant;
  final String? raison;
  final AcompteStatus status;
  final String? validatedByUuid;
  final User? validatedBy;
  final DateTime? validatedAt;
  final String? rejectionReason;
  final bool isPaid;
  final DateTime? paidDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Acompte({
    required this.uuid,
    required this.userUuid,
    this.user,
    required this.montant,
    this.raison,
    required this.status,
    this.validatedByUuid,
    this.validatedBy,
    this.validatedAt,
    this.rejectionReason,
    this.isPaid = false,
    this.paidDate,
    this.createdAt,
    this.updatedAt,
  });

  factory Acompte.fromJson(Map<String, dynamic> json) {
    return Acompte(
      uuid: json['uuid'] as String,
      userUuid: json['userUuid'] as String,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      montant: (json['montant'] as num).toDouble(),
      raison: json['raison'] as String?,
      status: AcompteStatus.fromValue(json['status'] as String),
      validatedByUuid: json['validatedByUuid'] as String?,
      validatedBy: json['validatedBy'] != null
          ? User.fromJson(json['validatedBy'])
          : null,
      validatedAt: json['validatedAt'] != null
          ? DateTime.parse(json['validatedAt'] as String)
          : null,
      rejectionReason: json['rejectionReason'] as String?,
      isPaid: json['isPaid'] as bool? ?? false,
      paidDate: json['paidDate'] != null
          ? DateTime.parse(json['paidDate'] as String)
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
      'userUuid': userUuid,
      if (user != null) 'user': user!.toJson(),
      'montant': montant,
      'raison': raison,
      'status': status.value,
      if (validatedByUuid != null) 'validatedByUuid': validatedByUuid,
      if (validatedBy != null) 'validatedBy': validatedBy!.toJson(),
      if (validatedAt != null) 'validatedAt': validatedAt!.toIso8601String(),
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'isPaid': isPaid,
      if (paidDate != null) 'paidDate': paidDate!.toIso8601String(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        uuid,
        userUuid,
        user,
        montant,
        raison,
        status,
        validatedByUuid,
        validatedBy,
        validatedAt,
        rejectionReason,
        isPaid,
        paidDate,
        createdAt,
        updatedAt,
      ];
}

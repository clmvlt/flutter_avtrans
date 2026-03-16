import 'package:equatable/equatable.dart';

import 'absence_type_model.dart';
import 'user_model.dart';

/// Statut d'une absence
enum AbsenceStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED'),
  cancelled('CANCELLED');

  final String value;
  const AbsenceStatus(this.value);

  static AbsenceStatus fromString(String value) {
    return AbsenceStatus.values.firstWhere(
      (s) => s.value.toUpperCase() == value.toUpperCase(),
      orElse: () => AbsenceStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case AbsenceStatus.pending:
        return 'En attente';
      case AbsenceStatus.approved:
        return 'Approuvée';
      case AbsenceStatus.rejected:
        return 'Refusée';
      case AbsenceStatus.cancelled:
        return 'Annulée';
    }
  }
}

/// Modèle d'une demande d'absence
class Absence extends Equatable {
  final String uuid;
  final User? user;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final AbsenceType? absenceType;
  final String? customType;
  final String? period;
  final AbsenceStatus status;
  final User? validatedBy;
  final DateTime? validatedAt;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Absence({
    required this.uuid,
    this.user,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.absenceType,
    this.customType,
    this.period,
    required this.status,
    this.validatedBy,
    this.validatedAt,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  /// Durée de l'absence en jours
  int get durationInDays {
    return endDate.difference(startDate).inDays + 1;
  }

  /// Vérifie si l'absence peut être annulée
  bool get canBeCancelled => status == AbsenceStatus.pending;

  /// Retourne le nom du type d'absence à afficher
  String get typeName {
    if (absenceType != null) {
      return absenceType!.name;
    }
    if (customType != null && customType!.isNotEmpty) {
      return customType!;
    }
    return 'Non spécifié';
  }

  /// Retourne la couleur du type d'absence
  String? get typeColor => absenceType?.color;

  factory Absence.fromJson(Map<String, dynamic> json) {
    return Absence(
      uuid: json['uuid'] as String,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      reason: json['reason'] as String? ?? '',
      absenceType: json['absenceType'] != null
          ? AbsenceType.fromJson(json['absenceType'])
          : null,
      customType: json['customType'] as String?,
      period: json['period'] as String?,
      status: AbsenceStatus.fromString(json['status'] as String),
      validatedBy: json['validatedBy'] != null
          ? User.fromJson(json['validatedBy'])
          : null,
      validatedAt: json['validatedAt'] != null
          ? DateTime.parse(json['validatedAt'] as String)
          : null,
      rejectionReason: json['rejectionReason'] as String?,
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
      'user': user?.toJson(),
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
      'reason': reason,
      'absenceType': absenceType?.toJson(),
      'customType': customType,
      'period': period,
      'status': status.value,
      'validatedBy': validatedBy?.toJson(),
      'validatedAt': validatedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        uuid,
        user,
        startDate,
        endDate,
        reason,
        absenceType,
        customType,
        period,
        status,
        validatedBy,
        validatedAt,
        rejectionReason,
        createdAt,
        updatedAt,
      ];
}

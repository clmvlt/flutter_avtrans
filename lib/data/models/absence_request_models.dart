/// Requête pour créer une demande d'absence
class CreateAbsenceRequest {
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String? absenceTypeUuid;
  final String? customType;
  final String? period;

  const CreateAbsenceRequest({
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.absenceTypeUuid,
    this.customType,
    this.period,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
      'reason': reason,
    };

    if (absenceTypeUuid != null) {
      map['absenceTypeUuid'] = absenceTypeUuid;
    }
    if (customType != null && customType!.isNotEmpty) {
      map['customType'] = customType;
    }
    if (period != null && period!.isNotEmpty) {
      map['period'] = period;
    }

    return map;
  }
}

/// Paramètres pour récupérer la liste des absences (POST body)
class AbsenceListParams {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final String? absenceTypeUuid;
  final int page;
  final int size;
  final String? sortBy;
  final String? sortDirection;

  const AbsenceListParams({
    this.startDate,
    this.endDate,
    this.status,
    this.absenceTypeUuid,
    this.page = 0,
    this.size = 20,
    this.sortBy,
    this.sortDirection,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'page': page,
      'size': size,
    };

    if (startDate != null) {
      map['startDate'] = startDate!.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      map['endDate'] = endDate!.toIso8601String().split('T')[0];
    }
    if (status != null && status!.isNotEmpty) {
      map['status'] = status;
    }
    if (absenceTypeUuid != null) {
      map['absenceTypeUuid'] = absenceTypeUuid;
    }
    if (sortBy != null && sortBy!.isNotEmpty) {
      map['sortBy'] = sortBy;
    }
    if (sortDirection != null && sortDirection!.isNotEmpty) {
      map['sortDirection'] = sortDirection;
    }

    return map;
  }
}

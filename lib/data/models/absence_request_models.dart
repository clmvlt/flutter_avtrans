import 'absence_model.dart';
import 'paginated_response.dart';

/// Requête pour créer une demande d'absence — `POST /absences` (contrat API §4.3).
///
/// Dates au format `yyyy-MM-dd`. `reason` max 500 caractères, `customType` max 100.
/// `period` omise → FULL_DAY côté serveur.
class CreateAbsenceRequest {
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;
  final String? absenceTypeUuid;
  final String? customType;
  final AbsencePeriod? period;

  const CreateAbsenceRequest({
    required this.startDate,
    required this.endDate,
    this.reason,
    this.absenceTypeUuid,
    this.customType,
    this.period,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'startDate': formatApiDate(startDate),
      'endDate': formatApiDate(endDate),
    };

    if (reason != null && reason!.isNotEmpty) {
      map['reason'] = reason;
    }
    if (absenceTypeUuid != null) {
      map['absenceTypeUuid'] = absenceTypeUuid;
    }
    if (customType != null && customType!.isNotEmpty) {
      map['customType'] = customType;
    }
    if (period != null) {
      map['period'] = period!.value;
    }

    return map;
  }
}

/// Paramètres pour `POST /absences/my` (contrat API §4.3).
///
/// Filtre : absence ENTIÈREMENT dans `[startDate ; endDate]`.
/// Défaut serveur si aucune des deux dates : `[aujourd'hui − 30 j ; aujourd'hui + 10 ans]`.
/// Pour tout l'historique, envoyer explicitement une `startDate` ancienne.
/// `sortBy` sûrs : `startDate` (défaut), `endDate`, `createdAt`, `status`.
class AbsenceListParams {
  final DateTime? startDate;
  final DateTime? endDate;
  final AbsenceStatus? status;
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
      map['startDate'] = formatApiDate(startDate!);
    }
    if (endDate != null) {
      map['endDate'] = formatApiDate(endDate!);
    }
    if (status != null) {
      map['status'] = status!.value;
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

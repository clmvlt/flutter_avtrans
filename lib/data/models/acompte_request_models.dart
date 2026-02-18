import 'acompte_model.dart';
import 'paginated_response.dart';

/// Requête pour créer un acompte
class AcompteCreateRequest {
  final double montant;
  final String raison;

  const AcompteCreateRequest({
    required this.montant,
    required this.raison,
  });

  Map<String, dynamic> toJson() {
    return {
      'montant': montant,
      'raison': raison,
    };
  }
}

/// Paramètres pour récupérer la liste des acomptes
class AcompteListParams {
  final DateTime? startDate;
  final DateTime? endDate;
  final AcompteStatus? status;
  final double? montantMin;
  final double? montantMax;
  final String? userUuid;
  final int? page;
  final int? size;
  final String? sortBy;
  final SortDirection? sortDirection;

  const AcompteListParams({
    this.startDate,
    this.endDate,
    this.status,
    this.montantMin,
    this.montantMax,
    this.userUuid,
    this.page,
    this.size,
    this.sortBy,
    this.sortDirection,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (startDate != null) {
      json['startDate'] = startDate!.toIso8601String();
    }
    if (endDate != null) {
      json['endDate'] = endDate!.toIso8601String();
    }
    if (status != null) {
      json['status'] = status!.value;
    }
    if (montantMin != null) {
      json['montantMin'] = montantMin;
    }
    if (montantMax != null) {
      json['montantMax'] = montantMax;
    }
    if (userUuid != null) {
      json['userUuid'] = userUuid;
    }
    if (page != null) {
      json['page'] = page;
    }
    if (size != null) {
      json['size'] = size;
    }
    if (sortBy != null) {
      json['sortBy'] = sortBy;
    }
    if (sortDirection != null) {
      json['sortDirection'] = sortDirection!.value;
    }

    return json;
  }
}

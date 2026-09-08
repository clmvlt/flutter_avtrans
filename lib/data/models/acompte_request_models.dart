import 'acompte_model.dart';
import 'paginated_response.dart';

/// Requête pour créer un acompte — `POST /acomptes` (contrat API §4.4).
/// `montant` obligatoire et strictement positif (validé côté serveur → 400 `Validation error`).
/// `raison` optionnelle, max 500 caractères.
class AcompteCreateRequest {
  final double montant;
  final String? raison;

  const AcompteCreateRequest({
    required this.montant,
    this.raison,
  });

  Map<String, dynamic> toJson() {
    return {
      'montant': montant,
      if (raison != null && raison!.isNotEmpty) 'raison': raison,
    };
  }
}

/// Paramètres pour `POST /acomptes/my` (contrat API §4.4).
///
/// Filtre sur `createdAt` : `startDate 00:00 → endDate 23:59:59.999` (jour de fin INCLUS).
/// Défaut serveur sans dates : `[aujourd'hui − 30 j ; +10 ans]`.
/// `userUuid` est ignoré par cette route (l'utilisateur est déduit du token).
class AcompteListParams {
  final DateTime? startDate;
  final DateTime? endDate;
  final AcompteStatus? status;
  final double? montantMin;
  final double? montantMax;
  final bool? isPaid;
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
    this.isPaid,
    this.page,
    this.size,
    this.sortBy,
    this.sortDirection,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (startDate != null) {
      json['startDate'] = formatApiDate(startDate!);
    }
    if (endDate != null) {
      json['endDate'] = formatApiDate(endDate!);
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
    if (isPaid != null) {
      json['isPaid'] = isPaid;
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

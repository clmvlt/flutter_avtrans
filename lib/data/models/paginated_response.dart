/// Réponse paginée générique
class PaginatedResponse<T> {
  final bool success;
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  const PaginatedResponse({
    required this.success,
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginatedResponse(
      success: json['success'] as bool? ?? true,
      content: (json['content'] as List<dynamic>?)
              ?.map((e) => fromJsonT(e as Map<String, dynamic>))
              .toList() ??
          [],
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 10,
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      first: json['first'] as bool? ?? true,
      last: json['last'] as bool? ?? true,
    );
  }

  /// Vérifie s'il y a une page suivante
  bool get hasNextPage => !last;

  /// Vérifie s'il y a une page précédente
  bool get hasPreviousPage => !first;

  /// Vérifie si la liste est vide
  bool get isEmpty => content.isEmpty;

  /// Vérifie si la liste n'est pas vide
  bool get isNotEmpty => content.isNotEmpty;
}

/// Formate une date au format `yyyy-MM-dd` attendu par les champs `LocalDate` de l'API
/// (contrat §1.3). Une chaîne ISO complète avec heure provoque un 400 `Invalid JSON format`.
String formatApiDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Paramètres de requête pour `POST /services/history` (contrat API §4.2).
///
/// Sans `startDate`/`endDate` : aucun filtre de date (tout l'historique, paginé).
/// `endDate` est inclusive côté client : le serveur filtre `debut <= endDate 00:00`
/// (jour de fin exclu), donc `toJson` envoie `endDate + 1 jour`.
class ServiceHistoryParams {
  final int? page;
  final int? size;
  final bool? isBreak;
  final DateTime? startDate;
  final DateTime? endDate;
  final ServiceHistorySortBy? sortBy;
  final SortDirection? sortDirection;

  const ServiceHistoryParams({
    this.page,
    this.size,
    this.isBreak,
    this.startDate,
    this.endDate,
    this.sortBy,
    this.sortDirection,
  });

  /// Convertit en JSON pour le body de la requête POST
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (page != null) json['page'] = page;
    if (size != null) json['size'] = size;
    if (isBreak != null) json['isBreak'] = isBreak;
    if (startDate != null) json['startDate'] = formatApiDate(startDate!);
    if (endDate != null) {
      // Borne serveur = minuit du jour de fin → envoyer jour voulu + 1
      json['endDate'] = formatApiDate(endDate!.add(const Duration(days: 1)));
    }
    if (sortBy != null) json['sortBy'] = sortBy!.value;
    if (sortDirection != null) json['sortDirection'] = sortDirection!.value;

    return json;
  }

  ServiceHistoryParams copyWith({
    int? page,
    int? size,
    bool? isBreak,
    DateTime? startDate,
    DateTime? endDate,
    ServiceHistorySortBy? sortBy,
    SortDirection? sortDirection,
  }) {
    return ServiceHistoryParams(
      page: page ?? this.page,
      size: size ?? this.size,
      isBreak: isBreak ?? this.isBreak,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
    );
  }
}

/// Champs de tri pour l'historique
enum ServiceHistorySortBy {
  debut('debut'),
  fin('fin'),
  duree('duree');

  final String value;
  const ServiceHistorySortBy(this.value);
}

/// Direction du tri
enum SortDirection {
  asc('asc'),
  desc('desc');

  final String value;
  const SortDirection(this.value);
}

/// Requête de création d'un todo
class TodoCreateRequest {
  final String title;
  final String? description;
  final String? categoryUuid;

  const TodoCreateRequest({
    required this.title,
    this.description,
    this.categoryUuid,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (description != null) 'description': description,
      if (categoryUuid != null) 'categoryUuid': categoryUuid,
    };
  }
}

/// Requête de mise à jour d'un todo
class TodoUpdateRequest {
  final String? title;
  final String? description;
  final String? categoryUuid;

  const TodoUpdateRequest({
    this.title,
    this.description,
    this.categoryUuid,
  });

  Map<String, dynamic> toJson() {
    return {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (categoryUuid != null) 'categoryUuid': categoryUuid,
    };
  }
}

/// Requête de recherche de todos
class TodoSearchParams {
  final String? categoryUuid;
  final bool? isDone;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? page;
  final int? size;
  final String? sortBy;
  final String? sortDirection;

  const TodoSearchParams({
    this.categoryUuid,
    this.isDone,
    this.startDate,
    this.endDate,
    this.page,
    this.size,
    this.sortBy,
    this.sortDirection,
  });

  Map<String, dynamic> toJson() {
    return {
      if (categoryUuid != null) 'categoryUuid': categoryUuid,
      if (isDone != null) 'isDone': isDone,
      if (startDate != null)
        'startDate':
            '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
      if (endDate != null)
        'endDate':
            '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
      if (page != null) 'page': page,
      if (size != null) 'size': size,
      if (sortBy != null) 'sortBy': sortBy,
      if (sortDirection != null) 'sortDirection': sortDirection,
    };
  }

  TodoSearchParams copyWith({
    String? categoryUuid,
    bool? isDone,
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    int? size,
    String? sortBy,
    String? sortDirection,
  }) {
    return TodoSearchParams(
      categoryUuid: categoryUuid ?? this.categoryUuid,
      isDone: isDone ?? this.isDone,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      page: page ?? this.page,
      size: size ?? this.size,
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
    );
  }
}

/// Requête de création de catégorie todo
class TodoCategoryCreateRequest {
  final String name;
  final String? color;

  const TodoCategoryCreateRequest({
    required this.name,
    this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (color != null) 'color': color,
    };
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import 'widgets/todo_card.dart';
import 'widgets/todo_create_sheet.dart';
import 'widgets/todos_header.dart';

/// Page « Tâches » (Administrateur et Mécanicien) : le nombre de tâches à
/// faire en hero, les filtres (statut, catégorie), puis la liste paginée
/// (20 par page, chargement au défilement). « Nouvelle tâche » vit dans le
/// dock.
class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> with DockNoticeMixin {
  final List<Todo> _todos = [];
  List<TodoCategory> _categories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasLoaded = false;
  int _currentPage = 0;
  String? _error;

  /// Nombre de tâches à faire (catégorie filtrée comprise), pour le hero.
  int? _openCount;

  /// Tâches dont le basculement est en cours (pas de double appel).
  final Set<String> _toggling = {};

  /// Jeton de la dernière recherche : une réponse plus ancienne (filtre
  /// changé entre-temps) est ignorée.
  int _loadToken = 0;

  /// Une recherche de première page est en vol (même silencieuse) : pas de
  /// « page suivante » en parallèle.
  bool _isFetching = false;

  // Filtres
  TodoStatusFilter _status = TodoStatusFilter.all;
  String? _filterCategoryUuid;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadTodos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        !_isFetching &&
        _hasMore) {
      _loadMoreTodos();
    }
  }

  // ---- chargement ---------------------------------------------------------

  Future<void> _loadCategories() async {
    final result = await sl.todoRepository.getCategories();
    if (!mounted) return;
    result.fold(
      (_) {},
      (categories) => setState(() => _categories = categories),
    );
  }

  TodoSearchParams _buildParams({int page = 0}) {
    return TodoSearchParams(
      page: page,
      size: 20,
      isDone: _status.isDone,
      categoryUuid: _filterCategoryUuid,
      sortBy: 'createdAt',
      sortDirection: 'desc',
    );
  }

  /// Recharge la première page. [silent] (tirer pour rafraîchir) garde la
  /// liste affichée ; un échec passe alors par le dock.
  Future<void> _loadTodos({bool silent = false}) async {
    final token = ++_loadToken;
    _isFetching = true;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    _loadOpenCount();

    final result = await sl.todoRepository.searchTodos(_buildParams());

    if (!mounted || token != _loadToken) return;
    _isFetching = false;

    result.fold(
      (failure) {
        if (silent && _todos.isNotEmpty && _error == null) {
          showDockError(failure.message);
        } else {
          setState(() {
            _error = failure.message;
            _isLoading = false;
          });
        }
      },
      (response) => setState(() {
        _todos
          ..clear()
          ..addAll(response.content);
        _currentPage = 0;
        _hasMore = !response.last;
        _isLoading = false;
        _error = null;
        _hasLoaded = true;
      }),
    );
  }

  Future<void> _refresh() => _loadTodos(silent: true);

  /// Décompte des tâches à faire pour le hero (une page d'un élément : seul
  /// `totalElements` sert).
  Future<void> _loadOpenCount() async {
    final categoryUuid = _filterCategoryUuid;
    final result = await sl.todoRepository.searchTodos(
      TodoSearchParams(
        page: 0,
        size: 1,
        isDone: false,
        categoryUuid: categoryUuid,
      ),
    );
    if (!mounted || categoryUuid != _filterCategoryUuid) return;
    setState(() {
      _openCount = result.fold((_) => null, (r) => r.totalElements);
    });
  }

  Future<void> _loadMoreTodos() async {
    if (_isLoadingMore) return;
    final token = _loadToken;
    setState(() => _isLoadingMore = true);

    final result = await sl.todoRepository.searchTodos(
      _buildParams(page: _currentPage + 1),
    );

    if (!mounted) return;
    if (token != _loadToken) {
      setState(() => _isLoadingMore = false);
      return;
    }

    result.fold(
      (failure) => setState(() => _isLoadingMore = false),
      (response) {
        setState(() {
          _todos.addAll(response.content);
          _currentPage++;
          _hasMore = !response.last;
          _isLoadingMore = false;
        });
      },
    );
  }

  // ---- actions ------------------------------------------------------------

  Future<void> _toggleTodo(Todo todo) async {
    if (_toggling.contains(todo.uuid)) return;
    clearDockNotice();
    setState(() => _toggling.add(todo.uuid));

    final result = await sl.todoRepository.toggleTodo(todo.uuid);
    if (!mounted) return;

    setState(() => _toggling.remove(todo.uuid));
    result.fold(
      (failure) => showDockError(failure.message),
      (updatedTodo) {
        HapticFeedback.lightImpact();
        setState(() {
          final index = _todos.indexWhere((t) => t.uuid == todo.uuid);
          if (index != -1) _todos[index] = updatedTodo;
          final count = _openCount;
          if (count != null && updatedTodo.isDone != todo.isDone) {
            _openCount = math.max(0, count + (updatedTodo.isDone ? -1 : 1));
          }
        });
      },
    );
  }

  Future<void> _deleteTodo(Todo todo) async {
    clearDockNotice();
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Supprimer la tâche ?',
      message: '« ${todo.title} » sera supprimée définitivement.',
      confirmLabel: 'Supprimer la tâche',
      confirmIcon: Icons.delete_rounded,
    );

    if (!confirmed || !mounted) return;

    final result = await sl.todoRepository.deleteTodo(todo.uuid);
    if (!mounted) return;
    result.fold(
      (failure) => showDockError(failure.message),
      // La ligne disparaît : pas de message.
      (_) => setState(() {
        _todos.removeWhere((t) => t.uuid == todo.uuid);
        final count = _openCount;
        if (count != null && !todo.isDone) _openCount = math.max(0, count - 1);
      }),
    );
  }

  Future<void> _createTodo() async {
    clearDockNotice();
    final todo = await TodoCreateSheet.show(context, categories: _categories);
    if (todo == null || !mounted) return;

    // La nouvelle tâche apparaît en tête de liste : pas de message.
    setState(() {
      _todos.insert(0, todo);
      final count = _openCount;
      final inScope = _filterCategoryUuid == null ||
          todo.category?.uuid == _filterCategoryUuid;
      if (count != null && !todo.isDone && inScope) _openCount = count + 1;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: AppDuration.base,
        curve: Curves.easeOut,
      );
    }
  }

  // ---- filtres ------------------------------------------------------------

  void _setStatus(TodoStatusFilter status) {
    setState(() => _status = status);
    _loadTodos();
  }

  void _setCategory(String? categoryUuid) {
    setState(() => _filterCategoryUuid = categoryUuid);
    _loadTodos();
  }

  void _clearFilters() {
    setState(() {
      _status = TodoStatusFilter.all;
      _filterCategoryUuid = null;
    });
    _loadTodos();
  }

  bool get _hasActiveFilters =>
      _status != TodoStatusFilter.all || _filterCategoryUuid != null;

  TodoCategory? get _selectedCategory {
    for (final c in _categories) {
      if (c.uuid == _filterCategoryUuid) return c;
    }
    return null;
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Tâches',
      body: _buildBody(),
      dock: AppDock(
        skeleton: !_hasLoaded && _isLoading,
        actions: [
          DockAction(
            label: 'Nouvelle tâche',
            icon: Icons.add_rounded,
            onPressed: _createTodo,
          ),
        ],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
      ),
    );
  }

  Widget _buildBody() {
    // Premier chargement : squelette, ou erreur sous le titre.
    if (!_hasLoaded && _todos.isEmpty) {
      final error = _error;
      return AppScrollView(
        onRefresh: error != null ? _loadTodos : null,
        children: [
          if (error != null && !_isLoading)
            AppErrorState(message: error, onRetry: _loadTodos)
          else
            const TodosSkeleton(),
        ],
      );
    }

    final showItems = !_isLoading && _error == null && _todos.isNotEmpty;

    return AppListView(
      controller: _scrollController,
      onRefresh: _refresh,
      header: [
        TodosHero(openCount: _openCount, category: _selectedCategory),
        const SizedBox(height: AppSpacing.lg),
        TodosFilters(
          status: _status,
          onStatusChanged: _setStatus,
          categories: _categories,
          categoryUuid: _filterCategoryUuid,
          onCategoryChanged: _setCategory,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!showItems) _buildListState(),
      ],
      itemCount: showItems ? _todos.length : 0,
      itemBuilder: (context, index) {
        final todo = _todos[index];
        return TodoCard(
          key: ValueKey(todo.uuid),
          todo: todo,
          busy: _toggling.contains(todo.uuid),
          onToggle: () => _toggleTodo(todo),
          onDelete: () => _deleteTodo(todo),
        );
      },
      footer: showItems && _isLoadingMore
          ? Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.colors.primary,
                ),
              ),
            )
          : null,
    );
  }

  /// Zone de liste quand il n'y a pas de lignes à montrer.
  Widget _buildListState() {
    if (_isLoading) return const AppListSkeleton(rows: 4);
    final error = _error;
    if (error != null) {
      return AppErrorState(message: error, onRetry: _loadTodos);
    }
    return AppEmptyCard(
      icon: Icons.checklist_rounded,
      message: _hasActiveFilters
          ? 'Aucune tâche ne correspond aux filtres'
          : 'Aucune tâche',
      detail: _hasActiveFilters
          ? null
          : 'Appuie sur « Nouvelle tâche » pour en créer une.',
      actionLabel: _hasActiveFilters ? 'Effacer' : null,
      onAction: _hasActiveFilters ? _clearFilters : null,
    );
  }
}

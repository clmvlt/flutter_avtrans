import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';

/// Page de gestion des todos
class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  final List<Todo> _todos = [];
  List<TodoCategory> _categories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _error;

  // Filtres
  bool? _filterIsDone;
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
        _hasMore) {
      _loadMoreTodos();
    }
  }

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
      isDone: _filterIsDone,
      categoryUuid: _filterCategoryUuid,
      sortBy: 'createdAt',
      sortDirection: 'desc',
    );
  }

  Future<void> _loadTodos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await sl.todoRepository.searchTodos(_buildParams());

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (response) {
        setState(() {
          _todos.clear();
          _todos.addAll(response.content);
          _currentPage = 0;
          _hasMore = !response.last;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _loadMoreTodos() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final result = await sl.todoRepository.searchTodos(
      _buildParams(page: _currentPage + 1),
    );

    if (!mounted) return;

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

  Future<void> _toggleTodo(Todo todo) async {
    final result = await sl.todoRepository.toggleTodo(todo.uuid);
    if (!mounted) return;
    result.fold(
      (failure) => _showError(failure.message),
      (updatedTodo) {
        setState(() {
          final index = _todos.indexWhere((t) => t.uuid == todo.uuid);
          if (index != -1) _todos[index] = updatedTodo;
        });
      },
    );
  }

  Future<void> _deleteTodo(Todo todo) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
        ),
        title: Text('Supprimer', style: TextStyle(color: colors.foreground)),
        content: Text(
          'Voulez-vous vraiment supprimer cette tâche ?',
          style: TextStyle(color: colors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Non', style: TextStyle(color: colors.mutedForeground)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colors.destructive),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await sl.todoRepository.deleteTodo(todo.uuid);
    if (!mounted) return;
    result.fold(
      (failure) => _showError(failure.message),
      (_) {
        setState(() => _todos.removeWhere((t) => t.uuid == todo.uuid));
        _showSuccess('Tâche supprimée');
      },
    );
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateTodoSheet(
        categories: _categories,
        onCreated: (todo) {
          setState(() => _todos.insert(0, todo));
        },
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterTodoSheet(
        categories: _categories,
        currentIsDone: _filterIsDone,
        currentCategoryUuid: _filterCategoryUuid,
        onApply: (isDone, categoryUuid) {
          setState(() {
            _filterIsDone = isDone;
            _filterCategoryUuid = categoryUuid;
          });
          _loadTodos();
        },
        onClear: () {
          setState(() {
            _filterIsDone = null;
            _filterCategoryUuid = null;
          });
          _loadTodos();
        },
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool get _hasActiveFilters =>
      _filterIsDone != null || _filterCategoryUuid != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Mes tâches'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list, size: 22),
                onPressed: _showFilterSheet,
                tooltip: 'Filtres',
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: colors.primary,
        child: Icon(Icons.add, color: colors.primaryForeground),
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Chargement...');
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.destructive),
            const SizedBox(height: AppSpacing.base),
            Text(
              _error!,
              style: TextStyle(color: colors.mutedForeground),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              text: 'Réessayer',
              onPressed: _loadTodos,
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryForeground,
            ),
          ],
        ),
      );
    }

    if (_todos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist_outlined, size: 64, color: colors.mutedForeground),
            const SizedBox(height: AppSpacing.base),
            Text(
              _hasActiveFilters
                  ? 'Aucune tâche ne correspond aux filtres'
                  : 'Aucune tâche',
              style: TextStyle(fontSize: 16, color: colors.mutedForeground),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!_hasActiveFilters)
              Text(
                'Appuyez sur + pour créer une tâche',
                style: TextStyle(fontSize: 13, color: colors.mutedForeground),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTodos,
      color: colors.primary,
      backgroundColor: colors.card,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.base),
        itemCount: _todos.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _todos.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: CircularProgressIndicator(color: colors.primary),
              ),
            );
          }
          return _buildTodoCard(_todos[index], colors);
        },
      ),
    );
  }

  Widget _buildTodoCard(Todo todo, AppColors colors) {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.base),
        onLongPress: () => _deleteTodo(todo),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              GestureDetector(
                onTap: () => _toggleTodo(todo),
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: todo.isDone
                        ? colors.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: todo.isDone
                          ? colors.primary
                          : colors.border,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: todo.isDone
                      ? Icon(Icons.check, size: 16, color: colors.primaryForeground)
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: todo.isDone
                            ? colors.mutedForeground
                            : colors.foreground,
                        decoration:
                            todo.isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (todo.description != null &&
                        todo.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        todo.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.mutedForeground,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        if (todo.category != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _parseColor(todo.category!.color)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              todo.category!.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _parseColor(todo.category!.color),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        if (todo.createdAt != null)
                          Text(
                            dateFormat.format(todo.createdAt!),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.mutedForeground,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: colors.mutedForeground),
                onPressed: () => _deleteTodo(todo),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.grey;
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

/// Sheet pour créer un nouveau todo
class _CreateTodoSheet extends StatefulWidget {
  final List<TodoCategory> categories;
  final Function(Todo) onCreated;

  const _CreateTodoSheet({required this.categories, required this.onCreated});

  @override
  State<_CreateTodoSheet> createState() => _CreateTodoSheetState();
}

class _CreateTodoSheetState extends State<_CreateTodoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategoryUuid;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final request = TodoCreateRequest(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      categoryUuid: _selectedCategoryUuid,
    );

    final result = await sl.todoRepository.createTodo(request);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (todo) {
        widget.onCreated(todo);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tâche créée')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.base,
        left: AppSpacing.base,
        right: AppSpacing.base,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.base,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nouvelle tâche',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: colors.mutedForeground),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Titre',
                labelStyle: TextStyle(color: colors.mutedForeground),
                prefixIcon: Icon(Icons.title, color: colors.primary),
              ),
              style: TextStyle(color: colors.foreground),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez saisir un titre';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.base),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (facultative)',
                labelStyle: TextStyle(color: colors.mutedForeground),
                prefixIcon:
                    Icon(Icons.description_outlined, color: colors.primary),
              ),
              style: TextStyle(color: colors.foreground),
            ),
            if (widget.categories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.base),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryUuid,
                decoration: InputDecoration(
                  labelText: 'Catégorie (facultative)',
                  labelStyle: TextStyle(color: colors.mutedForeground),
                  prefixIcon: Icon(Icons.category, color: colors.primary),
                ),
                dropdownColor: colors.card,
                style: TextStyle(color: colors.foreground),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text('Aucune',
                        style: TextStyle(color: colors.mutedForeground)),
                  ),
                  ...widget.categories.map((cat) => DropdownMenuItem<String>(
                        value: cat.uuid,
                        child: Text(cat.name),
                      )),
                ],
                onChanged: (value) =>
                    setState(() => _selectedCategoryUuid = value),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              text: 'Créer la tâche',
              onPressed: _isSubmitting ? null : _submit,
              isLoading: _isSubmitting,
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryForeground,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet pour les filtres des todos
class _FilterTodoSheet extends StatefulWidget {
  final List<TodoCategory> categories;
  final bool? currentIsDone;
  final String? currentCategoryUuid;
  final Function(bool?, String?) onApply;
  final VoidCallback onClear;

  const _FilterTodoSheet({
    required this.categories,
    required this.currentIsDone,
    required this.currentCategoryUuid,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterTodoSheet> createState() => _FilterTodoSheetState();
}

class _FilterTodoSheetState extends State<_FilterTodoSheet> {
  bool? _isDone;
  String? _categoryUuid;

  @override
  void initState() {
    super.initState();
    _isDone = widget.currentIsDone;
    _categoryUuid = widget.currentCategoryUuid;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: colors.mutedForeground),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Statut',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              FilterChip(
                label: const Text('À faire'),
                selected: _isDone == false,
                onSelected: (s) =>
                    setState(() => _isDone = s ? false : null),
                selectedColor: colors.primary.withValues(alpha: 0.2),
                checkmarkColor: colors.primary,
              ),
              FilterChip(
                label: const Text('Terminé'),
                selected: _isDone == true,
                onSelected: (s) =>
                    setState(() => _isDone = s ? true : null),
                selectedColor: colors.primary.withValues(alpha: 0.2),
                checkmarkColor: colors.primary,
              ),
            ],
          ),
          if (widget.categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.base),
            Text(
              'Catégorie',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: widget.categories
                  .map((cat) => FilterChip(
                        label: Text(cat.name),
                        selected: _categoryUuid == cat.uuid,
                        onSelected: (s) => setState(
                            () => _categoryUuid = s ? cat.uuid : null),
                        selectedColor: colors.primary.withValues(alpha: 0.2),
                        checkmarkColor: colors.primary,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onClear();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.border),
                  ),
                  child: Text(
                    'Effacer',
                    style: TextStyle(color: colors.mutedForeground),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: AppButton(
                  text: 'Appliquer',
                  onPressed: () {
                    widget.onApply(_isDone, _categoryUuid);
                    Navigator.pop(context);
                  },
                  backgroundColor: colors.primary,
                  foregroundColor: colors.primaryForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

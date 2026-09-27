import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';

/// Feuille « Nouvelle tâche » : titre, description et catégorie
/// facultatives. Retourne la tâche créée, ou `null` si la feuille est
/// fermée sans enregistrer.
abstract final class TodoCreateSheet {
  static Future<Todo?> show(
    BuildContext context, {
    required List<TodoCategory> categories,
  }) {
    return AppSheet.show<Todo>(
      context,
      title: 'Nouvelle tâche',
      builder: (_) => _CreateTodoForm(categories: categories),
    );
  }
}

class _CreateTodoForm extends StatefulWidget {
  const _CreateTodoForm({required this.categories});

  final List<TodoCategory> categories;

  @override
  State<_CreateTodoForm> createState() => _CreateTodoFormState();
}

class _CreateTodoFormState extends State<_CreateTodoForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategoryUuid;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

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
      (failure) => setState(() {
        _isSubmitting = false;
        _error = failure.message;
      }),
      (todo) => Navigator.of(context).pop(todo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppFieldLabel('Titre'),
          TextFormField(
            controller: _titleController,
            autofocus: true,
            enabled: !_isSubmitting,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            style: textTheme.bodyLarge,
            decoration: const InputDecoration(hintText: 'Ce qu\'il faut faire'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Saisis un titre';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.base),
          const AppFieldLabel('Description', optional: true),
          TextFormField(
            controller: _descriptionController,
            enabled: !_isSubmitting,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: textTheme.bodyLarge,
            decoration: const InputDecoration(hintText: 'Précisions utiles'),
          ),
          if (widget.categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.base),
            const AppFieldLabel('Catégorie', optional: true),
            AppFilterChips<String?>(
              segments: [
                const AppSegment<String?>(value: null, label: 'Aucune'),
                for (final category in widget.categories)
                  AppSegment<String?>(
                    value: category.uuid,
                    label: category.name,
                  ),
              ],
              selected: _selectedCategoryUuid,
              onChanged: (value) =>
                  setState(() => _selectedCategoryUuid = value),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.base),
            AppAlert(variant: AlertVariant.destructive, description: _error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: 'Créer la tâche',
            icon: Icons.add_rounded,
            size: ButtonSize.lg,
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 52,
            child: TextButton(
              onPressed:
                  _isSubmitting ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: colors.foreground),
              child: const Text('Annuler'),
            ),
          ),
        ],
      ),
    );
  }
}

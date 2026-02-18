import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Widget de sélection avec recherche intégrée
///
/// Un dropdown personnalisé qui ouvre un bottom sheet avec une barre
/// de recherche et une liste filtrable d'éléments.
class AppSearchableSelect<T> extends StatelessWidget {
  /// Liste des éléments à afficher
  final List<T> items;

  /// Élément actuellement sélectionné
  final T? selectedItem;

  /// Callback appelé lors de la sélection
  final void Function(T?) onChanged;

  /// Fonction pour obtenir le label d'un élément
  final String Function(T) itemLabel;

  /// Fonction pour obtenir un sous-titre optionnel
  final String Function(T)? itemSubtitle;

  /// Fonction pour obtenir une icône optionnelle
  final IconData Function(T)? itemIcon;

  /// Placeholder quand aucun élément n'est sélectionné
  final String placeholder;

  /// Titre du bottom sheet
  final String sheetTitle;

  /// Placeholder de la barre de recherche
  final String searchHint;

  /// Message quand aucun résultat
  final String emptyMessage;

  /// Validation du champ
  final String? Function(T?)? validator;

  /// Si le champ est activé
  final bool enabled;

  /// Icône préfixe du champ
  final IconData? prefixIcon;

  const AppSearchableSelect({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onChanged,
    required this.itemLabel,
    this.itemSubtitle,
    this.itemIcon,
    this.placeholder = 'Sélectionner',
    this.sheetTitle = 'Sélectionner',
    this.searchHint = 'Rechercher...',
    this.emptyMessage = 'Aucun résultat',
    this.validator,
    this.enabled = true,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FormField<T>(
      initialValue: selectedItem,
      validator: validator,
      builder: (field) {
        final showError = field.hasError && field.errorText != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: enabled
                  ? () => _showSelectionSheet(context)
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.bgTertiary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: showError
                        ? colors.error
                        : colors.borderPrimary,
                    width: showError ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    if (prefixIcon != null) ...[
                      Icon(
                        prefixIcon,
                        size: 20,
                        color: enabled
                            ? colors.textSecondary
                            : colors.textMuted,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: selectedItem != null
                          ? _buildSelectedContent(colors)
                          : Text(
                              placeholder,
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: enabled
                          ? colors.textSecondary
                          : colors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (showError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 14),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    color: colors.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSelectedContent(AppColors colors) {
    final item = selectedItem as T;
    final subtitle = itemSubtitle?.call(item);
    final icon = itemIcon?.call(item);

    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                itemLabel(item),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SelectionSheet<T>(
        items: items,
        selectedItem: selectedItem,
        onChanged: (value) {
          onChanged(value);
          Navigator.pop(context);
        },
        itemLabel: itemLabel,
        itemSubtitle: itemSubtitle,
        itemIcon: itemIcon,
        title: sheetTitle,
        searchHint: searchHint,
        emptyMessage: emptyMessage,
      ),
    );
  }
}

/// Bottom sheet avec recherche et liste
class _SelectionSheet<T> extends StatefulWidget {
  final List<T> items;
  final T? selectedItem;
  final void Function(T?) onChanged;
  final String Function(T) itemLabel;
  final String Function(T)? itemSubtitle;
  final IconData Function(T)? itemIcon;
  final String title;
  final String searchHint;
  final String emptyMessage;

  const _SelectionSheet({
    required this.items,
    required this.selectedItem,
    required this.onChanged,
    required this.itemLabel,
    this.itemSubtitle,
    this.itemIcon,
    required this.title,
    required this.searchHint,
    required this.emptyMessage,
  });

  @override
  State<_SelectionSheet<T>> createState() => _SelectionSheetState<T>();
}

class _SelectionSheetState<T> extends State<_SelectionSheet<T>> {
  final _searchController = TextEditingController();
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final label = widget.itemLabel(item).toLowerCase();
          final subtitle = widget.itemSubtitle?.call(item).toLowerCase() ?? '';
          return label.contains(query) || subtitle.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.75,
      ),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.borderSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.textSecondary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
            ),
            child: TextField(
              controller: _searchController,
              autofocus: widget.items.length > 5,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: colors.textSecondary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                        },
                        icon: Icon(
                          Icons.clear_rounded,
                          color: colors.textSecondary,
                          size: 20,
                        ),
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Divider
          Divider(
            height: 1,
            color: colors.borderPrimary,
          ),

          // List
          Flexible(
            child: _filteredItems.isEmpty
                ? _buildEmptyState(colors)
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final isSelected = item == widget.selectedItem;
                      return _buildItem(item, isSelected, colors);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: colors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.emptyMessage,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(T item, bool isSelected, AppColors colors) {
    final subtitle = widget.itemSubtitle?.call(item);
    final icon = widget.itemIcon?.call(item);

    return InkWell(
      onTap: () => widget.onChanged(item),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        color: isSelected
            ? colors.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withValues(alpha: 0.2)
                      : colors.bgTertiary,
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? colors.primary : colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.itemLabel(item),
                    style: TextStyle(
                      color: isSelected ? colors.primary : colors.textPrimary,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                color: colors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

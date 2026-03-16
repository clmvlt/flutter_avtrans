import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Widget de sélection avec recherche - style shadcn/ui
class AppSearchableSelect<T> extends StatelessWidget {
  final List<T> items;
  final T? selectedItem;
  final void Function(T?) onChanged;
  final String Function(T) itemLabel;
  final String Function(T)? itemSubtitle;
  final IconData Function(T)? itemIcon;
  final String placeholder;
  final String sheetTitle;
  final String searchHint;
  final String emptyMessage;
  final String? Function(T?)? validator;
  final bool enabled;
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
              onTap: enabled ? () => _showSelectionSheet(context) : null,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: showError ? colors.destructive : colors.input,
                    width: showError ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    if (prefixIcon != null) ...[
                      Icon(
                        prefixIcon,
                        size: 18,
                        color: colors.mutedForeground,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: selectedItem != null
                          ? _buildSelectedContent(colors)
                          : Text(
                              placeholder,
                              style: TextStyle(
                                color: colors.mutedForeground,
                                fontSize: 14,
                              ),
                            ),
                    ),
                    Icon(
                      Icons.unfold_more_rounded,
                      size: 18,
                      color: colors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
            if (showError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    color: colors.destructive,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
          Icon(icon, size: 16, color: colors.primary),
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
                  color: colors.foreground,
                  fontSize: 14,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.mutedForeground,
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
      constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        border: Border(
          top: BorderSide(color: colors.border),
          left: BorderSide(color: colors.border),
          right: BorderSide(color: colors.border),
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
              color: colors.muted,
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
                      color: colors.foreground,
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.mutedForeground,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.muted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: TextField(
              controller: _searchController,
              autofocus: widget.items.length > 5,
              style: TextStyle(
                fontSize: 14,
                color: colors.foreground,
              ),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: colors.mutedForeground,
                  size: 18,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () => _searchController.clear(),
                        icon: Icon(
                          Icons.clear_rounded,
                          color: colors.mutedForeground,
                          size: 16,
                        ),
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
          Container(height: 1, color: colors.border),

          // List
          Flexible(
            child: _filteredItems.isEmpty
                ? _buildEmptyState(colors)
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
            size: 40,
            color: colors.mutedForeground,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.emptyMessage,
            style: TextStyle(
              color: colors.mutedForeground,
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
        color: isSelected ? colors.accent : Colors.transparent,
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withValues(alpha: 0.1)
                      : colors.muted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? colors.primary : colors.mutedForeground,
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
                      color: colors.foreground,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.mutedForeground,
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
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

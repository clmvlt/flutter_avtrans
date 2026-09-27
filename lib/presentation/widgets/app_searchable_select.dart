import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_list_row.dart';
import 'app_picker_field.dart';

/// Champ de sélection avec recherche : un [AppPickerField] qui ouvre une
/// feuille (recherche + liste de lignes). Recherche sur le libellé et la
/// sous-ligne.
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

  /// Libellé au-dessus du champ.
  final String? label;
  final bool optional;

  /// Une croix efface la sélection (`onChanged(null)`).
  final bool clearable;

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
    this.searchHint = 'Rechercher…',
    this.emptyMessage = 'Aucun résultat',
    this.validator,
    this.enabled = true,
    this.prefixIcon,
    this.label,
    this.optional = false,
    this.clearable = false,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      // La valeur vit chez le parent : le FormField ne sert qu'à valider.
      key: ValueKey(selectedItem),
      initialValue: selectedItem,
      validator: validator,
      builder: (field) {
        final item = selectedItem;
        return AppPickerField(
          label: label,
          optional: optional,
          value: item == null ? null : itemLabel(item),
          subtitle: item == null ? null : itemSubtitle?.call(item),
          placeholder: placeholder,
          icon: prefixIcon ?? (item == null ? null : itemIcon?.call(item)),
          enabled: enabled,
          errorText: field.errorText,
          onTap: () => showAppSelectSheet<T>(
            context,
            title: sheetTitle,
            items: items,
            selectedItem: selectedItem,
            itemLabel: itemLabel,
            itemSubtitle: itemSubtitle,
            itemIcon: itemIcon,
            searchHint: searchHint,
            emptyMessage: emptyMessage,
          ).then((picked) {
            if (picked != null) onChanged(picked);
          }),
          onClear: clearable ? () => onChanged(null) : null,
        );
      },
    );
  }
}

/// Ouvre la feuille de sélection avec recherche et retourne l'élément choisi
/// (`null` si fermée sans choix).
Future<T?> showAppSelectSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) itemLabel,
  T? selectedItem,
  String Function(T)? itemSubtitle,
  IconData Function(T)? itemIcon,
  Color Function(T)? itemIconColor,
  String searchHint = 'Rechercher…',
  String emptyMessage = 'Aucun résultat',
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: context.colors.surfaceElevated,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => _SelectionSheet<T>(
      items: items,
      selectedItem: selectedItem,
      itemLabel: itemLabel,
      itemSubtitle: itemSubtitle,
      itemIcon: itemIcon,
      itemIconColor: itemIconColor,
      title: title,
      searchHint: searchHint,
      emptyMessage: emptyMessage,
    ),
  );
}

class _SelectionSheet<T> extends StatefulWidget {
  final List<T> items;
  final T? selectedItem;
  final String Function(T) itemLabel;
  final String Function(T)? itemSubtitle;
  final IconData Function(T)? itemIcon;
  final Color Function(T)? itemIconColor;
  final String title;
  final String searchHint;
  final String emptyMessage;

  const _SelectionSheet({
    required this.items,
    required this.selectedItem,
    required this.itemLabel,
    this.itemSubtitle,
    this.itemIcon,
    this.itemIconColor,
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
    final textTheme = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final showSearch = widget.items.length > 5;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.sm,
                  AppSpacing.screen,
                  AppSpacing.md,
                ),
                child: Text(widget.title, style: textTheme.titleLarge),
              ),
              if (showSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    0,
                    AppSpacing.screen,
                    AppSpacing.sm,
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: false,
                    textInputAction: TextInputAction.search,
                    style: textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: _searchController.clear,
                              tooltip: 'Effacer',
                              icon: const Icon(Icons.close_rounded, size: 18),
                            )
                          : null,
                    ),
                  ),
                ),
              Flexible(
                child: _filteredItems.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          widget.emptyMessage,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge
                              ?.copyWith(color: colors.mutedForeground),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm,
                          0,
                          AppSpacing.sm,
                          AppSpacing.base,
                        ),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final isSelected = item == widget.selectedItem;
                          return AppListRow(
                            title: widget.itemLabel(item),
                            subtitle: widget.itemSubtitle?.call(item),
                            icon: widget.itemIcon?.call(item),
                            iconColor: widget.itemIconColor?.call(item) ??
                                (isSelected
                                    ? colors.primary
                                    : colors.mutedForeground),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_rounded,
                                    color: colors.primary,
                                    size: 22,
                                  )
                                : null,
                            showChevron: false,
                            onTap: () => Navigator.of(context).pop(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

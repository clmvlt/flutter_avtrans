import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/entretien_model.dart';
import '../../../widgets/widgets.dart';

/// Ouvre le choix d'un type d'entretien : types rangés par dossier (les non
/// classés en dernier), recherche sur le nom, la description et le dossier.
/// Retourne le type choisi, ou `null` si la feuille est fermée.
Future<TypeEntretien?> showTypeEntretienPicker(
  BuildContext context, {
  required List<TypeEntretien> types,
  TypeEntretien? selected,
  String title = 'Type d\'entretien',
}) {
  return showModalBottomSheet<TypeEntretien>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: context.colors.surfaceElevated,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => _TypePickerSheet(
      types: types,
      selected: selected,
      title: title,
    ),
  );
}

class _TypePickerSheet extends StatefulWidget {
  const _TypePickerSheet({
    required this.types,
    required this.selected,
    required this.title,
  });

  final List<TypeEntretien> types;
  final TypeEntretien? selected;
  final String title;

  @override
  State<_TypePickerSheet> createState() => _TypePickerSheetState();
}

class _TypePickerSheetState extends State<_TypePickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Groupes (nom du dossier → types), dossiers triés, non classés à la fin.
  List<(String, List<TypeEntretien>)> _groups(List<TypeEntretien> types) {
    final byDossier = <String, List<TypeEntretien>>{};
    final unclassified = <TypeEntretien>[];
    for (final t in types) {
      final d = t.dossier;
      if (d == null) {
        unclassified.add(t);
      } else {
        byDossier.putIfAbsent(d.nom, () => []).add(t);
      }
    }
    final names = byDossier.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      for (final n in names) (n, byDossier[n]!),
      if (unclassified.isNotEmpty) ('Non classés', unclassified),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.types
        : widget.types.where((t) {
            return t.nom.toLowerCase().contains(q) ||
                (t.description?.toLowerCase().contains(q) ?? false) ||
                (t.dossier?.nom.toLowerCase().contains(q) ?? false);
          }).toList();
    final groups = _groups(filtered);

    final rows = <Widget>[];
    for (final (name, types) in groups) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.base,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                name == 'Non classés'
                    ? Icons.folder_open_rounded
                    : Icons.folder_rounded,
                size: 16,
                color: colors.mutedForeground,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                name.toUpperCase(),
                style: textTheme.labelSmall?.copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
        ),
      );
      for (final t in types) {
        final isSelected = t.id == widget.selected?.id;
        rows.add(
          AppListRow(
            title: t.nom,
            subtitle: t.description,
            subtitleMaxLines: 1,
            icon: Icons.build_rounded,
            iconColor: isSelected ? colors.primary : colors.mutedForeground,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            trailing: isSelected
                ? Icon(Icons.check_rounded, color: colors.primary, size: 22)
                : null,
            showChevron: false,
            onTap: () => Navigator.of(context).pop(t),
          ),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  style: textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un type ou un dossier',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              Flexible(
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          widget.types.isEmpty
                              ? 'Aucun type d\'entretien. Crée-en un depuis « Types d\'entretien ».'
                              : 'Aucun type ne correspond.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge
                              ?.copyWith(color: colors.mutedForeground),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm,
                          0,
                          AppSpacing.sm,
                          AppSpacing.base,
                        ),
                        children: rows,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

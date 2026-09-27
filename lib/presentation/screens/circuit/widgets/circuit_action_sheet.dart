import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_sheet.dart';
import 'tour_widgets.dart';

/// Un choix d'une feuille d'actions.
class CircuitSheetAction<T> {
  const CircuitSheetAction({
    required this.value,
    required this.icon,
    required this.label,
    this.subtitle,
    this.destructive = false,
  });

  /// Valeur renvoyée quand ce choix est touché.
  final T value;
  final IconData icon;
  final String label;
  final String? subtitle;

  /// Action sans retour (suppression) : icône et libellé en rouge.
  final bool destructive;
}

/// Feuille d'actions (remplace les menus « ⋮ » et les listes de choix) :
/// des lignes dans une carte. Renvoie la valeur du choix touché, ou `null`
/// si la feuille est fermée sans choix.
Future<T?> showCircuitActionSheet<T>(
  BuildContext context, {
  required String title,
  required List<CircuitSheetAction<T>> actions,
}) {
  return AppSheet.show<T>(
    context,
    title: title,
    builder: (ctx) => _ActionList<T>(actions: actions),
  );
}

class _ActionList<T> extends StatelessWidget {
  const _ActionList({required this.actions});

  final List<CircuitSheetAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return RowsCard(
      children: [
        for (final a in actions)
          AppListRow(
            icon: a.icon,
            iconColor: a.destructive ? colors.destructive : colors.primary,
            title: a.label,
            titleStyle: a.destructive
                ? textTheme.titleSmall?.copyWith(color: colors.destructive)
                : null,
            subtitle: a.subtitle,
            showChevron: false,
            onTap: () => Navigator.of(context).pop(a.value),
          ),
      ],
    );
  }
}

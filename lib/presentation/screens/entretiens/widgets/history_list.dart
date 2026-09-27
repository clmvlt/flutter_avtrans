import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/entretien_model.dart';
import '../../../widgets/widgets.dart';
import '../logic/entretien_history_controller.dart';
import 'entretien_tile.dart';

/// Morceaux de l'historique paginé, à composer dans un [AppListView] :
/// états (chargement, erreur, vide) en en-tête, une ligne par entretien
/// (avec l'intitulé du mois quand on trie par date), pied de pagination.
abstract final class HistoryList {
  /// États à placer sous la barre d'outils. Vide quand la liste s'affiche.
  static List<Widget> states(
    EntretienHistoryController c, {
    required String emptyMessage,
    String? emptyDetail,
  }) {
    if (!c.isLoaded && c.isLoading) {
      return const [EntretienListSkeleton()];
    }
    if (c.error != null && c.items.isEmpty) {
      return [AppErrorState(message: c.error!, onRetry: c.refresh)];
    }
    if (c.isLoaded && c.items.isEmpty && !c.isLoading) {
      return [
        AppEmptyCard(
          icon: Icons.build_outlined,
          message: emptyMessage,
          detail: emptyDetail,
        ),
      ];
    }
    return const [];
  }

  /// Nombre de lignes à construire (0 tant que les états occupent la place).
  static int itemCount(EntretienHistoryController c) =>
      c.error != null && c.items.isEmpty ? 0 : c.items.length;

  /// Une ligne, précédée de l'intitulé du mois au changement de mois.
  static Widget item(
    BuildContext context,
    EntretienHistoryController c,
    int index, {
    required bool showVehicle,
    required ValueChanged<Entretien> onTap,
  }) {
    final items = c.items;
    final e = items[index];
    final tile = EntretienTile(
      key: ValueKey(e.id),
      entretien: e,
      showVehicle: showVehicle,
      onTap: () => onTap(e),
    );

    if (c.query.sort != EntretienSort.date) return tile;
    final month = DateTime(e.dateEntretien.year, e.dateEntretien.month);
    final previous = index == 0 ? null : items[index - 1].dateEntretien;
    final newMonth = previous == null ||
        previous.year != month.year ||
        previous.month != month.month;
    if (!newMonth) return tile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xs,
            top: index == 0 ? 0 : AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            DisplayFormat.monthYear(month).toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(letterSpacing: 0.8),
          ),
        ),
        tile,
      ],
    );
  }

  /// Pied : chargement de la suite, « Réessayer », ou fin de liste.
  static Widget? footer(EntretienHistoryController c) {
    if (c.items.isEmpty) return null;
    return HistoryFooter(
      loadingMore: c.isLoadingMore,
      hasMore: c.hasMore,
      total: c.total,
      error: c.loadMoreError,
      onRetry: c.loadMore,
    );
  }

  /// Écouteur à brancher sur le `ScrollController` de la liste : charge la
  /// page suivante à l'approche de la fin.
  static VoidCallback infiniteScroll(
    ScrollController scroll,
    EntretienHistoryController c,
  ) {
    return () {
      if (!scroll.hasClients) return;
      if (scroll.position.extentAfter < 600 && c.loadMoreError == null) {
        c.loadMore();
      }
    };
  }
}

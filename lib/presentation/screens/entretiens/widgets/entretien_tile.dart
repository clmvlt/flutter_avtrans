import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/entretien_model.dart';
import '../../../widgets/widgets.dart';

/// Un entretien de l'historique : type en titre, « immat · date · km » en
/// sous-ligne, coût à droite, trombone s'il y a des fichiers.
class EntretienTile extends StatelessWidget {
  const EntretienTile({
    super.key,
    required this.entretien,
    required this.onTap,
    this.showVehicle = true,
  });

  final Entretien entretien;
  final VoidCallback onTap;

  /// Afficher l'immatriculation (inutile sur la page d'un véhicule).
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final e = entretien;

    final subtitle = [
      if (showVehicle && e.vehiculeImmat != null) e.vehiculeImmat!.toUpperCase(),
      DisplayFormat.dateCompact(e.dateEntretien),
      if (e.kilometrage != null) DisplayFormat.km(e.kilometrage!),
    ].join(' · ');

    return AppCard(
      padding: EdgeInsets.zero,
      child: AppListRow(
        title: e.typeLabel,
        subtitle: subtitle,
        icon: Icons.build_rounded,
        iconColor: colors.domainVehicule,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (e.cout != null)
              Text(
                DisplayFormat.euros(e.cout!),
                style: textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            if (e.files.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.attach_file_rounded,
                      size: 14,
                      color: colors.mutedForeground,
                    ),
                    Text('${e.files.length}', style: textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ),
        showChevron: true,
        semanticsLabel: '${e.typeLabel}. $subtitle'
            '${e.cout != null ? '. ${DisplayFormat.euros(e.cout!)}' : ''}'
            '${e.files.isNotEmpty ? '. ${DisplayFormat.plural(e.files.length, 'fichier')}' : ''}',
      ),
    );
  }
}

/// Squelette d'une liste d'entretiens.
class EntretienListSkeleton extends StatelessWidget {
  const EntretienListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          const AppListSkeleton(rows: 1),
        ],
      ],
    );
  }
}

/// Pied de liste paginée : indicateur, « Réessayer », ou fin de liste.
class HistoryFooter extends StatelessWidget {
  const HistoryFooter({
    super.key,
    required this.loadingMore,
    required this.hasMore,
    required this.total,
    this.error,
    required this.onRetry,
  });

  final bool loadingMore;
  final bool hasMore;
  final int total;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    if (error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Charger la suite'),
        ),
      );
    }
    if (loadingMore || hasMore) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
        ),
      );
    }
    return Center(
      child: Text(
        total > 1 ? 'Les $total entretiens sont affichés' : '',
        style: textTheme.bodySmall,
      ),
    );
  }
}

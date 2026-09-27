import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/widgets.dart';

// Blocs communs aux feuilles et listes des pages « demandes » (absences,
// acomptes, couchettes). Candidats à rejoindre le kit partagé.

/// Bloc de texte libre (motif, raison) sous un récapitulatif : fond enfoncé,
/// icône discrète, libellé puis texte.
class NoteBlock extends StatelessWidget {
  const NoteBlock({
    super.key,
    required this.label,
    required this.text,
    this.icon = Icons.notes_rounded,
    this.iconColor,
  });

  final String label;
  final String text;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor ?? colors.mutedForeground),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colors.foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Action destructive d'une feuille de détail (annuler, supprimer) : bouton
/// calme au texte rouge, protégé ensuite par une feuille de confirmation.
class SheetDangerAction extends StatelessWidget {
  const SheetDangerAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.hint,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// Phrase discrète sous le bouton (« Possible tant que… »).
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          text: label,
          icon: icon,
          onPressed: onPressed,
          size: ButtonSize.lg,
          variant: ButtonVariant.secondary,
          foregroundColor: colors.destructive,
        ),
        if (hint != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Pied de liste pendant le chargement de la page suivante.
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement de la suite',
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: context.colors.primary,
          ),
        ),
      ),
    );
  }
}

/// Squelette d'une page de demandes : hero, segments optionnels, puis
/// calendrier ou liste.
class RequestsSkeleton extends StatelessWidget {
  const RequestsSkeleton({
    super.key,
    this.showFigure = false,
    this.showSegmented = false,
    this.showCalendar = false,
  });

  final bool showFigure;
  final bool showSegmented;
  final bool showCalendar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppHeroSkeleton(showFigure: showFigure),
        const SizedBox(height: AppSpacing.lg),
        if (showSegmented) ...const [
          AppSkeleton(height: 48, borderRadius: AppRadius.md + 4),
          SizedBox(height: AppSpacing.lg),
        ],
        if (showCalendar)
          const AppSkeleton(height: 360, borderRadius: AppRadius.lg)
        else ...const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: AppSkeleton(width: 120, height: 16),
          ),
          SizedBox(height: AppSpacing.md),
          AppListSkeleton(rows: 4),
        ],
      ],
    );
  }
}

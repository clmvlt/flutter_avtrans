import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../widgets/app_card.dart';
import '../pointage_controller.dart';
import 'pointage_layout.dart';
import 'pointage_status.dart';

/// Une ligne de la carte « Avant de pointer » : le titre est l'action.
@immutable
class PrerequisiteItem {
  const PrerequisiteItem({
    required this.id,
    required this.blocking,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String id;

  /// `true` = obligatoire avant de démarrer ; `false` = conseillé.
  final bool blocking;
  final IconData icon;
  final String title;

  /// Le « pourquoi » : « Obligatoire · chaque jour travaillé ».
  final String subtitle;
  final VoidCallback onTap;
}

/// Callbacks d'action de la carte.
class PrereqActions {
  const PrereqActions({
    required this.onSign,
    required this.onKilometrage,
    required this.onRapport,
  });

  final VoidCallback onSign;
  final VoidCallback onKilometrage;
  final VoidCallback onRapport;
}

/// Lignes en attente uniquement (le silence est la récompense), bloquantes
/// d'abord dans l'ordre métier : signature, kilométrage, rapport requis, puis
/// rapport conseillé. Le GPS n'est pas ici : il conditionne toutes les
/// actions et vit dans le dock.
List<PrerequisiteItem> buildPrerequisiteItems({
  required PointagePrerequisites prerequisites,
  required DateTime now,
  required PrereqActions actions,
}) {
  final p = prerequisites;
  final items = <PrerequisiteItem>[];

  if (p.signatureRequired) {
    final heures = p.heuresLastMonth;
    items.add(PrerequisiteItem(
      id: 'signature',
      blocking: true,
      icon: Icons.draw_rounded,
      title: 'Signer mes heures',
      subtitle: heures != null && heures > 0
          ? 'Obligatoire · ${TimeFormat.hoursDecimal(heures)} du mois dernier à signer'
          : 'Obligatoire · heures du mois dernier à signer',
      onTap: actions.onSign,
    ));
  }

  if (p.kilometrageRequired) {
    items.add(PrerequisiteItem(
      id: 'kilometrage',
      blocking: true,
      icon: Icons.speed_rounded,
      title: 'Saisir le kilométrage',
      subtitle: 'Obligatoire · chaque jour travaillé',
      onTap: actions.onKilometrage,
    ));
  }

  if (p.rapportRequired || p.rapportWarning) {
    final last = p.lastRapportAt;
    final days = last == null ? null : now.difference(last).inDays;
    items.add(PrerequisiteItem(
      id: 'rapport',
      blocking: p.rapportRequired,
      icon: Icons.description_rounded,
      title: 'Faire le rapport véhicule',
      subtitle: p.rapportRequired
          ? (days == null
              ? 'Obligatoire · aucun rapport enregistré'
              : 'Obligatoire · dernier rapport il y a $days j')
          : 'Conseillé · aucun rapport cette semaine',
      onTap: actions.onRapport,
    ));
  }

  return items;
}

/// Carte « AVANT DE POINTER » : fond ambre doux si une ligne bloque, bleu
/// doux si tout est seulement conseillé. Absente quand rien n'est en attente.
class PrerequisiteCard extends StatelessWidget {
  const PrerequisiteCard({super.key, required this.items});

  final List<PrerequisiteItem> items;

  bool get hasBlocking => items.any((i) => i.blocking);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    if (items.isEmpty) return const SizedBox.shrink();

    final headerColor =
        hasBlocking ? PointageColors.onWarningMuted(colors) : colors.info;

    return AppCard(
      elevation: AppCardElevation.flat,
      color: hasBlocking ? colors.warningMuted : colors.infoMuted,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                hasBlocking ? Icons.lock_rounded : Icons.info_outline_rounded,
                size: 18,
                color: headerColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'AVANT DE POINTER',
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.8,
                  color: headerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in items)
            PrerequisiteRow(key: ValueKey(item.id), item: item),
        ],
      ),
    );
  }
}

/// Une ligne de la carte (56 dp min) : boîte d'icône, titre, pourquoi, chevron.
class PrerequisiteRow extends StatelessWidget {
  const PrerequisiteRow({super.key, required this.item});

  final PrerequisiteItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final accent = item.blocking ? colors.warning : colors.info;

    return Semantics(
      button: true,
      label: '${item.title}. ${item.subtitle}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: PointageLayout.rowMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: PointageLayout.prereqIconBoxSize,
                    height: PointageLayout.prereqIconBoxSize,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(item.icon, size: 22, color: accent),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.title, style: textTheme.titleSmall),
                        const SizedBox(height: 1),
                        Text(
                          item.subtitle,
                          style: textTheme.bodySmall
                              ?.copyWith(color: colors.foreground),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

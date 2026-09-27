import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/ypsium_spooler_entry.dart';
import '../../../widgets/widgets.dart';

/// Icône, accent et mot d'état d'un envoi de la file.
(IconData, Color, String) ypsiumSpoolerVisual(
  SpoolerEntryStatus status,
  AppColors colors,
) =>
    switch (status) {
      SpoolerEntryStatus.pending => (
          Icons.schedule_rounded,
          colors.warning,
          'En attente',
        ),
      SpoolerEntryStatus.sending => (
          Icons.sync_rounded,
          colors.info,
          'Envoi…',
        ),
      SpoolerEntryStatus.failed => (
          Icons.error_outline_rounded,
          colors.destructive,
          'Erreur',
        ),
    };

/// Carte « Envois en attente » de l'accueil : n'apparaît que s'il reste
/// des envois hors ligne, et mène à la file d'envoi.
class YpsiumSpoolerCallout extends StatelessWidget {
  const YpsiumSpoolerCallout({
    super.key,
    required this.pendingCount,
    required this.isProcessing,
    required this.onOpen,
  });

  final int pendingCount;
  final bool isProcessing;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final notSent = pendingCount > 1 ? 'pas encore partis' : 'pas encore parti';

    return AppCalloutCard(
      title: 'Envois en attente',
      tone: AppCalloutTone.warning,
      icon: Icons.outbox_rounded,
      children: [
        AppListRow(
          icon: isProcessing ? Icons.sync_rounded : Icons.outbox_rounded,
          iconColor: colors.warning,
          title: 'Voir la file d\'envoi',
          subtitle: isProcessing
              ? 'Envoi en cours…'
              : '${DisplayFormat.plural(pendingCount, 'envoi')} $notSent',
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          onTap: onOpen,
        ),
      ],
    );
  }
}

/// Carte hero de la file d'envoi : nombre d'envois, état du traitement et
/// compteurs par statut.
class YpsiumSpoolerHero extends StatelessWidget {
  const YpsiumSpoolerHero({
    super.key,
    required this.entries,
    required this.isProcessing,
  });

  final List<YpsiumSpoolerEntry> entries;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    int count(SpoolerEntryStatus s) => entries.where((e) => e.status == s).length;
    final pending = count(SpoolerEntryStatus.pending);
    final sending = count(SpoolerEntryStatus.sending);
    final failed = count(SpoolerEntryStatus.failed);

    final (icon, accent) = isProcessing
        ? (Icons.sync_rounded, colors.info)
        : failed > 0
            ? (Icons.error_outline_rounded, colors.destructive)
            : (Icons.outbox_rounded, colors.warning);

    AppMetric metric(String label, int value) => AppMetric(
          label: label,
          value: '$value',
          valueColor: value == 0 ? colors.mutedForeground : null,
        );

    return AppHeroCard(
      icon: icon,
      accent: accent,
      title: '${DisplayFormat.plural(entries.length, 'envoi')} en attente',
      subtitle: isProcessing
          ? 'Envoi en cours…'
          : 'Nouvel essai automatique régulier',
      trailing: isProcessing
          ? SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.info,
                ),
              ),
            )
          : null,
      child: AppMetricRow(
        metrics: [
          metric('En attente', pending),
          metric('En cours', sending),
          metric('En erreur', failed),
        ],
      ),
    );
  }
}

/// Ligne d'un envoi : boîte d'icône du statut, libellé, statut · heure ·
/// tentatives, dernière erreur, bouton de suppression.
class YpsiumSpoolerRow extends StatelessWidget {
  const YpsiumSpoolerRow({
    super.key,
    required this.entry,
    required this.onDelete,
  });

  final YpsiumSpoolerEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final (icon, accent, statusLabel) = ypsiumSpoolerVisual(entry.status, colors);
    final time = DateFormat('HH:mm:ss').format(entry.createdAt);
    final tries = entry.retryCount > 0
        ? ' · ${DisplayFormat.plural(entry.retryCount, 'tentative')}'
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBox(icon: icon, color: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text('$statusLabel · $time$tries', style: textTheme.bodySmall),
                if (entry.lastError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: colors.destructive,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            entry.lastError!,
                            style: textTheme.bodySmall
                                ?.copyWith(color: colors.foreground),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Supprimer cet envoi',
            color: colors.mutedForeground,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

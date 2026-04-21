import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ypsium_spooler_entry.dart';
import '../../widgets/widgets.dart';

/// Écran de gestion du spooler Ypsium
/// Permet de voir, renvoyer et supprimer les requêtes en attente
class YpsiumSpoolerScreen extends StatefulWidget {
  const YpsiumSpoolerScreen({super.key});

  @override
  State<YpsiumSpoolerScreen> createState() => _YpsiumSpoolerScreenState();
}

class _YpsiumSpoolerScreenState extends State<YpsiumSpoolerScreen> {
  @override
  void initState() {
    super.initState();
    sl.ypsiumSpoolerService.addListener(_onSpoolerChanged);
  }

  @override
  void dispose() {
    sl.ypsiumSpoolerService.removeListener(_onSpoolerChanged);
    super.dispose();
  }

  void _onSpoolerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spooler = sl.ypsiumSpoolerService;
    final entries = spooler.entries;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.foreground, size: 20),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Spooler',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: colors.foreground,
              ),
        ),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep, size: 22, color: colors.destructive),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => _confirmClearAll(context, colors),
              tooltip: 'Vider le spooler',
            ),
        ],
      ),
      body: entries.isEmpty
          ? _buildEmpty(colors)
          : Column(
              children: [
                _buildHeader(colors, entries, spooler.isProcessing),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        _buildEntryCard(colors, entries[index]),
                  ),
                ),
                _buildBottomBar(colors, spooler),
              ],
            ),
    );
  }

  Widget _buildEmpty(AppColors colors) {
    return const Center(
      child: AppEmptyState(
        icon: Icons.check_circle_outline,
        title: 'Spooler vide',
        subtitle: 'Toutes les requêtes ont été envoyées',
      ),
    );
  }

  Widget _buildHeader(
      AppColors colors, List<YpsiumSpoolerEntry> entries, bool isProcessing) {
    final pending =
        entries.where((e) => e.status == SpoolerEntryStatus.pending).length;
    final failed =
        entries.where((e) => e.status == SpoolerEntryStatus.failed).length;
    final sending =
        entries.where((e) => e.status == SpoolerEntryStatus.sending).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.base, AppSpacing.base, 0),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isProcessing
                  ? colors.info.withValues(alpha: 0.1)
                  : colors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: isProcessing
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.info,
                    ),
                  )
                : Icon(Icons.outbox, size: 22, color: colors.warning),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entries.length} requête${entries.length > 1 ? 's' : ''} en file',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.foreground,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    if (pending > 0)
                      AppBadge(
                          text: '$pending en attente',
                          variant: BadgeVariant.secondary),
                    if (sending > 0)
                      AppBadge(
                          text: '$sending en cours',
                          variant: BadgeVariant.primary),
                    if (failed > 0)
                      AppBadge(
                          text: '$failed en erreur',
                          variant: BadgeVariant.destructive),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(AppColors colors, YpsiumSpoolerEntry entry) {
    final statusColor = switch (entry.status) {
      SpoolerEntryStatus.pending => colors.warning,
      SpoolerEntryStatus.sending => colors.info,
      SpoolerEntryStatus.failed => colors.destructive,
    };

    final statusLabel = switch (entry.status) {
      SpoolerEntryStatus.pending => 'En attente',
      SpoolerEntryStatus.sending => 'Envoi...',
      SpoolerEntryStatus.failed => 'Erreur',
    };

    final statusIcon = switch (entry.status) {
      SpoolerEntryStatus.pending => Icons.schedule,
      SpoolerEntryStatus.sending => Icons.sync,
      SpoolerEntryStatus.failed => Icons.error_outline,
    };

    final timeStr = DateFormat('HH:mm:ss').format(entry.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, size: 16, color: statusColor),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    entry.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.foreground,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppBadge(
                  text: statusLabel,
                  variant: switch (entry.status) {
                    SpoolerEntryStatus.pending => BadgeVariant.warning,
                    SpoolerEntryStatus.sending => BadgeVariant.primary,
                    SpoolerEntryStatus.failed => BadgeVariant.destructive,
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: colors.mutedForeground),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  timeStr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.mutedForeground,
                      ),
                ),
                if (entry.retryCount > 0) ...[
                  const SizedBox(width: AppSpacing.md),
                  Icon(Icons.replay, size: 14, color: colors.mutedForeground),
                  const SizedBox(width: 2),
                  Text(
                    '${entry.retryCount} tentative${entry.retryCount > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.mutedForeground,
                        ),
                  ),
                ],
                const Spacer(),
                // Bouton supprimer individuel
                GestureDetector(
                  onTap: () => _confirmDeleteEntry(context, colors, entry),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.destructive.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 16, color: colors.destructive),
                  ),
                ),
              ],
            ),
            if (entry.lastError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.destructive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  entry.lastError!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.destructive,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(AppColors colors, dynamic spooler) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        boxShadow: [
          BoxShadow(
            color: colors.foreground.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AppButton(
          text: 'Renvoyer les requêtes',
          icon: Icons.replay,
          onPressed: spooler.isProcessing ? null : () => spooler.retryAll(),
          isLoading: spooler.isProcessing,
        ),
      ),
    );
  }

  // ─── Confirmations ───────────────────────────────────────

  void _confirmDeleteEntry(
      BuildContext context, AppColors colors, YpsiumSpoolerEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Supprimer cette requête ?',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: colors.foreground),
        ),
        content: Text(
          entry.label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler',
                style: TextStyle(color: colors.mutedForeground)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              sl.ypsiumSpoolerService.removeEntry(entry.id);
            },
            child: Text('Supprimer', style: TextStyle(color: colors.destructive)),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, AppColors colors) {
    // Double confirmation
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Vider le spooler ?',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: colors.foreground),
        ),
        content: Text(
          'Toutes les requêtes en attente seront supprimées. '
          'Les données non envoyées seront perdues.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler',
                style: TextStyle(color: colors.mutedForeground)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _confirmClearAllSecond(context, colors);
            },
            child: Text('Continuer', style: TextStyle(color: colors.destructive)),
          ),
        ],
      ),
    );
  }

  void _confirmClearAllSecond(BuildContext context, AppColors colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Confirmer la suppression',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: colors.destructive),
        ),
        content: Text(
          'Cette action est irréversible. '
          'Êtes-vous sûr de vouloir supprimer toutes les requêtes ?',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler',
                style: TextStyle(color: colors.mutedForeground)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              sl.ypsiumSpoolerService.clearAll();
            },
            child: Text('Tout supprimer',
                style: TextStyle(color: colors.destructive)),
          ),
        ],
      ),
    );
  }
}

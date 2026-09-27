import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ypsium_spooler_entry.dart';
import '../../widgets/widgets.dart';
import 'widgets/ypsium_order_visual.dart';
import 'widgets/ypsium_spooler_widgets.dart';

/// File d'envoi Ypsium (spooler) : les envois faits hors ligne qui n'ont pas
/// encore atteint le serveur. Hero avec les compteurs, liste dans l'ordre
/// d'envoi, « Renvoyer maintenant » dans le dock ; suppression d'un envoi
/// ou de toute la file après confirmation.
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

    return AppPage(
      title: 'Envois en attente',
      actions: [
        if (entries.isNotEmpty)
          AppIconButton(
            icon: Icons.delete_sweep_rounded,
            tooltip: 'Vider la file',
            color: colors.foreground,
            onPressed: _confirmClearAll,
          ),
      ],
      body: entries.isEmpty
          ? Padding(
              // Centre l'état vide au-dessus de la tab bar.
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: const AppEmptyState(
                icon: Icons.check_circle_outline_rounded,
                title: 'Tout est envoyé',
                subtitle: 'Aucun envoi en attente',
              ),
            )
          : AppScrollView(
              children: [
                YpsiumSpoolerHero(
                  entries: entries,
                  isProcessing: spooler.isProcessing,
                ),
                const SizedBox(height: AppSpacing.lg),
                const AppSectionHeader(
                  title: 'File d\'envoi',
                  summary: 'Envoyés dans l\'ordre',
                ),
                YpsiumRowGroup(
                  children: [
                    for (final entry in entries)
                      YpsiumSpoolerRow(
                        key: ValueKey(entry.id),
                        entry: entry,
                        onDelete: () => _confirmDeleteEntry(entry),
                      ),
                  ],
                ),
              ],
            ),
      dock: entries.isEmpty
          ? null
          : AppDock(
              actions: [
                DockAction(
                  label: 'Renvoyer maintenant',
                  icon: Icons.replay_rounded,
                  isLoading: spooler.isProcessing,
                  onPressed:
                      spooler.isProcessing ? null : () => spooler.retryAll(),
                ),
              ],
              bottomGap: AppSpacing.lg,
            ),
    );
  }

  // ─── Confirmations ───────────────────────────────────────

  Future<void> _confirmDeleteEntry(YpsiumSpoolerEntry entry) async {
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Supprimer cet envoi ?',
      message: 'Il ne partira jamais vers Ypsium.',
      details: AppRecapBox(
        rows: [
          AppRecapRow(label: 'Envoi', value: entry.label),
          AppRecapRow(
            label: 'Créé à',
            value: DateFormat('HH:mm:ss').format(entry.createdAt),
          ),
        ],
      ),
      confirmLabel: 'Supprimer l\'envoi',
      confirmIcon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;
    sl.ypsiumSpoolerService.removeEntry(entry.id);
  }

  /// Double confirmation avant de vider toute la file.
  Future<void> _confirmClearAll() async {
    final first = await AppConfirmSheet.show(
      context,
      title: 'Vider la file ?',
      message: 'Tous les envois en attente seront supprimés. '
          'Les données non envoyées seront perdues.',
      confirmLabel: 'Oui, vider la file',
    );
    if (!first || !mounted) return;

    final second = await AppConfirmSheet.show(
      context,
      title: 'Confirmer la suppression',
      message: 'Cette action est irréversible. '
          'Tu veux vraiment supprimer tous les envois ?',
      confirmLabel: 'Tout supprimer',
      confirmIcon: Icons.delete_sweep_rounded,
    );
    if (!second || !mounted) return;
    sl.ypsiumSpoolerService.clearAll();
  }
}

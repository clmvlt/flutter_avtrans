import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/ypsium_models.dart';
import '../../../widgets/widgets.dart';
import 'ypsium_order_visual.dart';

/// Les transports du jour en trois sections : « À enlever », « À livrer »,
/// puis « Livrés », repliée par défaut (lien Afficher / Masquer).
class YpsiumTransportSections extends StatelessWidget {
  const YpsiumTransportSections({
    super.key,
    required this.orders,
    required this.showLivres,
    required this.onToggleLivres,
    required this.onOpen,
  });

  final List<YpsiumTransportOrder> orders;
  final bool showLivres;
  final VoidCallback onToggleLivres;
  final ValueChanged<YpsiumTransportOrder> onOpen;

  @override
  Widget build(BuildContext context) {
    final aEnlever = orders.where((o) => o.isAEnlever).toList();
    final enleves = orders.where((o) => o.isEnleve).toList();
    final livres = orders.where((o) => o.isLivre).toList();

    Widget group(List<YpsiumTransportOrder> list) => YpsiumRowGroup(
          children: [
            for (final order in list)
              YpsiumOrderRow(order: order, onTap: () => onOpen(order)),
          ],
        );

    final blocks = <Widget>[
      if (aEnlever.isNotEmpty)
        _Section(
          header: AppSectionHeader(
            title: 'À enlever',
            summary: DisplayFormat.plural(aEnlever.length, 'transport'),
          ),
          child: group(aEnlever),
        ),
      if (enleves.isNotEmpty)
        _Section(
          header: AppSectionHeader(
            title: 'À livrer',
            summary: DisplayFormat.plural(enleves.length, 'transport'),
          ),
          child: group(enleves),
        ),
      if (livres.isNotEmpty)
        _Section(
          header: AppSectionHeader(
            title: 'Livrés',
            actionLabel:
                showLivres ? 'Masquer' : 'Afficher (${livres.length})',
            onAction: onToggleLivres,
          ),
          child: showLivres ? group(livres) : null,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          blocks[i],
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.header, this.child});

  final Widget header;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, if (child != null) child!],
    );
  }
}

/// Ligne d'un transport : boîte d'icône du groupe, client et pastille
/// d'état, puis les deux arrêts (heure · nom · ville) et le n° d'ordre.
class YpsiumOrderRow extends StatelessWidget {
  const YpsiumOrderRow({super.key, required this.order, required this.onTap});

  final YpsiumTransportOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final (icon, accent) = YpsiumOrderVisual.group(order, colors);
    final hasClient = order.client.isNotEmpty;
    final title = hasClient ? order.client : 'Ordre #${order.idOrdre}';

    final pickup = _StopText(
      heure: order.eHeureFormatted,
      name: order.eNom.isNotEmpty ? order.eNom : 'Enlèvement',
      ville: '${order.eCodePostal} ${order.eVille}'.trim(),
    );
    final drop = _StopText(
      heure: order.lHeureFormatted,
      name: order.lNom.isNotEmpty ? order.lNom : 'Livraison',
      ville: '${order.lCodePostal} ${order.lVille}'.trim(),
    );

    return Semantics(
      button: true,
      label: '$title, ${order.etatLabel}. Enlèvement : ${pickup.spoken}. '
          'Livraison : ${drop.spoken}. Ordre ${order.idOrdre}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.md,
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          YpsiumEtatChip(order: order),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _StopLine(
                        icon: Icons.upload_rounded,
                        color: colors.info,
                        stop: pickup,
                      ),
                      const SizedBox(height: 2),
                      _StopLine(
                        icon: Icons.download_rounded,
                        color: colors.success,
                        stop: drop,
                      ),
                      if (hasClient) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Ordre #${order.idOrdre}',
                          style: textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StopText {
  const _StopText({
    required this.heure,
    required this.name,
    required this.ville,
  });

  final String heure;
  final String name;
  final String ville;

  String get spoken =>
      [heure, name, ville].where((s) => s.isNotEmpty).join(', ');
}

/// « 08:30 · Pharmacie du centre · 75001 Paris » avec l'heure en valeur.
class _StopLine extends StatelessWidget {
  const _StopLine({
    required this.icon,
    required this.color,
    required this.stop,
  });

  final IconData icon;
  final Color color;
  final _StopText stop;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final rest = [stop.name, stop.ville].where((s) => s.isNotEmpty).join(' · ');

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                if (stop.heure.isNotEmpty) ...[
                  TextSpan(
                    text: stop.heure,
                    style: textTheme.labelMedium?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const TextSpan(text: ' · '),
                ],
                TextSpan(text: rest),
              ],
            ),
            style: textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

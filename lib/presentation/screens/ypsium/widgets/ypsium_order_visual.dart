import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/ypsium_models.dart';
import '../../../widgets/widgets.dart';

/// Visuels d'un ordre de transport Ypsium : groupe (à enlever, à livrer,
/// livré) pour la boîte d'icône, et pastille d'état.
abstract final class YpsiumOrderVisual {
  /// Icône et accent du groupe de l'ordre.
  static (IconData, Color) group(YpsiumTransportOrder order, AppColors colors) {
    if (order.isAEnlever) return (Icons.upload_rounded, colors.info);
    if (order.isEnleve) return (Icons.local_shipping_rounded, colors.warning);
    return (Icons.check_circle_rounded, colors.success);
  }

  /// Nom du groupe : « À enlever », « À livrer », « Livré ».
  static String groupLabel(YpsiumTransportOrder order) {
    if (order.isAEnlever) return 'À enlever';
    if (order.isEnleve) return 'À livrer';
    return 'Livré';
  }

  /// Teinte de la pastille d'état : même répartition que l'ancien badge
  /// (enlevé et livré en vert, en cours en ambre, le reste neutre).
  static Color etatColor(int idEtat, AppColors colors) => switch (idEtat) {
        4 || 5 => colors.success,
        2 => colors.warning,
        _ => colors.mutedForeground,
      };

  static IconData etatIcon(int idEtat) => switch (idEtat) {
        0 => Icons.fiber_new_rounded,
        1 => Icons.assignment_ind_rounded,
        2 => Icons.autorenew_rounded,
        3 => Icons.event_rounded,
        4 => Icons.inventory_2_rounded,
        5 => Icons.check_rounded,
        6 => Icons.done_all_rounded,
        _ => Icons.circle_outlined,
      };
}

/// Pastille d'état d'un ordre : icône teintée + libellé (« Enlevé »).
class YpsiumEtatChip extends StatelessWidget {
  const YpsiumEtatChip({super.key, required this.order});

  final YpsiumTransportOrder order;

  @override
  Widget build(BuildContext context) {
    return AppStatusChip(
      label: order.etatLabel,
      color: YpsiumOrderVisual.etatColor(order.idEtat, context.colors),
      icon: YpsiumOrderVisual.etatIcon(order.idEtat),
    );
  }
}

/// Groupe de lignes dans une carte, séparées par un filet aligné sur le
/// texte (marge 16 + boîte d'icône 40 + écart 12), comme `AppSection`.
class YpsiumRowGroup extends StatelessWidget {
  const YpsiumRowGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 68,
                endIndent: AppSpacing.base,
                color: colors.border,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

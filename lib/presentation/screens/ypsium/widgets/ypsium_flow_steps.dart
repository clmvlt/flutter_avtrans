import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/ypsium_models.dart';
import '../../../widgets/widgets.dart';
import 'ypsium_colis_widgets.dart';
import 'ypsium_order_visual.dart';
import 'ypsium_place_card.dart';

/// Étape 1 de l'enlèvement : lieu d'enlèvement (itinéraire, appel) et
/// colis chargés, avec le lien « Ajouter un colis ».
class YpsiumChargementStep extends StatelessWidget {
  const YpsiumChargementStep({
    super.key,
    required this.order,
    required this.colis,
    required this.onAddColis,
    required this.onCall,
    required this.onMaps,
  });

  final YpsiumTransportOrder order;
  final List<YpsiumColisEntry> colis;
  final VoidCallback onAddColis;
  final ValueChanged<String> onCall;

  /// `null` quand l'adresse est vide.
  final VoidCallback? onMaps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Lieu d\'enlèvement',
          summary: order.eHeureFormatted,
        ),
        YpsiumPlaceCard(
          icon: Icons.upload_rounded,
          accent: context.colors.info,
          name: order.eNom,
          fallbackName: 'Lieu d\'enlèvement',
          addressLines: [order.eAdresseComplete],
          phones: [order.eTelephone1],
          onCall: onCall,
          onMaps: onMaps,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: colis.isEmpty ? 'Colis chargés' : 'Colis chargés · ${colis.length}',
          actionLabel: 'Ajouter un colis',
          onAction: onAddColis,
        ),
        if (colis.isEmpty)
          const AppEmptyCard(
            icon: Icons.inventory_2_outlined,
            message: 'Aucun colis ajouté',
          )
        else
          YpsiumColisList(colis: colis),
      ],
    );
  }
}

/// Étape 1 de la livraison : lieu de livraison (contact, itinéraire,
/// appel) et provenance.
class YpsiumLivraisonRecapStep extends StatelessWidget {
  const YpsiumLivraisonRecapStep({
    super.key,
    required this.order,
    required this.onCall,
    required this.onMaps,
  });

  final YpsiumTransportOrder order;
  final ValueChanged<String> onCall;

  /// `null` quand l'adresse est vide.
  final VoidCallback? onMaps;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Lieu de livraison',
          summary: order.lHeureFormatted,
        ),
        YpsiumPlaceCard(
          icon: Icons.download_rounded,
          accent: colors.success,
          name: order.lNom,
          fallbackName: 'Lieu de livraison',
          addressLines: [order.lAdresseComplete],
          contact: order.lContact,
          phones: [order.lTelephone1],
          onCall: onCall,
          onMaps: onMaps,
        ),
        const SizedBox(height: AppSpacing.lg),

        // Provenance (enlèvement déjà fait)
        const AppSectionHeader(title: 'Provenance'),
        YpsiumRowGroup(
          children: [
            AppListRow(
              icon: Icons.upload_rounded,
              iconColor: colors.mutedForeground,
              title: order.eNom.isNotEmpty ? order.eNom : 'Lieu d\'enlèvement',
              subtitle: '${order.eCodePostal} ${order.eVille}'.trim(),
            ),
          ],
        ),
      ],
    );
  }
}

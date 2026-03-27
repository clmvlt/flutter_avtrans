import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/ypsium_models.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import 'ypsium_enlevement_flow_screen.dart';
import 'ypsium_livraison_flow_screen.dart';

/// Écran de détail d'un ordre de transport Ypsium
/// Affiche les actions selon l'état : enlèvement, livraison, ou re-opération
class YpsiumTransportDetailScreen extends StatelessWidget {
  final YpsiumTransportOrder order;

  const YpsiumTransportDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.foreground, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Ordre #${order.idOrdre}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
            color: colors.foreground,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(colors),
            const SizedBox(height: AppSpacing.base),

            // Enlèvement
            _buildStopCard(
              colors: colors,
              title: 'Enlèvement',
              icon: Icons.upload_outlined,
              iconColor: colors.info,
              nom: order.eNom,
              adresse1: order.eAdresse1,
              adresse2: order.eAdresse2,
              adresse3: order.eAdresse3,
              codePostal: order.eCodePostal,
              ville: order.eVille,
              pays: order.ePays,
              heure: order.eHeureFormatted,
              contact: order.eContact,
              tel1: order.eTelephone1,
              tel2: order.eTelephone2,
            ),
            const SizedBox(height: AppSpacing.base),

            // Livraison
            _buildStopCard(
              colors: colors,
              title: 'Livraison',
              icon: Icons.download_outlined,
              iconColor: colors.success,
              nom: order.lNom,
              adresse1: order.lAdresse1,
              adresse2: order.lAdresse2,
              adresse3: order.lAdresse3,
              codePostal: order.lCodePostal,
              ville: order.lVille,
              pays: order.lPays,
              heure: order.lHeureFormatted,
              contact: order.lContact,
              tel1: order.lTelephone1,
              tel2: order.lTelephone2,
            ),
            const SizedBox(height: AppSpacing.base),

            // Photos requises
            if (_hasPhotoConfig()) _buildPhotoInfo(colors),
            if (_hasPhotoConfig()) const SizedBox(height: AppSpacing.base),

            // Infos complémentaires
            _buildDetails(colors),
            const SizedBox(height: AppSpacing.xl),

            // Actions selon l'état
            ..._buildActions(context, colors),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // Actions
  // ==========================================================

  List<Widget> _buildActions(BuildContext context, AppColors colors) {
    final widgets = <Widget>[];

    if (order.isAEnlever) {
      widgets.add(AppButton(
        text: 'Commencer l\'enlèvement',
        icon: Icons.upload_outlined,
        onPressed: () => _startFlow(context, isEnlevement: true),
      ));
    } else if (order.isEnleve) {
      widgets.add(AppButton(
        text: 'Commencer la livraison',
        icon: Icons.download_outlined,
        onPressed: () => _startFlow(context, isEnlevement: false),
      ));
    } else if (order.isLivre) {
      widgets.add(AppButton(
        text: 'Re-enlever',
        icon: Icons.upload_outlined,
        variant: ButtonVariant.outline,
        onPressed: () => _startFlow(context, isEnlevement: true),
      ));
      widgets.add(const SizedBox(height: AppSpacing.sm));
      widgets.add(AppButton(
        text: 'Re-livrer',
        icon: Icons.download_outlined,
        variant: ButtonVariant.outline,
        onPressed: () => _startFlow(context, isEnlevement: false),
      ));
    }

    return widgets;
  }

  void _startFlow(BuildContext context, {required bool isEnlevement}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => isEnlevement
            ? YpsiumEnlevementFlowScreen(order: order)
            : YpsiumLivraisonFlowScreen(order: order),
      ),
    );
    if (result == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  // ==========================================================
  // Helpers launch
  // ==========================================================

  void _callPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isNotEmpty) {
      launchUrl(Uri.parse('tel:$cleaned'));
    }
  }

  void _openMaps({
    required String adresse1,
    String adresse2 = '',
    String adresse3 = '',
    required String codePostal,
    required String ville,
    String pays = '',
  }) {
    final parts = [adresse1, adresse2, adresse3, '$codePostal $ville', pays]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');
    final encoded = Uri.encodeComponent(parts);
    launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded'),
      mode: LaunchMode.externalApplication,
    );
  }

  // ==========================================================
  // Widgets
  // ==========================================================

  Widget _buildHeader(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.client,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ordre #${order.idOrdre}',
                  style: TextStyle(fontSize: 13, color: colors.mutedForeground),
                ),
              ],
            ),
          ),
          _buildEtatBadge(colors),
        ],
      ),
    );
  }

  Widget _buildEtatBadge(AppColors colors) {
    BadgeVariant variant;
    switch (order.idEtat) {
      case 4:
      case 5:
        variant = BadgeVariant.success;
        break;
      case 2:
        variant = BadgeVariant.warning;
        break;
      default:
        variant = BadgeVariant.secondary;
    }
    return AppBadge(text: order.etatLabel, variant: variant);
  }

  Widget _buildStopCard({
    required AppColors colors,
    required String title,
    required IconData icon,
    required Color iconColor,
    required String nom,
    required String adresse1,
    String adresse2 = '',
    String adresse3 = '',
    required String codePostal,
    required String ville,
    String pays = '',
    required String heure,
    String contact = '',
    String tel1 = '',
    String tel2 = '',
  }) {
    final hasAddress = adresse1.isNotEmpty || codePostal.isNotEmpty || ville.isNotEmpty;
    final hasPhone = tel1.isNotEmpty || tel2.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const Spacer(),
              if (heure.isNotEmpty)
                AppBadge(text: heure, variant: BadgeVariant.secondary),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Nom
          if (nom.isNotEmpty)
            Text(
              nom,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.foreground,
              ),
            ),

          // Adresse
          if (adresse1.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                adresse1,
                style: TextStyle(fontSize: 13, color: colors.mutedForeground),
              ),
            ),
          if (adresse2.isNotEmpty)
            Text(adresse2, style: TextStyle(fontSize: 13, color: colors.mutedForeground)),
          if (adresse3.isNotEmpty)
            Text(adresse3, style: TextStyle(fontSize: 13, color: colors.mutedForeground)),
          if (codePostal.isNotEmpty || ville.isNotEmpty)
            Text(
              '$codePostal $ville'.trim(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.foreground,
              ),
            ),

          // Contact
          if (contact.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: colors.mutedForeground),
                const SizedBox(width: 4),
                Text(contact, style: TextStyle(fontSize: 13, color: colors.mutedForeground)),
              ],
            ),
          ],

          // Téléphones (texte)
          if (tel1.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.phone_outlined, size: 14, color: colors.mutedForeground),
                  const SizedBox(width: 4),
                  Text(tel1, style: TextStyle(fontSize: 13, color: colors.mutedForeground)),
                ],
              ),
            ),
          if (tel2.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.phone_outlined, size: 14, color: colors.mutedForeground),
                  const SizedBox(width: 4),
                  Text(tel2, style: TextStyle(fontSize: 13, color: colors.mutedForeground)),
                ],
              ),
            ),

          // Boutons d'action : Appeler + GPS
          if (hasPhone || hasAddress) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (tel1.isNotEmpty)
                  _buildActionChip(
                    colors: colors,
                    icon: Icons.phone,
                    label: 'Appeler',
                    color: colors.success,
                    onTap: () => _callPhone(tel1),
                  ),
                if (tel1.isNotEmpty && tel2.isNotEmpty)
                  const SizedBox(width: AppSpacing.sm),
                if (tel2.isNotEmpty)
                  _buildActionChip(
                    colors: colors,
                    icon: Icons.phone,
                    label: tel2,
                    color: colors.success,
                    onTap: () => _callPhone(tel2),
                  ),
                if (hasPhone && hasAddress)
                  const SizedBox(width: AppSpacing.sm),
                if (hasAddress)
                  _buildActionChip(
                    colors: colors,
                    icon: Icons.navigation,
                    label: 'Itinéraire',
                    color: colors.info,
                    onTap: () => _openMaps(
                      adresse1: adresse1,
                      adresse2: adresse2,
                      adresse3: adresse3,
                      codePostal: codePostal,
                      ville: ville,
                      pays: pays,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required AppColors colors,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoInfo(AppColors colors) {
    final photos = <String>[];
    if (order.photoEnlDebut) photos.add('Enlèvement (début)');
    if (order.photoEnlFin) photos.add('Enlèvement (fin)');
    if (order.photoLivDebut) photos.add('Livraison (début)');
    if (order.photoLivFin) photos.add('Livraison (fin)');
    if (order.photoDocEnl) photos.add('Documents enlèvement');
    if (order.photoDocLiv) photos.add('Documents livraison');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photos requises',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...photos.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 14, color: colors.info),
                    const SizedBox(width: AppSpacing.sm),
                    Text(p, style: TextStyle(fontSize: 13, color: colors.foreground)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildDetails(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Détails',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(colors, 'État enlèvement', _sousEtatLabel(order.idEtatSousOrdreEnlevement)),
          _row(colors, 'État livraison', _sousEtatLabel(order.idEtatSousOrdreLivraison)),
          if (order.eSignatureAuto) _row(colors, 'Signature enlèvement', 'Automatique'),
          if (order.lSignatureAuto) _row(colors, 'Signature livraison', 'Automatique'),
          if (order.bEstUnService) _row(colors, 'Type', 'Service'),
        ],
      ),
    );
  }

  Widget _row(AppColors colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: colors.mutedForeground)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.foreground),
          ),
        ],
      ),
    );
  }

  bool _hasPhotoConfig() {
    return order.photoEnlDebut ||
        order.photoEnlFin ||
        order.photoLivDebut ||
        order.photoLivFin ||
        order.photoDocEnl ||
        order.photoDocLiv;
  }

  String _sousEtatLabel(int etat) {
    switch (etat) {
      case 0:
        return 'Non démarré';
      case 1:
        return 'En cours';
      case 2:
        return 'Terminé';
      default:
        return 'État $etat';
    }
  }
}

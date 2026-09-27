import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/ypsium_models.dart';
import '../../widgets/widgets.dart';
import 'widgets/ypsium_order_visual.dart';
import 'widgets/ypsium_place_card.dart';
import 'ypsium_enlevement_flow_screen.dart';
import 'ypsium_livraison_flow_screen.dart';

/// Détail d'un ordre de transport Ypsium : hero (client, état, heures),
/// lieux d'enlèvement et de livraison (itinéraire, appel), photos requises,
/// détails. Le dock lance l'étape suivante selon l'état de l'ordre.
class YpsiumTransportDetailScreen extends StatelessWidget {
  final YpsiumTransportOrder order;

  const YpsiumTransportDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, accent) = YpsiumOrderVisual.group(order, colors);
    final photos = _requiredPhotos();

    return AppPage(
      title: 'Ordre #${order.idOrdre}',
      body: AppScrollView(
        children: [
          AppHeroCard(
            icon: icon,
            accent: accent,
            title: order.client.isNotEmpty
                ? order.client
                : 'Ordre #${order.idOrdre}',
            subtitle: YpsiumOrderVisual.groupLabel(order),
            trailing: YpsiumEtatChip(order: order),
            child: AppMetricRow(
              metrics: [
                AppMetric(
                  label: 'Enlèvement',
                  value: _orDash(order.eHeureFormatted),
                ),
                AppMetric(
                  label: 'Livraison',
                  value: _orDash(order.lHeureFormatted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Enlèvement
          const AppSectionHeader(title: 'Enlèvement'),
          _stopCard(
            colors: colors,
            icon: Icons.upload_rounded,
            accent: colors.info,
            fallbackName: 'Enlèvement',
            nom: order.eNom,
            adresse1: order.eAdresse1,
            adresse2: order.eAdresse2,
            adresse3: order.eAdresse3,
            codePostal: order.eCodePostal,
            ville: order.eVille,
            pays: order.ePays,
            contact: order.eContact,
            tel1: order.eTelephone1,
            tel2: order.eTelephone2,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Livraison
          const AppSectionHeader(title: 'Livraison'),
          _stopCard(
            colors: colors,
            icon: Icons.download_rounded,
            accent: colors.success,
            fallbackName: 'Livraison',
            nom: order.lNom,
            adresse1: order.lAdresse1,
            adresse2: order.lAdresse2,
            adresse3: order.lAdresse3,
            codePostal: order.lCodePostal,
            ville: order.lVille,
            pays: order.lPays,
            contact: order.lContact,
            tel1: order.lTelephone1,
            tel2: order.lTelephone2,
          ),

          // Photos requises
          if (photos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            AppSectionHeader(
              title: 'Photos requises',
              summary: '${photos.length}',
            ),
            YpsiumRowGroup(
              children: [
                for (final p in photos)
                  AppListRow(
                    icon: Icons.photo_camera_rounded,
                    iconColor: colors.info,
                    title: p,
                  ),
              ],
            ),
          ],

          // Infos complémentaires
          const SizedBox(height: AppSpacing.lg),
          const AppSectionHeader(title: 'Détails'),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: [
                AppRecapRow(
                  label: 'État enlèvement',
                  value: _sousEtatLabel(order.idEtatSousOrdreEnlevement),
                ),
                AppRecapRow(
                  label: 'État livraison',
                  value: _sousEtatLabel(order.idEtatSousOrdreLivraison),
                ),
                if (order.eSignatureAuto)
                  const AppRecapRow(
                    label: 'Signature enlèvement',
                    value: 'Automatique',
                  ),
                if (order.lSignatureAuto)
                  const AppRecapRow(
                    label: 'Signature livraison',
                    value: 'Automatique',
                  ),
                if (order.bEstUnService)
                  const AppRecapRow(label: 'Type', value: 'Service'),
              ],
            ),
          ),
        ],
      ),
      dock: AppDock(
        actions: _dockActions(context),
        bottomGap: AppSpacing.lg,
      ),
    );
  }

  // ==========================================================
  // Actions
  // ==========================================================

  /// Le dock dit l'étape suivante : enlever, livrer, ou refaire l'une des
  /// deux une fois l'ordre livré.
  List<DockAction> _dockActions(BuildContext context) {
    if (order.isAEnlever) {
      return [
        DockAction(
          label: 'Commencer l\'enlèvement',
          icon: Icons.upload_rounded,
          onPressed: () => _startFlow(context, isEnlevement: true),
        ),
      ];
    }
    if (order.isEnleve) {
      return [
        DockAction(
          label: 'Commencer la livraison',
          icon: Icons.download_rounded,
          onPressed: () => _startFlow(context, isEnlevement: false),
        ),
      ];
    }
    if (order.isLivre) {
      return [
        DockAction(
          label: 'Re-enlever',
          icon: Icons.upload_rounded,
          tone: DockTone.secondary,
          onPressed: () => _startFlow(context, isEnlevement: true),
        ),
        DockAction(
          label: 'Re-livrer',
          icon: Icons.download_rounded,
          tone: DockTone.secondary,
          onPressed: () => _startFlow(context, isEnlevement: false),
        ),
      ];
    }
    return const [];
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

  Widget _stopCard({
    required AppColors colors,
    required IconData icon,
    required Color accent,
    required String fallbackName,
    required String nom,
    required String adresse1,
    String adresse2 = '',
    String adresse3 = '',
    required String codePostal,
    required String ville,
    String pays = '',
    String contact = '',
    String tel1 = '',
    String tel2 = '',
  }) {
    final hasAddress =
        adresse1.isNotEmpty || codePostal.isNotEmpty || ville.isNotEmpty;

    return YpsiumPlaceCard(
      icon: icon,
      accent: accent,
      name: nom,
      fallbackName: fallbackName,
      addressLines: [adresse1, adresse2, adresse3, '$codePostal $ville'.trim()],
      contact: contact,
      phones: [tel1, tel2],
      onCall: _callPhone,
      onMaps: hasAddress
          ? () => _openMaps(
                adresse1: adresse1,
                adresse2: adresse2,
                adresse3: adresse3,
                codePostal: codePostal,
                ville: ville,
                pays: pays,
              )
          : null,
    );
  }

  static String _orDash(String value) => value.isEmpty ? '—' : value;

  List<String> _requiredPhotos() {
    final photos = <String>[];
    if (order.photoEnlDebut) photos.add('Enlèvement (début)');
    if (order.photoEnlFin) photos.add('Enlèvement (fin)');
    if (order.photoLivDebut) photos.add('Livraison (début)');
    if (order.photoLivFin) photos.add('Livraison (fin)');
    if (order.photoDocEnl) photos.add('Documents enlèvement');
    if (order.photoDocLiv) photos.add('Documents livraison');
    return photos;
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

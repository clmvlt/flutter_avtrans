import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/widgets.dart';
import 'ypsium_order_visual.dart';

/// Carte d'un lieu (enlèvement ou livraison) : nom et adresse (tap = ouvrir
/// l'itinéraire), contact, téléphones (tap = appeler). Les actions sont
/// fournies par l'écran, qui garde sa propre façon de composer l'adresse.
class YpsiumPlaceCard extends StatelessWidget {
  const YpsiumPlaceCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.name,
    required this.fallbackName,
    this.addressLines = const [],
    this.contact = '',
    this.phones = const [],
    this.onCall,
    this.onMaps,
  });

  final IconData icon;
  final Color accent;
  final String name;

  /// Titre affiché quand le nom du lieu est vide.
  final String fallbackName;
  final List<String> addressLines;
  final String contact;
  final List<String> phones;
  final ValueChanged<String>? onCall;

  /// `null` : pas d'adresse, pas d'itinéraire.
  final VoidCallback? onMaps;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = name.isNotEmpty ? name : fallbackName;
    final address =
        addressLines.where((l) => l.trim().isNotEmpty).join('\n');

    return YpsiumRowGroup(
      children: [
        AppListRow(
          icon: icon,
          iconColor: accent,
          title: title,
          subtitle: address.isEmpty ? null : address,
          subtitleMaxLines: 4,
          trailing: onMaps == null
              ? null
              : const YpsiumRowAction(
                  icon: Icons.directions_rounded,
                  label: 'Itinéraire',
                ),
          onTap: onMaps,
          semanticsLabel: onMaps == null
              ? null
              : '$title. $address. Ouvre l\'itinéraire',
        ),
        if (contact.isNotEmpty)
          AppListRow(
            icon: Icons.person_rounded,
            iconColor: colors.mutedForeground,
            title: contact,
            subtitle: 'Contact',
          ),
        for (final phone in phones.where((p) => p.isNotEmpty))
          AppListRow(
            icon: Icons.phone_rounded,
            iconColor: colors.success,
            title: phone,
            subtitle: 'Téléphone',
            trailing: onCall == null
                ? null
                : const YpsiumRowAction(
                    icon: Icons.call_rounded,
                    label: 'Appeler',
                  ),
            onTap: onCall == null ? null : () => onCall!(phone),
            semanticsLabel: onCall == null ? null : 'Appeler le $phone',
          ),
      ],
    );
  }
}

/// Accessoire de ligne qui annonce l'action du tap : icône teintée et mot.
class YpsiumRowAction extends StatelessWidget {
  const YpsiumRowAction({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: colors.primary),
        const SizedBox(height: 2),
        Text(label, style: textTheme.labelSmall),
      ],
    );
  }
}

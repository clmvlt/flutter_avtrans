import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/vehicule_model.dart';
import '../../../widgets/widgets.dart';

/// « Marque Modèle », sans espace parasite quand l'un des deux manque.
String vehiculeName(Vehicule v) =>
    [v.brand, v.model].where((s) => s.trim().isNotEmpty).join(' ');

/// Carte hero de la fiche véhicule : immatriculation, marque et modèle,
/// puis le dernier kilométrage en grand chiffre et la date du relevé.
class VehiculeHeroCard extends StatelessWidget {
  const VehiculeHeroCard({super.key, required this.vehicule});

  final Vehicule vehicule;

  String _readingDate(DateTime date) {
    final day = DisplayFormat.relativeDay(date);
    return switch (day) {
      'Aujourd\'hui' => 'Relevé aujourd\'hui',
      'Hier' => 'Relevé hier',
      'Demain' => 'Relevé demain',
      _ => 'Relevé le $day',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final v = vehicule;
    final name = vehiculeName(v);
    final km = v.latestKm;
    final date = v.latestKmDate;

    return AppHeroCard(
      icon: Icons.directions_car_rounded,
      accent: colors.domainVehicule,
      title: v.immat,
      subtitle: name.isEmpty ? null : name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeroFigure(
            label: 'Dernier kilométrage',
            value: km != null ? DisplayFormat.km(km) : 'Aucun relevé',
            muted: km == null,
            small: km == null,
          ),
          if (km != null && date != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_readingDate(date), style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

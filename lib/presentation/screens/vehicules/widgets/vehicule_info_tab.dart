import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/vehicule_model.dart';
import '../../../widgets/widgets.dart';
import 'deadline_chip.dart';
import 'vehicule_field_row.dart';

/// Onglet « Infos » de la fiche véhicule : raccourcis (entretiens pour
/// l'atelier, signalement), puis la fiche groupée par thème. Les champs
/// facultatifs n'apparaissent que s'ils sont renseignés.
class VehiculeInfoTab extends StatelessWidget {
  const VehiculeInfoTab({
    super.key,
    required this.vehicule,
    required this.showEntretiens,
    required this.onOpenEntretiens,
    required this.onAddInfo,
    required this.onOpenPhoto,
    required this.now,
  });

  final Vehicule vehicule;

  /// Ligne « Entretiens » : Administrateur et Mécanicien uniquement.
  final bool showEntretiens;
  final VoidCallback onOpenEntretiens;
  final VoidCallback onAddInfo;
  final VoidCallback onOpenPhoto;
  final DateTime now;

  static bool _has(String? s) => s != null && s.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = vehicule;

    final identification = <Widget>[
      if (_has(v.pictureUrl))
        AppListRow(
          leading: _PhotoThumb(url: v.pictureUrl!),
          title: 'Photo du véhicule',
          subtitle: 'Touche pour agrandir',
          onTap: onOpenPhoto,
        ),
      VehiculeFieldRow(
        icon: Icons.confirmation_number_rounded,
        label: 'Immatriculation',
        value: v.immat,
      ),
      if (_has(v.relaiImmat))
        VehiculeFieldRow(
          icon: Icons.repeat_rounded,
          label: 'Véhicule relais',
          value: v.relaiImmat!,
        ),
      _textRow(Icons.business_rounded, 'Marque', v.brand),
      _textRow(Icons.directions_car_rounded, 'Modèle', v.model),
      if (_has(v.vin))
        VehiculeFieldRow(icon: Icons.tag_rounded, label: 'VIN', value: v.vin!),
      if (_has(v.numeroCarteGrise))
        VehiculeFieldRow(
          icon: Icons.badge_rounded,
          label: 'Carte grise',
          value: v.numeroCarteGrise!,
        ),
      VehiculeFieldRow(
        icon: Icons.event_available_rounded,
        label: 'Ajouté le',
        value: DisplayFormat.date(v.createdAt),
      ),
    ];

    final specs = <Widget>[
      if (v.dateMiseEnCirculation != null)
        VehiculeFieldRow(
          icon: Icons.event_rounded,
          label: 'Mise en circulation',
          value: DisplayFormat.date(v.dateMiseEnCirculation!),
        ),
      if (_has(v.typeCarburant))
        VehiculeFieldRow(
          icon: Icons.local_gas_station_rounded,
          label: 'Carburant',
          value: v.typeCarburant!,
        ),
      if (v.ptac != null)
        VehiculeFieldRow(
          icon: Icons.scale_rounded,
          label: 'PTAC',
          value: '${DisplayFormat.integer(v.ptac!)} kg',
        ),
    ];

    final insurance = <Widget>[
      if (_has(v.assureur))
        VehiculeFieldRow(
          icon: Icons.shield_rounded,
          label: 'Assureur',
          value: v.assureur!,
        ),
      if (_has(v.numeroContratAssurance))
        VehiculeFieldRow(
          icon: Icons.receipt_long_rounded,
          label: 'N° de contrat',
          value: v.numeroContratAssurance!,
        ),
      if (v.dateExpirationAssurance != null)
        VehiculeFieldRow(
          icon: Icons.event_busy_rounded,
          label: 'Fin de l\'assurance',
          value: DisplayFormat.date(v.dateExpirationAssurance!),
          trailing: DeadlineChip.of(
            context,
            v.dateExpirationAssurance!,
            now: now,
            overdueLabel: 'Expirée',
          ),
        ),
      if (v.dateProchainControleTechnique != null)
        VehiculeFieldRow(
          icon: Icons.fact_check_rounded,
          label: 'Prochain contrôle technique',
          value: DisplayFormat.date(v.dateProchainControleTechnique!),
          trailing: DeadlineChip.of(
            context,
            v.dateProchainControleTechnique!,
            now: now,
            overdueLabel: 'En retard',
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RowsCard(
          children: [
            if (showEntretiens)
              AppListRow(
                icon: Icons.build_rounded,
                iconColor: colors.primary,
                title: 'Entretiens',
                subtitle: 'Historique, échéances et suivi',
                onTap: onOpenEntretiens,
              ),
            AppListRow(
              icon: Icons.add_comment_rounded,
              iconColor: colors.warning,
              title: 'Ajouter des informations',
              subtitle: 'Signale un problème ou un ajustement, photos comprises',
              onTap: onAddInfo,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _FieldSection(title: 'Identification', rows: identification),
        if (specs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _FieldSection(title: 'Caractéristiques', rows: specs),
        ],
        if (insurance.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _FieldSection(title: 'Assurance et contrôle', rows: insurance),
        ],
        if (_has(v.comment)) ...[
          const SizedBox(height: AppSpacing.lg),
          _FieldSection(
            title: 'Commentaire',
            rows: [
              VehiculeFieldRow(
                icon: Icons.notes_rounded,
                label: 'Note',
                value: v.comment!.trim(),
                valueMaxLines: 12,
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Champ texte toujours affiché (marque, modèle) : « — » s'il est vide.
  Widget _textRow(IconData icon, String label, String value) {
    final empty = value.trim().isEmpty;
    return VehiculeFieldRow(
      icon: icon,
      label: label,
      value: empty ? '—' : value,
      muted: empty,
    );
  }
}

/// En-tête de section + carte de lignes.
class _FieldSection extends StatelessWidget {
  const _FieldSection({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title: title),
        _RowsCard(children: rows),
      ],
    );
  }
}

class _RowsCard extends StatelessWidget {
  const _RowsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(children: children),
    );
  }
}

/// Vignette 40 dp de la photo du véhicule (icône en secours).
class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fallback = AppIconBox(
      icon: Icons.photo_rounded,
      color: colors.domainVehicule,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: AppLayout.iconBox,
        height: AppLayout.iconBox,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          cacheWidth: 120,
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/mapbox_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';

/// Écran de sélection / ajustement d'un point GPS sur une carte Mapbox.
///
/// Un repère reste fixe au centre de l'écran : on déplace la carte pour placer
/// le point (le point retenu = centre de la carte). Utilisé pour :
/// - **confirmer/ajuster une adresse** avant de l'ajouter ([addressLabel] non nul) ;
/// - **poser un point GPS** directement ([addressLabel] nul).
///
/// Renvoie la [LatLng] choisie via `Navigator.pop`, ou `null` si annulation.
class MapPointPickerScreen extends StatefulWidget {
  const MapPointPickerScreen({
    super.key,
    required this.initial,
    required this.title,
    required this.confirmLabel,
    this.addressLabel,
  });

  final LatLng initial;
  final String title;
  final String confirmLabel;

  /// Adresse à confirmer (affichée en bandeau). `null` = simple point GPS.
  final String? addressLabel;

  @override
  State<MapPointPickerScreen> createState() => _MapPointPickerScreenState();
}

class _MapPointPickerScreenState extends State<MapPointPickerScreen> {
  final MapController _mapController = MapController();
  // Instance unique : évite que les tuiles se rechargent à chaque rebuild
  // (déplacement de la carte, mise à jour des coordonnées…).
  final TileLayer _tileLayer = MapboxConstants.tileLayer();
  late LatLng _center = widget.initial;
  bool _locating = false;

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (_center != camera.center) {
      setState(() => _center = camera.center);
    }
  }

  Future<void> _recenterOnUser() async {
    setState(() => _locating = true);
    var position = await sl.locationService.getLastKnownPosition();
    position ??= await sl.locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (position == null) return;
    final target = LatLng(position.latitude, position.longitude);
    _mapController.move(target, 16);
    setState(() => _center = target);
  }

  void _confirm() => Navigator.of(context).pop(_center);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: 16,
              minZoom: 3,
              maxZoom: 20,
              onPositionChanged: _onPositionChanged,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              _tileLayer,
              const SimpleAttributionWidget(
                source: Text(MapboxConstants.attribution),
              ),
            ],
          ),

          // Repère fixe au centre (la pointe vise le centre exact).
          const IgnorePointer(child: Center(child: _CenterPin())),

          // Bandeau d'adresse (mode confirmation).
          if (widget.addressLabel != null)
            Positioned(
              top: AppSpacing.base,
              left: AppSpacing.base,
              right: AppSpacing.base,
              child: _AddressBanner(label: widget.addressLabel!),
            ),

          // Bouton « se recentrer sur ma position ».
          Positioned(
            right: AppSpacing.base,
            bottom: 150,
            child: FloatingActionButton.small(
              heroTag: 'recenter',
              backgroundColor: colors.card,
              foregroundColor: colors.primary,
              onPressed: _locating ? null : _recenterOnUser,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),

          // Panneau bas : coordonnées + validation.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              center: _center,
              confirmLabel: widget.confirmLabel,
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Décale l'icône vers le haut pour que sa pointe touche le centre exact.
    return Transform.translate(
      offset: const Offset(0, -22),
      child: Icon(
        Icons.location_on,
        size: 44,
        color: colors.primary,
        shadows: const [
          Shadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
    );
  }
}

class _AddressBanner extends StatelessWidget {
  const _AddressBanner({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: colors.cardShadow,
          border: colors.isDarkMode
              ? Border.all(color: colors.border)
              : null,
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 18, color: colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.center,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final LatLng center;
  final String confirmLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final coords =
        '${center.latitude.toStringAsFixed(6)}, ${center.longitude.toStringAsFixed(6)}';

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        boxShadow: colors.navShadow,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.pin_drop_outlined,
                      size: 18, color: colors.mutedForeground),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Déplace la carte pour ajuster le point',
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(coords, style: textTheme.labelMedium),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                text: confirmLabel,
                icon: Icons.check_rounded,
                onPressed: onConfirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

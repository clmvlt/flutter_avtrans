import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/mapbox_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_dock.dart';
import '../../../widgets/app_page.dart';
import 'map_point_picker_parts.dart';
import 'tour_map_parts.dart';

/// Écran de sélection / ajustement d'un point GPS sur une carte Mapbox.
///
/// Interaction « pose ta localisation » (style Uber / Google Maps) : un repère
/// reste fixe au centre, on **glisse la carte** pour l'amener sur le bon
/// endroit. Le repère se **soulève** pendant le geste et **retombe** au relâcher
/// (retour haptique), laissant voir un point-cible au sol = l'emplacement exact.
///
/// La carte passe sous le dock, qui porte l'adresse, son statut et le bouton
/// de validation.
///
/// Utilisé pour :
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

  /// Adresse à confirmer (affichée dans le dock). `null` = simple point GPS.
  final String? addressLabel;

  @override
  State<MapPointPickerScreen> createState() => _MapPointPickerScreenState();
}

class _MapPointPickerScreenState extends State<MapPointPickerScreen> {
  // Au-delà de cette distance (m) entre le point et l'adresse géocodée, on
  // considère que l'utilisateur l'a volontairement déplacé.
  static const double _movedThresholdMeters = 8;

  final MapController _mapController = MapController();
  // Instance unique : évite que les tuiles se rechargent à chaque rebuild
  // (déplacement de la carte, mise à jour des coordonnées…).
  final TileLayer _tileLayer = MapboxConstants.tileLayer();

  late LatLng _center = widget.initial;
  bool _locating = false;

  // Nombre de doigts actuellement posés sur la carte : pilote le « soulèvement »
  // du repère (levé tant qu'au moins un doigt interagit).
  int _pointers = 0;
  bool get _lifted => _pointers > 0;

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (_center != camera.center) {
      setState(() => _center = camera.center);
    }
  }

  void _onPointerDown() {
    setState(() => _pointers++);
  }

  void _onPointerUp() {
    if (_pointers == 0) return;
    final wasLifted = _lifted;
    setState(() => _pointers = math.max(0, _pointers - 1));
    // Le repère vient de « retomber » : petit retour tactile, comme un clic.
    if (wasLifted && !_lifted) HapticFeedback.selectionClick();
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

  /// Ramène le point sur l'adresse géocodée d'origine.
  void _resetToAddress() {
    _mapController.move(widget.initial, _mapController.camera.zoom);
    setState(() => _center = widget.initial);
    HapticFeedback.selectionClick();
  }

  void _confirm() => Navigator.of(context).pop(_center);

  double? get _movedMeters {
    if (widget.addressLabel == null) return null;
    return _distanceMeters(_center, widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final movedMeters = _movedMeters;

    return AppPage(
      title: widget.title,
      body: Builder(
        builder: (context) {
          // Lu dans le corps : hauteur du dock (la carte passe dessous).
          final inset = MediaQuery.paddingOf(context).bottom;
          return Stack(
            children: [
              // Carte : on écoute les pointeurs pour animer le soulèvement du
              // repère.
              Listener(
                onPointerDown: (_) => _onPointerDown(),
                onPointerUp: (_) => _onPointerUp(),
                onPointerCancel: (_) => _onPointerUp(),
                child: FlutterMap(
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
              ),

              // Repère fixe au centre : se soulève pendant le geste, la pointe
              // (et le point-cible au sol) visent le centre exact de la carte.
              IgnorePointer(child: Center(child: CenterPin(lifted: _lifted))),

              // « Ma position », au-dessus du dock.
              Positioned(
                right: AppSpacing.base,
                bottom: inset + AppSpacing.sm,
                child: MapRoundButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Centrer sur ma position',
                  loading: _locating,
                  onPressed: _locating ? null : _recenterOnUser,
                ),
              ),
            ],
          );
        },
      ),
      dock: AppDock(
        status: PickerInfo(
          addressLabel: widget.addressLabel,
          center: _center,
          movedMeters: movedMeters,
          moved: (movedMeters ?? 0) > _movedThresholdMeters,
          onResetToAddress: _resetToAddress,
        ),
        actions: [
          DockAction(
            label: widget.confirmLabel,
            icon: Icons.check_rounded,
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }

  /// Distance du grand cercle (Haversine) en mètres entre deux points.
  static double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.latitude - a.latitude);
    final dLon = rad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(a.latitude)) *
            math.cos(rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}

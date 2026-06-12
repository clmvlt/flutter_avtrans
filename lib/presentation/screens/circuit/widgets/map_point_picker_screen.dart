import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/mapbox_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';

/// Écran de sélection / ajustement d'un point GPS sur une carte Mapbox.
///
/// Interaction « pose ta localisation » (style Uber / Google Maps) : un repère
/// reste fixe au centre, on **glisse la carte** pour l'amener sur le bon
/// endroit. Le repère se **soulève** pendant le geste et **retombe** au relâcher
/// (retour haptique), laissant voir un point-cible au sol = l'emplacement exact.
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

  /// Adresse à confirmer (affichée dans la fiche). `null` = simple point GPS.
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
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          // Carte : on écoute les pointeurs pour animer le soulèvement du repère.
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

          // Repère fixe au centre : se soulève pendant le geste, la pointe (et
          // le point-cible au sol) visent le centre exact de la carte.
          IgnorePointer(child: Center(child: _CenterPin(lifted: _lifted))),

          // Bas de l'écran : bouton « ma position » au-dessus de la fiche.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    right: AppSpacing.base,
                    bottom: AppSpacing.sm,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
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
                ),
                _BottomPanel(
                  addressLabel: widget.addressLabel,
                  center: _center,
                  movedMeters: _movedMeters,
                  moved: (_movedMeters ?? 0) > _movedThresholdMeters,
                  confirmLabel: widget.confirmLabel,
                  onConfirm: _confirm,
                  onResetToAddress: _resetToAddress,
                ),
              ],
            ),
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

/// Repère central animé : une pastille-cible reste au sol (centre exact) tandis
/// que la « goutte » se soulève pendant le geste et retombe au relâcher.
class _CenterPin extends StatelessWidget {
  const _CenterPin({required this.lifted});

  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: lifted ? 1 : 0),
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Point-cible au sol (emplacement exact retenu).
            Transform.scale(
              scale: 1 + 0.18 * t,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: 0.20),
                  border: Border.all(color: colors.primary, width: 2),
                ),
              ),
            ),
            // « Goutte » : pointe sur le centre, se soulève pendant le geste.
            Transform.translate(
              offset: Offset(0, -23 - 12 * t),
              child: Icon(
                Icons.location_on,
                size: 46,
                color: colors.primary,
                shadows: [
                  Shadow(
                    color: Color.fromRGBO(0, 0, 0, 0.25 + 0.15 * t),
                    blurRadius: 8 + 6 * t,
                    offset: Offset(0, 3 + 4 * t),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Fiche basse : adresse (ou point GPS) + statut vivant + validation.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.addressLabel,
    required this.center,
    required this.movedMeters,
    required this.moved,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onResetToAddress,
  });

  final String? addressLabel;
  final LatLng center;
  final double? movedMeters;
  final bool moved;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final VoidCallback onResetToAddress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final isAddress = addressLabel != null;

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
              // Hint de découverte du geste.
              Row(
                children: [
                  Icon(Icons.touch_app_outlined,
                      size: 16, color: colors.mutedForeground),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Glissez la carte pour ajuster le point',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colors.mutedForeground),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              if (isAddress) ...[
                Text(
                  addressLabel!,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                _StatusLine(
                  moved: moved,
                  movedMeters: movedMeters,
                  onReset: onResetToAddress,
                  colors: colors,
                  textTheme: textTheme,
                ),
              ] else ...[
                Text(
                  'Nouveau point GPS',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.pin_drop_outlined,
                        size: 16, color: colors.mutedForeground),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${center.latitude.toStringAsFixed(6)}, '
                      '${center.longitude.toStringAsFixed(6)}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colors.mutedForeground),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
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

/// Ligne de statut en mode adresse : « positionné » vs « déplacé de X ».
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.moved,
    required this.movedMeters,
    required this.onReset,
    required this.colors,
    required this.textTheme,
  });

  final bool moved;
  final double? movedMeters;
  final VoidCallback onReset;
  final AppColors colors;
  final TextTheme textTheme;

  static String _fmt(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    if (!moved) {
      return Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Positionné sur l\'adresse',
            style: textTheme.bodySmall?.copyWith(color: colors.foreground),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.adjust_rounded, size: 16, color: colors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Déplacé de ${_fmt(movedMeters ?? 0)} de l\'adresse',
            style: textTheme.bodySmall?.copyWith(color: colors.foreground),
          ),
        ),
        GestureDetector(
          onTap: onReset,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              'Revenir',
              style: textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

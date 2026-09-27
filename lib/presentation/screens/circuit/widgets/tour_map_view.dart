import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/mapbox_constants.dart';
import '../../../../data/models/tour_model.dart';
import '../../../../data/models/tour_stop.dart';
import 'tour_map_parts.dart';

/// Canevas carte d'une tournée : tuiles Mapbox + tracé + arrêts numérotés +
/// dépôt. Réutilisé en aperçu (bascule Liste/Carte) et en plein écran.
class TourMapView extends StatefulWidget {
  const TourMapView({
    super.key,
    required this.tour,
    this.selected,
    this.onStopTap,
    this.onMapTap,
    this.fitPadding = EdgeInsets.zero,
  });

  final Tour tour;
  final TourStop? selected;
  final void Function(TourStop stop)? onStopTap;
  final VoidCallback? onMapTap;

  /// Marge ajoutée au cadrage initial, pour ne pas cacher de repère sous un
  /// élément posé sur la carte (dock).
  final EdgeInsets fitPadding;

  @override
  State<TourMapView> createState() => _TourMapViewState();
}

class _TourMapViewState extends State<TourMapView> {
  static const LatLng _franceCenter = LatLng(46.6, 2.4);

  // Instance unique : évite que les tuiles se rechargent à chaque rebuild.
  final TileLayer _tileLayer = MapboxConstants.tileLayer();

  LatLng _ll(double lat, double lon) => LatLng(lat, lon);

  @override
  Widget build(BuildContext context) {
    final tour = widget.tour;
    final stops = tour.activeStops;

    final allPoints = <LatLng>[
      if (tour.depot != null) _ll(tour.depot!.lat, tour.depot!.lon),
      ...stops.map((s) => _ll(s.lat, s.lon)),
      ...tour.routeGeometry.map((p) => _ll(p.lat, p.lon)),
    ];

    return FlutterMap(
      options: MapOptions(
        initialCenter: allPoints.isNotEmpty ? allPoints.first : _franceCenter,
        initialZoom: 13,
        minZoom: 3,
        maxZoom: 20,
        initialCameraFit: allPoints.length >= 2
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(allPoints),
                padding: const EdgeInsets.all(56) + widget.fitPadding,
              )
            : null,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (_, __) => widget.onMapTap?.call(),
      ),
      children: [
        _tileLayer,
        if (tour.hasRoute)
          PolylineLayer(
            polylines: [
              Polyline(
                points: tour.routeGeometry
                    .map((p) => _ll(p.lat, p.lon))
                    .toList(),
                strokeWidth: 5,
                color: MapPalette.accent,
                borderStrokeWidth: 2,
                borderColor: MapPalette.halo,
              ),
            ],
          ),
        MarkerLayer(markers: _markers(tour)),
        // Enveloppé d'une SafeArea : reste visible au-dessus du dock.
        const SimpleAttributionWidget(
          source: Text(MapboxConstants.attribution),
        ),
      ],
    );
  }

  List<Marker> _markers(Tour tour) {
    final markers = <Marker>[];

    if (tour.depot != null) {
      markers.add(
        Marker(
          point: _ll(tour.depot!.lat, tour.depot!.lon),
          width: 38,
          height: 38,
          child: Semantics(
            label: 'Départ',
            child: Container(
              decoration: BoxDecoration(
                color: MapPalette.ink,
                shape: BoxShape.circle,
                border: Border.all(color: MapPalette.halo, width: 2),
                boxShadow: MapPalette.shadow,
              ),
              child: Icon(Icons.home_rounded, size: 20, color: MapPalette.halo),
            ),
          ),
        ),
      );
    }

    final stops = tour.activeStops;
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final selected = identical(stop, widget.selected);
      final onTap =
          widget.onStopTap == null ? null : () => widget.onStopTap!(stop);
      markers.add(
        Marker(
          point: _ll(stop.lat, stop.lon),
          width: 34,
          height: 34,
          child: Semantics(
            button: onTap != null,
            selected: selected,
            label: 'Arrêt ${i + 1}, ${stop.label}',
            onTap: onTap,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? MapPalette.ink : MapPalette.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: MapPalette.halo, width: 2),
                  boxShadow: MapPalette.shadow,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: MapPalette.onAccent,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }
}

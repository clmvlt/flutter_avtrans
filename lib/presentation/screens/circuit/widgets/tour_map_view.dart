import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/mapbox_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/tour_model.dart';
import '../../../../data/models/tour_stop.dart';

/// Canevas carte d'une tournée : tuiles Mapbox + tracé + arrêts numérotés +
/// dépôt. Réutilisé en aperçu (switch Liste/Carte) et en plein écran.
class TourMapView extends StatefulWidget {
  const TourMapView({
    super.key,
    required this.tour,
    this.selected,
    this.onStopTap,
    this.onMapTap,
  });

  final Tour tour;
  final TourStop? selected;
  final void Function(TourStop stop)? onStopTap;
  final VoidCallback? onMapTap;

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
    final colors = context.colors;
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
                padding: const EdgeInsets.all(56),
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
                color: colors.primary,
                borderStrokeWidth: 2,
                borderColor: Colors.white,
              ),
            ],
          ),
        MarkerLayer(markers: _markers(tour, colors)),
        const SimpleAttributionWidget(
          source: Text(MapboxConstants.attribution),
        ),
      ],
    );
  }

  List<Marker> _markers(Tour tour, AppColors colors) {
    final markers = <Marker>[];

    if (tour.depot != null) {
      markers.add(
        Marker(
          point: _ll(tour.depot!.lat, tour.depot!.lon),
          width: 38,
          height: 38,
          child: Container(
            decoration: BoxDecoration(
              color: colors.foreground,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: colors.cardShadow,
            ),
            child: const Icon(Icons.home_rounded, size: 20, color: Colors.white),
          ),
        ),
      );
    }

    final stops = tour.activeStops;
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final selected = identical(stop, widget.selected);
      markers.add(
        Marker(
          point: _ll(stop.lat, stop.lon),
          width: 34,
          height: 34,
          child: GestureDetector(
            onTap: widget.onStopTap == null
                ? null
                : () => widget.onStopTap!(stop),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? colors.foreground : colors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: colors.cardShadow,
              ),
              alignment: Alignment.center,
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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

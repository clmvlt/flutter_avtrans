import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/address_ocr_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/address_suggestion.dart';
import '../../../../data/models/tour_stop.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_empty_state.dart';
import 'address_picker_sheet.dart';
import 'live_address_scanner.dart';
import 'map_point_picker_screen.dart';

/// Étape 1 de l'assistant : ajouter les adresses de la tournée (scan caméra,
/// saisie, ou point GPS posé sur la carte). « Suivant » passe au tri.
class TourAddressesStep extends StatefulWidget {
  const TourAddressesStep({
    super.key,
    required this.tourId,
    required this.onNext,
  });

  final String tourId;
  final VoidCallback onNext;

  @override
  State<TourAddressesStep> createState() => _TourAddressesStepState();
}

class _TourAddressesStepState extends State<TourAddressesStep> {
  static const LatLng _franceCenter = LatLng(46.6, 2.4);

  Future<void> _addManual() async {
    final picked = await AddressPickerSheet.show(context);
    if (!mounted || picked == null) return;
    final confirmed = await _confirmOnMap(picked);
    if (!mounted || confirmed == null) return;
    await sl.tourService.addStop(widget.tourId, confirmed);
  }

  Future<void> _confirmScanned(String query) async {
    final picked = await AddressPickerSheet.show(
      context,
      initialQuery: query,
      fromScan: true,
    );
    if (!mounted || picked == null) return;
    final confirmed = await _confirmOnMap(picked);
    if (!mounted || confirmed == null) return;
    await sl.tourService.addStop(widget.tourId, confirmed);
  }

  Future<AddressSuggestion?> _confirmOnMap(AddressSuggestion suggestion) async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPointPickerScreen(
          initial: LatLng(suggestion.lat, suggestion.lon),
          title: 'Confirmer l\'adresse',
          confirmLabel: 'Ajouter à la tournée',
          addressLabel: suggestion.label,
        ),
      ),
    );
    if (result == null) return null;
    return suggestion.copyWith(lat: result.latitude, lon: result.longitude);
  }

  Future<void> _addGpsPoint() async {
    final initial = await _currentLatLng() ?? _franceCenter;
    if (!mounted) return;
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPointPickerScreen(
          initial: initial,
          title: 'Placer un point GPS',
          confirmLabel: 'Ajouter le point',
        ),
      ),
    );
    if (!mounted || result == null) return;
    await sl.tourService.addStop(
      widget.tourId,
      AddressSuggestion.manualPoint(result.latitude, result.longitude),
    );
  }

  Future<LatLng?> _currentLatLng() async {
    var position = await sl.locationService.getLastKnownPosition();
    position ??= await sl.locationService.getCurrentPosition();
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: sl.tourService,
      builder: (context, _) {
        final tour = sl.tourService.tourById(widget.tourId);
        if (tour == null) return const SizedBox.shrink();
        final stops = tour.stops;

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(title: Text(tour.name)),
          body: Column(
            children: [
              if (AddressOcrService.isSupported)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.base,
                    AppSpacing.screen,
                    0,
                  ),
                  child: LiveAddressScanner(onConfirm: _confirmScanned),
                ),
              Expanded(
                child: stops.isEmpty
                    ? _buildEmpty()
                    : _buildList(tour.stops),
              ),
              _buildActionBar(stops.isNotEmpty, colors),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return const AppEmptyState(
      icon: Icons.add_location_alt_outlined,
      title: 'Aucune adresse',
      subtitle:
          'Vise une adresse avec la caméra, saisis-la ou pose un point GPS pour l\'ajouter.',
    );
  }

  Widget _buildList(List<TourStop> stops) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.base,
        AppSpacing.screen,
        AppSpacing.lg,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Adresses · ${stops.length}',
            style: textTheme.titleSmall?.copyWith(color: colors.mutedForeground),
          ),
        ),
        for (var i = 0; i < stops.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _AddressTile(
              stop: stops[i],
              onRemove: () => sl.tourService.removeStopAt(widget.tourId, i),
            ),
          ),
      ],
    );
  }

  Widget _buildActionBar(bool hasStops, AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        boxShadow: colors.navShadow,
        border: colors.isDarkMode
            ? Border(top: BorderSide(color: colors.border))
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Saisir',
                      icon: Icons.keyboard_alt_outlined,
                      variant: ButtonVariant.secondary,
                      onPressed: _addManual,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      text: 'Point GPS',
                      icon: Icons.add_location_alt_outlined,
                      variant: ButtonVariant.outline,
                      onPressed: _addGpsPoint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                text: 'Suivant',
                icon: Icons.arrow_forward_rounded,
                onPressed: hasStops ? widget.onNext : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.stop, required this.onRemove});

  final TourStop stop;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final secondary = stop.address.secondaryLine;
    final showSecondary =
        secondary.isNotEmpty && !stop.label.contains(secondary);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 20, color: colors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.label,
                  style: textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showSecondary) ...[
                  const SizedBox(height: 2),
                  Text(secondary, style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 20, color: colors.mutedForeground),
            tooltip: 'Retirer',
            onPressed: onRemove,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}

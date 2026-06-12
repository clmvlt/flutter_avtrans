import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/address_ocr_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/address_suggestion.dart';
import '../../../data/models/tour_model.dart';
import '../../../data/services/tour_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import 'widgets/address_picker_sheet.dart';
import 'widgets/live_address_scanner.dart';
import 'widgets/map_point_picker_screen.dart';
import 'widgets/tour_name_dialog.dart';

/// Détail d'une tournée : caméra live de scan + liste des arrêts (adresses).
///
/// La tournée est lue depuis [TourService] (source de vérité persistée) : tout
/// ajout/suppression est immédiatement sauvegardé et survit au redémarrage.
class TourDetailScreen extends StatefulWidget {
  const TourDetailScreen({super.key, required this.tourId});

  final String tourId;

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  TourService get _service => sl.tourService;

  Future<void> _addManual() async {
    final picked = await AddressPickerSheet.show(context);
    if (!mounted || picked == null) return;
    final confirmed = await _confirmOnMap(picked);
    if (!mounted || confirmed == null) return;
    await _service.addStop(widget.tourId, confirmed);
  }

  /// Appelé par le scanner live quand l'utilisateur valide l'adresse détectée.
  Future<void> _confirmScanned(String query) async {
    final picked = await AddressPickerSheet.show(
      context,
      initialQuery: query,
      fromScan: true,
    );
    if (!mounted || picked == null) return;
    final confirmed = await _confirmOnMap(picked);
    if (!mounted || confirmed == null) return;
    await _service.addStop(widget.tourId, confirmed);
  }

  /// Affiche l'adresse sur une carte Mapbox pour vérifier / ajuster le point
  /// GPS avant de l'ajouter. Renvoie l'adresse aux coordonnées confirmées, ou
  /// `null` si l'utilisateur annule.
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

  /// Ouvre une carte pour poser directement un point GPS (sans adresse).
  Future<void> _addGpsPoint() async {
    var position = await sl.locationService.getLastKnownPosition();
    position ??= await sl.locationService.getCurrentPosition();
    if (!mounted) return;
    final initial = position != null
        ? LatLng(position.latitude, position.longitude)
        : const LatLng(48.8566, 2.3522); // Paris par défaut
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
    await _service.addStop(
      widget.tourId,
      AddressSuggestion.manualPoint(result.latitude, result.longitude),
    );
  }

  Future<void> _removeStop(int index) async {
    await _service.removeStopAt(widget.tourId, index);
  }

  Future<void> _rename(Tour tour) async {
    final name = await showTourNameDialog(
      context,
      title: 'Renommer la tournée',
      actionLabel: 'Enregistrer',
      initialName: tour.name,
    );
    if (!mounted || name == null) return;
    await _service.renameTour(tour.id, name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final tour = _service.tourById(widget.tourId);

        // Tournée supprimée (depuis la liste) alors que ce détail est ouvert.
        if (tour == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
          return Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(),
          );
        }

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            title: Text(tour.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Renommer',
                onPressed: () => _rename(tour),
              ),
            ],
          ),
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
              Expanded(child: _buildStops(tour)),
              _buildActionBar(colors),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStops(Tour tour) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    if (tour.stops.isEmpty) {
      return const AppEmptyState(
        icon: Icons.add_location_alt_outlined,
        title: 'Aucune adresse',
        subtitle:
            'Vise une adresse avec la caméra ou saisis-la pour l\'ajouter à cette tournée.',
      );
    }

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
            'Arrêts · ${tour.stopCount}',
            style: textTheme.titleSmall?.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ),
        for (int i = 0; i < tour.stops.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _StopTile(
              index: i,
              suggestion: tour.stops[i],
              onRemove: () => _removeStop(i),
            ),
          ),
      ],
    );
  }

  Widget _buildActionBar(AppColors colors) {
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
          child: Row(
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
        ),
      ),
    );
  }
}

/// Carte d'un arrêt de la tournée.
class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.index,
    required this.suggestion,
    required this.onRemove,
  });

  final int index;
  final AddressSuggestion suggestion;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final secondary = suggestion.secondaryLine;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '${index + 1}',
              style: textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.label,
                  style: textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (secondary.isNotEmpty &&
                    !suggestion.label.contains(secondary)) ...[
                  const SizedBox(height: 2),
                  Text(secondary, style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 20, color: colors.mutedForeground),
            onPressed: onRemove,
            tooltip: 'Retirer',
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}

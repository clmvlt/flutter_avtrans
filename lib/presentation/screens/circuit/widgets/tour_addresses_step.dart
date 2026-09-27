import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/address_ocr_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/address_suggestion.dart';
import '../../../../data/models/tour_stop.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dock.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/app_state_views.dart';
import 'address_picker_sheet.dart';
import 'live_address_scanner.dart';
import 'map_point_picker_screen.dart';
import 'tour_widgets.dart';

/// Étape 1 de l'assistant : ajouter les adresses de la tournée (scan caméra,
/// saisie, ou point GPS posé sur la carte).
///
/// Le scanner est le point focal ; les autres façons d'ajouter sont des
/// lignes. Le dock dit la prochaine étape : « Continuer » dès qu'il y a une
/// adresse, sinon « Saisir une adresse ».
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
        if (tour == null) {
          return Scaffold(backgroundColor: colors.background, appBar: AppBar());
        }
        final stops = tour.stops;
        final hasScanner = AddressOcrService.isSupported;

        return AppPage(
          title: tour.name,
          body: AppScrollView(
            children: [
              if (hasScanner) ...[
                LiveAddressScanner(onConfirm: _confirmScanned),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppSectionHeader(
                title: hasScanner ? 'Ajouter autrement' : 'Ajouter une adresse',
              ),
              RowsCard(
                children: [
                  AppListRow(
                    icon: Icons.keyboard_alt_outlined,
                    iconColor: colors.primary,
                    title: 'Saisir une adresse',
                    subtitle: 'Rue, ville ou code postal',
                    onTap: _addManual,
                  ),
                  AppListRow(
                    icon: Icons.add_location_alt_outlined,
                    iconColor: colors.primary,
                    title: 'Poser un point GPS',
                    subtitle: 'Place le point sur la carte',
                    onTap: _addGpsPoint,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSectionHeader(
                title: 'Adresses',
                summary: stops.isEmpty
                    ? null
                    : DisplayFormat.plural(stops.length, 'adresse'),
              ),
              if (stops.isEmpty)
                AppEmptyCard(
                  icon: Icons.add_location_alt_outlined,
                  message: 'Aucune adresse pour l\'instant',
                  detail: hasScanner
                      ? 'Vise une adresse avec la caméra, saisis-la ou pose '
                          'un point GPS.'
                      : 'Saisis une adresse ou pose un point GPS.',
                )
              else
                RowsCard(
                  children: [
                    for (var i = 0; i < stops.length; i++)
                      _AddressRow(
                        key: ValueKey(stops[i].id),
                        stop: stops[i],
                        onRemove: () =>
                            sl.tourService.removeStopAt(widget.tourId, i),
                      ),
                  ],
                ),
            ],
          ),
          dock: AppDock(
            actions: [
              if (stops.isEmpty)
                DockAction(
                  label: 'Saisir une adresse',
                  icon: Icons.keyboard_alt_outlined,
                  onPressed: _addManual,
                )
              else
                DockAction(
                  label: 'Continuer',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: widget.onNext,
                  semanticsHint: 'Passe au choix de l\'ordre de la tournée',
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Une adresse ajoutée : icône, libellé, ligne secondaire, bouton « Retirer ».
class _AddressRow extends StatelessWidget {
  const _AddressRow({super.key, required this.stop, required this.onRemove});

  final TourStop stop;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final secondary = stop.address.secondaryLine;
    final showSecondary =
        secondary.isNotEmpty && !stop.label.contains(secondary);

    return AppListRow(
      icon: stop.address.isManualPoint
          ? Icons.pin_drop_outlined
          : Icons.location_on_outlined,
      iconColor: colors.primary,
      title: stop.label,
      subtitle: showSecondary ? secondary : null,
      showChevron: false,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      trailing: AppIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Retirer',
        color: colors.mutedForeground,
        onPressed: onRemove,
      ),
    );
  }
}

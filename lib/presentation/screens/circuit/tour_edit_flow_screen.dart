import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/tour_model.dart';
import 'tour_delivery_screen.dart';
import 'widgets/tour_addresses_step.dart';
import 'widgets/tour_order_step.dart';

/// Assistant d'édition d'une tournée en deux étapes :
/// 1. **Adresses** — ajouter les points (scan / saisie / GPS) ;
/// 2. **Ordre** — trier (auto/manuel), définir le départ, liste ↔ carte.
///
/// « Valider » bascule la tournée en mode livraison ([TourDeliveryScreen]).
/// Le passage entre étapes est interne (pas d'empilement de routes) ; le retour
/// système recule d'une étape avant de quitter.
class TourEditFlowScreen extends StatefulWidget {
  const TourEditFlowScreen({super.key, required this.tourId});

  final String tourId;

  @override
  State<TourEditFlowScreen> createState() => _TourEditFlowScreenState();
}

class _TourEditFlowScreenState extends State<TourEditFlowScreen> {
  int _step = 0;

  void _goToOrder() => setState(() => _step = 1);
  void _goToAddresses() => setState(() => _step = 0);

  Future<void> _validate() async {
    await sl.tourService.setStatus(widget.tourId, TourStatus.delivery);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TourDeliveryScreen(tourId: widget.tourId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Sur l'étape Ordre, le retour recule à l'étape Adresses plutôt que quitter.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 1) _goToAddresses();
      },
      child: _step == 0
          ? TourAddressesStep(tourId: widget.tourId, onNext: _goToOrder)
          : TourOrderStep(
              tourId: widget.tourId,
              onBack: _goToAddresses,
              onValidated: _validate,
            ),
    );
  }
}

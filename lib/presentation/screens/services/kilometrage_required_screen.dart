import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/app_searchable_select.dart';
import '../../widgets/widgets.dart';

/// Écran affiché quand l'utilisateur doit saisir un kilométrage
class KilometrageRequiredScreen extends StatefulWidget {
  /// Véhicule pré-sélectionné (dernier utilisé)
  final String? lastVehiculeId;

  /// Si true, l'écran ne peut pas être fermé sans saisir le kilométrage
  final bool isRequired;

  const KilometrageRequiredScreen({
    super.key,
    this.lastVehiculeId,
    this.isRequired = false,
  });

  @override
  State<KilometrageRequiredScreen> createState() =>
      _KilometrageRequiredScreenState();
}

class _KilometrageRequiredScreenState extends State<KilometrageRequiredScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kmController = TextEditingController();

  List<Vehicule> _vehicules = [];
  Vehicule? _selectedVehicule;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _canClose = false;

  @override
  void initState() {
    super.initState();
    // Si non obligatoire, permettre la fermeture dès le départ
    _canClose = !widget.isRequired;
    _loadData();
  }

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Charger les véhicules et le dernier kilométrage en parallèle
    final results = await Future.wait([
      sl.vehiculeRepository.getAllVehicules(),
      sl.vehiculeRepository.getMyLastKilometrage(),
    ]);

    if (!mounted) return;

    final vehiculesResult = results[0] as dynamic;
    final lastKmResult = results[1] as dynamic;

    String? lastVehiculeId = widget.lastVehiculeId;

    // Récupérer l'ID du dernier véhicule utilisé
    lastKmResult.fold(
      (_) {},
      (response) {
        if (response.lastKilometrage?.vehiculeId != null) {
          lastVehiculeId = response.lastKilometrage!.vehiculeId;
        }
      },
    );

    vehiculesResult.fold(
      (failure) {
        _showError(failure.message);
        setState(() => _isLoading = false);
      },
      (vehicules) {
        setState(() {
          _vehicules = vehicules;
          // Pré-sélectionner le dernier véhicule utilisé
          if (lastVehiculeId != null) {
            _selectedVehicule = vehicules.cast<Vehicule>().firstWhere(
                  (v) => v.id == lastVehiculeId,
                  orElse: () => vehicules.first as Vehicule,
                );
          }
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicule == null) {
      _showError('Veuillez sélectionner un véhicule');
      return;
    }

    setState(() => _isSubmitting = true);

    final km = int.parse(_kmController.text);
    final request = AddKilometrageRequest(
      vehiculeId: _selectedVehicule!.id,
      km: km,
    );

    final result = await sl.vehiculeRepository.addKilometrage(request);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isSubmitting = false);
        _showError(failure.message);
      },
      (kilometrage) {
        // Ne pas faire de setState ici car la page va se fermer
        _canClose = true;
        Navigator.of(context).pop(true);
      },
    );
  }

  void _showError(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.bgSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(color: colors.error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      canPop: _canClose,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_canClose) {
          // L'utilisateur a essayé de fermer sans avoir saisi le kilométrage
          setState(() => _canClose = true);
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        backgroundColor: colors.bgPrimary,
        appBar: AppBar(
          title: Text(widget.isRequired ? 'Kilométrage requis' : 'Saisir un kilométrage'),
          backgroundColor: colors.bgSecondary,
          automaticallyImplyLeading: !widget.isRequired,
          actions: widget.isRequired
              ? null
              : [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                    tooltip: 'Fermer',
                  ),
                ],
        ),
        body: _isLoading
          ? const LoadingIndicator(message: 'Chargement des véhicules...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInfoCard(colors),
                    const SizedBox(height: AppSpacing.xl),
                    _buildVehiculeSelector(colors),
                    const SizedBox(height: AppSpacing.base),
                    _buildKilometrageInput(colors),
                    const SizedBox(height: AppSpacing.xl),
                    _buildSubmitButton(colors),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildInfoCard(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.infoBg,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: colors.info),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colors.info, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kilométrage journalier',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Veuillez renseigner le kilométrage de votre véhicule avant de commencer votre journée.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiculeSelector(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Véhicule',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSearchableSelect<Vehicule>(
          items: _vehicules,
          selectedItem: _selectedVehicule,
          onChanged: (value) {
            setState(() => _selectedVehicule = value);
          },
          itemLabel: (v) => v.immat,
          itemSubtitle: (v) => '${v.brand} ${v.model}${v.latestKm != null ? ' • ${v.latestKm} km' : ''}',
          itemIcon: (v) => Icons.directions_car,
          prefixIcon: Icons.directions_car_outlined,
          placeholder: _vehicules.isEmpty ? 'Aucun véhicule disponible' : 'Sélectionner un véhicule',
          sheetTitle: 'Choisir un véhicule',
          searchHint: 'Rechercher un véhicule...',
          emptyMessage: 'Aucun véhicule trouvé',
          enabled: _vehicules.isNotEmpty,
          validator: (value) {
            if (value == null) {
              return 'Veuillez sélectionner un véhicule';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildKilometrageInput(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kilométrage actuel',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _kmController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Ex: 125000',
            hintStyle: TextStyle(
              color: colors.textMuted,
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(Icons.speed, color: colors.primary),
            suffixText: 'km',
            suffixStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
            filled: true,
            fillColor: colors.bgSecondary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.base),
              borderSide: BorderSide(color: colors.borderPrimary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.base),
              borderSide: BorderSide(color: colors.borderPrimary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.base),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.base),
              borderSide: BorderSide(color: colors.error),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez saisir le kilométrage';
            }
            final km = int.tryParse(value);
            if (km == null || km <= 0) {
              return 'Kilométrage invalide';
            }
            if (_selectedVehicule?.latestKm != null &&
                km < _selectedVehicule!.latestKm!) {
              return 'Le kilométrage doit être supérieur au dernier relevé (${_selectedVehicule!.latestKm} km)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton(AppColors colors) {
    return AppButton(
      text: 'Valider le kilométrage',
      icon: Icons.check,
      onPressed: _submit,
      isLoading: _isSubmitting,
      backgroundColor: colors.primary,
      foregroundColor: Colors.white,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';

/// Écran de saisie du kilométrage - design shadcn/ui
class KilometrageRequiredScreen extends StatefulWidget {
  final String? lastVehiculeId;
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

    final results = await Future.wait([
      sl.vehiculeRepository.getAllVehicules(),
      sl.vehiculeRepository.getMyLastKilometrage(),
    ]);

    if (!mounted) return;

    final vehiculesResult = results[0] as dynamic;
    final lastKmResult = results[1] as dynamic;

    String? lastVehiculeId = widget.lastVehiculeId;

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
        _canClose = true;
        Navigator.of(context).pop(true);
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      canPop: _canClose,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_canClose) {
          setState(() => _canClose = true);
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(widget.isRequired ? 'Kilométrage requis' : 'Saisir un kilométrage'),
          automaticallyImplyLeading: !widget.isRequired,
          actions: widget.isRequired
              ? null
              : [
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: colors.mutedForeground),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: () => Navigator.of(context).pop(false),
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
                      const AppAlert(
                        title: 'Kilométrage journalier',
                        description: 'Veuillez renseigner le kilométrage de votre véhicule avant de commencer votre journée.',
                        variant: AlertVariant.info,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildVehiculeSelector(colors),
                      const SizedBox(height: AppSpacing.base),
                      _buildKilometrageInput(colors),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        text: 'Valider le kilométrage',
                        icon: Icons.check,
                        onPressed: _submit,
                        isLoading: _isSubmitting,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildVehiculeSelector(AppColors colors) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Véhicule',
          style: textTheme.titleSmall?.copyWith(
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSearchableSelect<Vehicule>(
          items: _vehicules,
          selectedItem: _selectedVehicule,
          onChanged: (value) => setState(() => _selectedVehicule = value),
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
            if (value == null) return 'Veuillez sélectionner un véhicule';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildKilometrageInput(AppColors colors) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kilométrage actuel',
          style: textTheme.titleSmall?.copyWith(
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _kmController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: textTheme.titleLarge?.copyWith(
            color: colors.foreground,
          ),
          decoration: InputDecoration(
            hintText: 'Ex: 125000',
            prefixIcon: Icon(Icons.speed, color: colors.primary, size: 20),
            suffixText: 'km',
            suffixStyle: textTheme.labelMedium?.copyWith(
              color: colors.mutedForeground,
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
}

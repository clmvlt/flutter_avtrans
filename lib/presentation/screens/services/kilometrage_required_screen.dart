import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';

/// Saisie du kilométrage du jour : véhicule + compteur dans la carte hero,
/// « Valider le kilométrage » dans le dock.
///
/// Ouvert en `fullscreenDialog` quand la saisie est obligatoire
/// ([isRequired]) : pas de bouton de fermeture dans la barre de titre, et le
/// retour système ferme l'écran avec `false` (comportement d'origine, géré
/// par le `PopScope`).
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

class _KilometrageRequiredScreenState extends State<KilometrageRequiredScreen>
    with DockNoticeMixin {
  final _formKey = GlobalKey<FormState>();
  final _kmController = TextEditingController();

  List<Vehicule> _vehicules = [];
  Vehicule? _selectedVehicule;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _canClose = false;
  String? _loadError;

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
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final (vehiculesResult, lastKmResult) = await (
      sl.vehiculeRepository.getAllVehicules(),
      sl.vehiculeRepository.getMyLastKilometrage(),
    ).wait;

    if (!mounted) return;

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
        setState(() {
          _loadError = failure.message;
          _isLoading = false;
        });
      },
      (vehicules) {
        setState(() {
          _vehicules = vehicules;
          // Garde : `vehicules.first` levait une exception sur une liste vide.
          if (lastVehiculeId != null && vehicules.isNotEmpty) {
            _selectedVehicule = vehicules.firstWhere(
              (v) => v.id == lastVehiculeId,
              orElse: () => vehicules.first,
            );
          }
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    clearDockNotice();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedVehicule == null) {
      showDockError('Sélectionne un véhicule');
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
        showDockError(failure.message);
      },
      (kilometrage) {
        _canClose = true;
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showForm = !_isLoading && _loadError == null && _vehicules.isNotEmpty;

    return PopScope(
      canPop: _canClose,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_canClose) {
          setState(() => _canClose = true);
          Navigator.of(context).pop(false);
        }
      },
      // Scaffold plutôt qu'AppPage : la barre de titre ne doit pas proposer
      // de fermeture quand la saisie est obligatoire.
      child: Scaffold(
        backgroundColor: colors.background,
        extendBody: true,
        appBar: AppBar(
          title: Text(
            widget.isRequired ? 'Kilométrage requis' : 'Saisir le kilométrage',
          ),
          automaticallyImplyLeading: !widget.isRequired,
        ),
        body: _buildBody(),
        bottomNavigationBar: AppDock(
          skeleton: _isLoading,
          notice: dockNotice,
          onDismissNotice: clearDockNotice,
          actions: [
            if (showForm)
              DockAction(
                label: 'Valider le kilométrage',
                icon: Icons.check_rounded,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppScrollView(children: [_KilometrageSkeleton()]);
    }
    if (_loadError != null) {
      return AppScrollView(
        children: [AppErrorState(message: _loadError!, onRetry: _loadData)],
      );
    }
    if (_vehicules.isEmpty) {
      return const AppScrollView(
        children: [
          AppEmptyCard(
            icon: Icons.directions_car_outlined,
            message: 'Aucun véhicule disponible',
            detail: 'Impossible de saisir un kilométrage pour l\'instant.',
          ),
        ],
      );
    }

    return AppScrollView(
      children: [
        AppHeroCard(
          icon: Icons.speed_rounded,
          accent: context.colors.domainVehicule,
          title: 'Kilométrage journalier',
          subtitle: 'À relever avant de commencer ta journée',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildVehiculeSelector(),
                const SizedBox(height: AppSpacing.lg),
                _buildKilometrageInput(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehiculeSelector() {
    return AppSearchableSelect<Vehicule>(
      label: 'Véhicule',
      items: _vehicules,
      selectedItem: _selectedVehicule,
      onChanged: (value) => setState(() => _selectedVehicule = value),
      itemLabel: (v) => v.immat,
      itemSubtitle: (v) => '${v.brand} ${v.model}'
          '${v.latestKm != null ? ' · ${DisplayFormat.km(v.latestKm!)}' : ''}',
      itemIcon: (v) => Icons.directions_car_rounded,
      prefixIcon: Icons.directions_car_outlined,
      placeholder: 'Choisir un véhicule',
      sheetTitle: 'Choisir un véhicule',
      searchHint: 'Rechercher un véhicule…',
      emptyMessage: 'Aucun véhicule trouvé',
      enabled: _vehicules.isNotEmpty,
      validator: (value) {
        if (value == null) return 'Sélectionne un véhicule';
        return null;
      },
    );
  }

  Widget _buildKilometrageInput() {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final latestKm = _selectedVehicule?.latestKm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppFieldLabel('Kilométrage actuel'),
        TextFormField(
          controller: _kmController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: textTheme.titleLarge?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            hintText: 'Ex. 125000',
            prefixIcon: Icon(
              Icons.speed_rounded,
              color: colors.mutedForeground,
              size: 20,
            ),
            suffixText: 'km',
            suffixStyle: textTheme.labelMedium?.copyWith(
              color: colors.mutedForeground,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Saisis le kilométrage';
            }
            final km = int.tryParse(value);
            if (km == null || km <= 0) {
              return 'Kilométrage invalide';
            }
            if (_selectedVehicule?.latestKm != null &&
                km < _selectedVehicule!.latestKm!) {
              return 'Le kilométrage doit être au moins égal au dernier '
                  'relevé (${DisplayFormat.km(_selectedVehicule!.latestKm!)})';
            }
            return null;
          },
        ),
        if (latestKm != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              'Dernier relevé : ${DisplayFormat.km(latestKm)}',
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

/// Squelette : ligne d'état du hero et deux champs.
class _KilometrageSkeleton extends StatelessWidget {
  const _KilometrageSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevation: AppCardElevation.hero,
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSkeleton(
                width: AppLayout.heroIconBox,
                height: AppLayout.heroIconBox,
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(width: 180, height: 22),
                    SizedBox(height: AppSpacing.sm),
                    AppSkeleton(width: 220, height: 15),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          AppSkeleton(width: 70, height: 15),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton(height: 56),
          SizedBox(height: AppSpacing.lg),
          AppSkeleton(width: 130, height: 15),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton(height: 56),
        ],
      ),
    );
  }
}

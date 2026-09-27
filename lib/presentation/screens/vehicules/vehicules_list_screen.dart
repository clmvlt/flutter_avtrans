import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';
import 'vehicule_details_screen.dart';
import 'widgets/vehicule_hero_card.dart';

/// Liste des véhicules de la flotte : recherche en tête, une ligne par
/// véhicule (immatriculation, marque et modèle, dernier kilométrage).
class VehiculesListScreen extends StatefulWidget {
  const VehiculesListScreen({super.key});

  @override
  State<VehiculesListScreen> createState() => _VehiculesListScreenState();
}

class _VehiculesListScreenState extends State<VehiculesListScreen>
    with DockNoticeMixin {
  /// `null` tant que le premier chargement n'a pas abouti.
  List<Vehicule>? _vehicules;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadVehicules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Recharge la liste. Une fois la liste affichée, un échec passe par le
  /// dock et la liste reste visible.
  Future<void> _loadVehicules() async {
    final result = await sl.vehiculeRepository.getAllVehicules();

    if (!mounted) return;

    result.fold(
      (failure) {
        if (_vehicules == null) {
          setState(() => _error = failure.message);
        } else {
          showDockError(failure.message);
        }
      },
      (vehicules) => setState(() {
        _vehicules = vehicules;
        _error = null;
      }),
    );
  }

  Future<void> _retry() async {
    setState(() => _error = null);
    await _loadVehicules();
  }

  List<Vehicule> _filter(List<Vehicule> vehicules) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return vehicules;
    return vehicules.where((v) {
      return v.immat.toLowerCase().contains(query) ||
          v.brand.toLowerCase().contains(query) ||
          v.model.toLowerCase().contains(query);
    }).toList();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Future<void> _openVehicule(Vehicule vehicule) async {
    clearDockNotice();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VehiculeDetailsScreen(vehiculeId: vehicule.id),
      ),
    );
    if (!mounted) return;
    await _loadVehicules();
  }

  /// « Renault Master · 123 456 km »
  String _subtitle(Vehicule v) {
    final name = vehiculeName(v);
    return [
      if (name.isNotEmpty) name,
      if (v.latestKm != null) DisplayFormat.km(v.latestKm!),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Véhicules',
      body: _buildBody(),
      dock: AppDock(notice: dockNotice, onDismissNotice: clearDockNotice),
    );
  }

  Widget _buildBody() {
    final vehicules = _vehicules;
    final error = _error;

    if (vehicules == null) {
      return AppScrollView(
        onRefresh: error != null ? _retry : null,
        children: [
          if (error != null)
            AppErrorState(message: error, onRetry: _retry)
          else
            const _ListSkeleton(),
        ],
      );
    }

    if (vehicules.isEmpty) {
      return AppScrollView(
        onRefresh: _loadVehicules,
        children: const [
          AppEmptyCard(
            icon: Icons.directions_car_outlined,
            message: 'Aucun véhicule',
            detail: 'La flotte est vide pour l\'instant.',
          ),
        ],
      );
    }

    final filtered = _filter(vehicules);
    final colors = context.colors;

    return AppScrollView(
      onRefresh: _loadVehicules,
      children: [
        _SearchField(
          controller: _searchController,
          hasQuery: _searchQuery.isNotEmpty,
          onChanged: (value) => setState(() => _searchQuery = value),
          onClear: _clearSearch,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (filtered.isEmpty)
          AppEmptyCard(
            icon: Icons.search_off_rounded,
            message: 'Aucun véhicule trouvé',
            detail: 'Essaie avec une autre immatriculation ou marque.',
            actionLabel: 'Effacer',
            onAction: _clearSearch,
          )
        else ...[
          AppSectionHeader(
            title: _searchQuery.trim().isEmpty ? 'Flotte' : 'Résultats',
            summary: DisplayFormat.plural(filtered.length, 'véhicule'),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (final v in filtered)
                  AppListRow(
                    key: ValueKey(v.id),
                    icon: Icons.directions_car_rounded,
                    iconColor: colors.domainVehicule,
                    title: v.immat,
                    subtitle: _subtitle(v),
                    subtitleMaxLines: 1,
                    onTap: () => _openVehicule(v),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Champ de recherche en tête de liste (immatriculation, marque, modèle).
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      textCapitalization: TextCapitalization.characters,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      style: textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: 'Rechercher une immat, une marque…',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: hasQuery
            ? IconButton(
                onPressed: onClear,
                tooltip: 'Effacer',
                icon: const Icon(Icons.close_rounded, size: 18),
              )
            : null,
      ),
    );
  }
}

/// Squelette du premier chargement : champ de recherche, en-tête, lignes.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSkeleton(height: 56),
        SizedBox(height: AppSpacing.lg),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: AppSkeleton(width: 100, height: 16),
        ),
        SizedBox(height: AppSpacing.md),
        AppListSkeleton(rows: 6),
      ],
    );
  }
}

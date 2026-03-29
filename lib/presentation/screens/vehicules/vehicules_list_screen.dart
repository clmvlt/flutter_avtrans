import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';
import 'vehicule_details_screen.dart';

/// Écran de liste des véhicules
class VehiculesListScreen extends StatefulWidget {
  const VehiculesListScreen({super.key});

  @override
  State<VehiculesListScreen> createState() => _VehiculesListScreenState();
}

class _VehiculesListScreenState extends State<VehiculesListScreen> {
  List<Vehicule> _vehicules = [];
  List<Vehicule> _filteredVehicules = [];
  bool _isLoading = true;
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

  void _filterVehicules(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredVehicules = _vehicules;
      } else {
        _filteredVehicules = _vehicules.where((v) {
          return v.immat.toLowerCase().contains(_searchQuery) ||
              v.brand.toLowerCase().contains(_searchQuery) ||
              v.model.toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  Future<void> _loadVehicules() async {
    setState(() => _isLoading = true);

    final result = await sl.vehiculeRepository.getAllVehicules();

    if (!mounted) return;

    result.fold(
      (failure) {
        _showError(failure.message);
        setState(() => _isLoading = false);
      },
      (vehicules) {
        setState(() {
          _vehicules = vehicules;
          _filteredVehicules = vehicules;
          _isLoading = false;
        });
      },
    );
  }

  void _showError(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.destructive, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(color: colors.destructive),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Véhicules'),
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Chargement...')
          : Column(
              children: [
                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterVehicules,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un véhicule...',
                      hintStyle: TextStyle(color: colors.mutedForeground),
                      prefixIcon: Icon(Icons.search, color: colors.mutedForeground),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: colors.mutedForeground),
                              onPressed: () {
                                _searchController.clear();
                                _filterVehicules('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        borderSide: BorderSide(color: colors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    style: TextStyle(color: colors.foreground),
                  ),
                ),
                // Liste des véhicules
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadVehicules,
                    color: colors.primary,
                    backgroundColor: colors.card,
                    child: _filteredVehicules.isEmpty
                        ? AppEmptyState(
                            icon: Icons.directions_car_outlined,
                            title: _searchQuery.isNotEmpty
                                ? 'Aucun véhicule trouvé'
                                : 'Aucun véhicule',
                            subtitle: _searchQuery.isNotEmpty
                                ? 'Essayez avec un autre terme de recherche'
                                : null,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.base,
                            ),
                            itemCount: _filteredVehicules.length,
                            itemBuilder: (context, index) {
                              final vehicule = _filteredVehicules[index];
                              return _buildVehiculeCard(vehicule, colors);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVehiculeCard(Vehicule vehicule, AppColors colors) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VehiculeDetailsScreen(vehiculeId: vehicule.id),
            ),
          ).then((_) => _loadVehicules());
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.directions_car,
                  color: colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicule.immat,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${vehicule.brand} ${vehicule.model}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                    if (vehicule.latestKm != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.speed,
                            size: 14,
                            color: colors.mutedForeground,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${vehicule.latestKm} km',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colors.mutedForeground,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

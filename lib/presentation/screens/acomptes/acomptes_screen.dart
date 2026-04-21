import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';

/// Page de gestion des acomptes
class AcomptesScreen extends StatefulWidget {
  const AcomptesScreen({super.key});

  @override
  State<AcomptesScreen> createState() => _AcomptesScreenState();
}

class _AcomptesScreenState extends State<AcomptesScreen> {
  final List<Acompte> _acomptes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _error;

  // Filtres
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  AcompteStatus? _filterStatus;
  double? _filterMontantMin;
  double? _filterMontantMax;
  bool _hasActiveFilters = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAcomptes();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreAcomptes();
    }
  }

  void _updateFiltersState() {
    _hasActiveFilters = _filterStartDate != null ||
        _filterEndDate != null ||
        _filterStatus != null ||
        _filterMontantMin != null ||
        _filterMontantMax != null;
  }

  AcompteListParams _buildParams({int page = 0}) {
    return AcompteListParams(
      page: page,
      size: 20,
      startDate: _filterStartDate,
      endDate: _filterEndDate,
      status: _filterStatus,
      montantMin: _filterMontantMin,
      montantMax: _filterMontantMax,
      sortBy: 'createdAt',
      sortDirection: SortDirection.desc,
    );
  }

  Future<void> _loadAcomptes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await sl.acompteRepository.getMyAcomptes(_buildParams());

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (response) {
        setState(() {
          _acomptes.clear();
          _acomptes.addAll(response.content);
          _currentPage = 0;
          _hasMore = !response.last;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _loadMoreAcomptes() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    final result = await sl.acompteRepository.getMyAcomptes(
      _buildParams(page: _currentPage + 1),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isLoadingMore = false);
      },
      (response) {
        setState(() {
          _acomptes.addAll(response.content);
          _currentPage++;
          _hasMore = !response.last;
          _isLoadingMore = false;
        });
      },
    );
  }

  Future<void> _cancelAcompte(Acompte acompte) async {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Annuler la demande',
          style: textTheme.titleLarge?.copyWith(color: colors.foreground),
        ),
        content: Text(
          'Voulez-vous vraiment annuler cette demande d\'acompte ?',
          style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
            ),
            child: Text(
              'Non',
              style: textTheme.labelLarge?.copyWith(color: colors.mutedForeground),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: colors.destructive,
              minimumSize: const Size(48, 48),
            ),
            child: Text(
              'Oui, annuler',
              style: textTheme.labelLarge?.copyWith(color: colors.destructive),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await sl.acompteRepository.cancelAcompte(acompte.uuid);

    if (!mounted) return;

    result.fold(
      (failure) => _showError(failure.message),
      (success) {
        _showSuccess('Demande annulée');
        // Recharge la liste pour refléter les changements
        _loadAcomptes();
      },
    );
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateAcompteSheet(
        onCreated: (acompte) {
          setState(() => _acomptes.insert(0, acompte));
        },
      ),
    );
  }

  void _showFiltersDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FiltersSheet(
        initialStartDate: _filterStartDate,
        initialEndDate: _filterEndDate,
        initialStatus: _filterStatus,
        initialMontantMin: _filterMontantMin,
        initialMontantMax: _filterMontantMax,
        onApply: (startDate, endDate, status, montantMin, montantMax) {
          setState(() {
            _filterStartDate = startDate;
            _filterEndDate = endDate;
            _filterStatus = status;
            _filterMontantMin = montantMin;
            _filterMontantMax = montantMax;
            _updateFiltersState();
          });
          _loadAcomptes();
        },
        onClear: () {
          setState(() {
            _filterStartDate = null;
            _filterEndDate = null;
            _filterStatus = null;
            _filterMontantMin = null;
            _filterMontantMax = null;
            _hasActiveFilters = false;
          });
          _loadAcomptes();
        },
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Mes acomptes'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list, size: 22),
                onPressed: _showFiltersDialog,
                tooltip: 'Filtres',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: colors.primary,
        child: Icon(Icons.add, color: colors.primaryForeground),
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const LoadingIndicator(message: 'Chargement...');
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.destructive),
              const SizedBox(height: AppSpacing.base),
              Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.base),
              AppButton(
                text: 'Réessayer',
                onPressed: _loadAcomptes,
                backgroundColor: colors.primary,
                foregroundColor: colors.primaryForeground,
              ),
            ],
          ),
        ),
      );
    }

    if (_acomptes.isEmpty) {
      if (_hasActiveFilters) {
        return AppEmptyState(
          icon: Icons.filter_list_off,
          title: 'Aucun acompte ne correspond aux filtres',
          actionText: 'Effacer les filtres',
          onAction: () {
            setState(() {
              _filterStartDate = null;
              _filterEndDate = null;
              _filterStatus = null;
              _filterMontantMin = null;
              _filterMontantMax = null;
              _hasActiveFilters = false;
            });
            _loadAcomptes();
          },
        );
      }
      return const AppEmptyState(
        icon: Icons.payments_outlined,
        title: 'Aucune demande d\'acompte',
        subtitle: 'Appuyez sur + pour créer une demande',
      );
    }

    return Column(
      children: [
        // Barre de filtres actifs
        if (_hasActiveFilters) _buildActiveFiltersBar(colors, textTheme),
        // Liste des acomptes
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAcomptes,
            color: colors.primary,
            backgroundColor: colors.card,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.base),
              itemCount: _acomptes.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _acomptes.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: CircularProgressIndicator(color: colors.primary),
                    ),
                  );
                }

                final acompte = _acomptes[index];
                return _buildAcompteCard(acompte, colors);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFiltersBar(AppColors colors, TextTheme textTheme) {
    final filters = <String>[];
    if (_filterStatus != null) filters.add(_filterStatus!.label);
    if (_filterStartDate != null || _filterEndDate != null) {
      filters.add('Période');
    }
    if (_filterMontantMin != null || _filterMontantMax != null) {
      filters.add('Montant');
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      color: colors.card,
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 20, color: colors.primary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Filtres: ${filters.join(', ')}',
              style: textTheme.labelSmall?.copyWith(
                color: colors.mutedForeground,
                letterSpacing: 1,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _filterStartDate = null;
                _filterEndDate = null;
                _filterStatus = null;
                _filterMontantMin = null;
                _filterMontantMax = null;
                _hasActiveFilters = false;
              });
              _loadAcomptes();
            },
            icon: Icon(Icons.close, size: 20, color: colors.mutedForeground),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
    );
  }

  Widget _buildAcompteCard(Acompte acompte, AppColors colors) {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête: montant et statut
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Icon(
                    Icons.euro,
                    color: colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${acompte.montant.toStringAsFixed(2)} \u20ac',
                        style: textTheme.titleLarge?.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        acompte.createdAt != null
                            ? dateFormat.format(acompte.createdAt!)
                            : 'Date non disponible',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(acompte.status, colors),
              ],
            ),
            // Raison
            if (acompte.raison != null && acompte.raison!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.base),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.muted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: colors.mutedForeground,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        acompte.raison!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Info validation/rejet
            if (acompte.status == AcompteStatus.approved) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 20, color: colors.success),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    acompte.validatedAt != null
                        ? 'Approuv\u00e9 le ${dateFormat.format(acompte.validatedAt!)}'
                        : 'Approuv\u00e9',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.success,
                    ),
                  ),
                ],
              ),
            ],
            if (acompte.status == AcompteStatus.rejected) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.destructive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: colors.destructive.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cancel, size: 20, color: colors.destructive),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        acompte.rejectionReason ?? 'Rejet\u00e9',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.destructive,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Info paiement
            if (acompte.isPaid) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: colors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.paid, size: 20, color: colors.success),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        acompte.paidDate != null
                            ? 'Pay\u00e9 le ${dateFormat.format(acompte.paidDate!)}'
                            : 'Pay\u00e9',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Bouton annuler
            if (acompte.status == AcompteStatus.pending) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelAcompte(acompte),
                  icon: Icon(Icons.cancel_outlined, size: 20, color: colors.destructive),
                  label: Text(
                    'Annuler la demande',
                    style: textTheme.labelLarge?.copyWith(color: colors.destructive),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.destructive),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AcompteStatus status, AppColors colors) {
    final textTheme = Theme.of(context).textTheme;
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case AcompteStatus.pending:
        bgColor = colors.warning.withValues(alpha: 0.1);
        textColor = colors.warning;
        icon = Icons.schedule;
        break;
      case AcompteStatus.approved:
        bgColor = colors.success.withValues(alpha: 0.1);
        textColor = colors.success;
        icon = Icons.check_circle;
        break;
      case AcompteStatus.rejected:
        bgColor = colors.destructive.withValues(alpha: 0.1);
        textColor = colors.destructive;
        icon = Icons.cancel;
        break;
      case AcompteStatus.cancelled:
        bgColor = colors.mutedForeground.withValues(alpha: 0.1);
        textColor = colors.mutedForeground;
        icon = Icons.block;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            status.label,
            style: textTheme.labelSmall?.copyWith(
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet pour créer un nouvel acompte
class _CreateAcompteSheet extends StatefulWidget {
  final Function(Acompte) onCreated;

  const _CreateAcompteSheet({required this.onCreated});

  @override
  State<_CreateAcompteSheet> createState() => _CreateAcompteSheetState();
}

class _CreateAcompteSheetState extends State<_CreateAcompteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _raisonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _montantController.dispose();
    _raisonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final montant = double.tryParse(_montantController.text) ?? 0;
    final raisonText = _raisonController.text.trim();
    final request = AcompteCreateRequest(
      montant: montant,
      raison: raisonText.isEmpty ? '' : raisonText,
    );

    final result = await sl.acompteRepository.createAcompte(request);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (acompte) {
        widget.onCreated(acompte);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Demande d\'acompte cr\u00e9\u00e9e avec succ\u00e8s')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.base,
        left: AppSpacing.base,
        right: AppSpacing.base,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.base,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Titre
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Nouvelle demande d\'acompte',
                    style: textTheme.titleLarge?.copyWith(
                      color: colors.foreground,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, size: 22, color: colors.mutedForeground),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            // Champ montant
            TextFormField(
              controller: _montantController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Montant (\u20ac)',
                labelStyle: textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
                prefixIcon: Icon(Icons.euro, color: colors.primary),
              ),
              style: textTheme.bodyMedium?.copyWith(color: colors.foreground),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir un montant';
                }
                final montant = double.tryParse(value);
                if (montant == null || montant <= 0) {
                  return 'Veuillez saisir un montant valide';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.base),
            // Champ raison
            TextFormField(
              controller: _raisonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Raison (facultative)',
                labelStyle: textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
                prefixIcon: Icon(Icons.description_outlined, color: colors.primary),
              ),
              style: textTheme.bodyMedium?.copyWith(color: colors.foreground),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Bouton soumettre
            AppButton(
              text: 'Soumettre la demande',
              onPressed: _isSubmitting ? null : _submit,
              isLoading: _isSubmitting,
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryForeground,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet pour les filtres
class _FiltersSheet extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final AcompteStatus? initialStatus;
  final double? initialMontantMin;
  final double? initialMontantMax;
  final Function(DateTime?, DateTime?, AcompteStatus?, double?, double?) onApply;
  final VoidCallback onClear;

  const _FiltersSheet({
    required this.initialStartDate,
    required this.initialEndDate,
    required this.initialStatus,
    required this.initialMontantMin,
    required this.initialMontantMax,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  AcompteStatus? _status;
  final _montantMinController = TextEditingController();
  final _montantMaxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _status = widget.initialStatus;
    _montantMinController.text = widget.initialMontantMin?.toString() ?? '';
    _montantMaxController.text = widget.initialMontantMax?.toString() ?? '';
  }

  @override
  void dispose() {
    _montantMinController.dispose();
    _montantMaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Titre
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtres',
                style: textTheme.titleLarge?.copyWith(
                  color: colors.foreground,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, size: 22, color: colors.mutedForeground),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          // Statut
          Text(
            'STATUT',
            style: textTheme.labelSmall?.copyWith(
              color: colors.mutedForeground,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final status in AcompteStatus.values)
                FilterChip(
                  label: Text(
                    status.label,
                    style: textTheme.labelSmall,
                  ),
                  selected: _status == status,
                  onSelected: (selected) {
                    setState(() => _status = selected ? status : null);
                  },
                  selectedColor: colors.primary.withValues(alpha: 0.2),
                  checkmarkColor: colors.primary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          // Dates
          Text(
            'P\u00c9RIODE',
            style: textTheme.labelSmall?.copyWith(
              color: colors.mutedForeground,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        locale: const Locale('fr', 'FR'),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                    icon: Icon(Icons.calendar_today, size: 20, color: colors.primary),
                    label: Text(
                      _startDate != null
                          ? DateFormat('dd/MM/yyyy').format(_startDate!)
                          : 'D\u00e9but',
                      style: textTheme.bodySmall?.copyWith(color: colors.foreground),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        locale: const Locale('fr', 'FR'),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                    icon: Icon(Icons.calendar_today, size: 20, color: colors.primary),
                    label: Text(
                      _endDate != null
                          ? DateFormat('dd/MM/yyyy').format(_endDate!)
                          : 'Fin',
                      style: textTheme.bodySmall?.copyWith(color: colors.foreground),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          // Montants
          Text(
            'MONTANT',
            style: textTheme.labelSmall?.copyWith(
              color: colors.mutedForeground,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _montantMinController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Min (\u20ac)',
                    hintStyle: textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
                  ),
                  style: textTheme.bodyMedium?.copyWith(color: colors.foreground),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _montantMaxController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Max (\u20ac)',
                    hintStyle: textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
                  ),
                  style: textTheme.bodyMedium?.copyWith(color: colors.foreground),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Boutons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      widget.onClear();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.border),
                    ),
                    child: Text(
                      'Effacer',
                      style: textTheme.labelLarge?.copyWith(color: colors.mutedForeground),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: AppButton(
                  text: 'Appliquer',
                  onPressed: () {
                    final montantMin = double.tryParse(_montantMinController.text);
                    final montantMax = double.tryParse(_montantMaxController.text);
                    widget.onApply(_startDate, _endDate, _status, montantMin, montantMax);
                    Navigator.pop(context);
                  },
                  backgroundColor: colors.primary,
                  foregroundColor: colors.primaryForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

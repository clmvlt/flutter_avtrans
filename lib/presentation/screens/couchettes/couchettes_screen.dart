import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';

/// Page de gestion des couchettes
class CouchettesScreen extends StatefulWidget {
  const CouchettesScreen({super.key});

  @override
  State<CouchettesScreen> createState() => _CouchettesScreenState();
}

class _CouchettesScreenState extends State<CouchettesScreen> {
  final List<Couchette> _couchettes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _error;
  bool _isCreating = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCouchettes();
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
      _loadMoreCouchettes();
    }
  }

  Future<void> _loadCouchettes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await sl.couchetteRepository.getMyCouchettes(page: 0);

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
          _couchettes.clear();
          _couchettes.addAll(response.content);
          _currentPage = 0;
          _hasMore = !response.last;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _loadMoreCouchettes() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final result = await sl.couchetteRepository.getMyCouchettes(
      page: _currentPage + 1,
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() => _isLoadingMore = false),
      (response) {
        setState(() {
          _couchettes.addAll(response.content);
          _currentPage++;
          _hasMore = !response.last;
          _isLoadingMore = false;
        });
      },
    );
  }

  Future<void> _createCouchette() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    final result = await sl.couchetteRepository.createCouchette();

    if (!mounted) return;

    setState(() => _isCreating = false);

    result.fold(
      (failure) => _showError(failure.message),
      (couchette) {
        setState(() => _couchettes.insert(0, couchette));
        _showSuccess('Couchette ajoutée pour aujourd\'hui');
      },
    );
  }

  Future<void> _deleteCouchette(Couchette couchette) async {
    final colors = context.colors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text('Supprimer', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colors.foreground)),
        content: Text(
          'Voulez-vous vraiment supprimer cette couchette ?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text('Non', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.mutedForeground)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colors.destructive, minimumSize: const Size(48, 48)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await sl.couchetteRepository.deleteCouchette(couchette.uuid);
    if (!mounted) return;

    result.fold(
      (failure) => _showError(failure.message),
      (_) {
        setState(
            () => _couchettes.removeWhere((c) => c.uuid == couchette.uuid));
        _showSuccess('Couchette supprimée');
      },
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

  bool _isToday(String? dateStr) {
    if (dateStr == null) return false;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return dateStr == today;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Mes couchettes'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isCreating ? null : _createCouchette,
        backgroundColor: colors.primary,
        child: _isCreating
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primaryForeground,
                ),
              )
            : Icon(Icons.add, color: colors.primaryForeground),
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Chargement...');
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.destructive),
            const SizedBox(height: AppSpacing.base),
            Text(_error!,
                style: TextStyle(color: colors.mutedForeground),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              text: 'Réessayer',
              onPressed: _loadCouchettes,
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryForeground,
            ),
          ],
        ),
      );
    }

    if (_couchettes.isEmpty) {
      return const AppEmptyState(
        icon: Icons.hotel_outlined,
        title: 'Aucune couchette',
        subtitle: 'Appuyez sur + pour ajouter une couchette',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCouchettes,
      color: colors.primary,
      backgroundColor: colors.card,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.base),
        itemCount: _couchettes.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _couchettes.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: CircularProgressIndicator(color: colors.primary),
              ),
            );
          }
          return _buildCouchetteCard(_couchettes[index], colors);
        },
      ),
    );
  }

  Widget _buildCouchetteCard(Couchette couchette, AppColors colors) {
    final dateFormat = DateFormat('EEEE dd MMMM yyyy', 'fr_FR');
    final isToday = _isToday(couchette.date);

    String dateDisplay = 'Date non disponible';
    if (couchette.date != null) {
      try {
        final date = DateTime.parse(couchette.date!);
        dateDisplay = dateFormat.format(date);
        // Capitalize first letter
        dateDisplay =
            dateDisplay[0].toUpperCase() + dateDisplay.substring(1);
      } catch (_) {
        dateDisplay = couchette.date!;
      }
    }

    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(Icons.hotel, color: colors.info, size: 22),
            ),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateDisplay,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                  if (isToday)
                    Text(
                      'Aujourd\'hui',
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                ],
              ),
            ),
            if (isToday)
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20, color: colors.destructive),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => _deleteCouchette(couchette),
                tooltip: 'Supprimer',
              ),
          ],
        ),
      ),
    );
  }
}

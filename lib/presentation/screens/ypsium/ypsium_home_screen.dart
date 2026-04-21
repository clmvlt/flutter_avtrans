import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ypsium_models.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/widgets.dart';
import 'ypsium_spooler_screen.dart';
import 'ypsium_transport_detail_screen.dart';
import 'ypsium_vehicule_screen.dart';

/// Écran principal Ypsium après connexion
/// Affiche la liste des ordres de transport du jour
class YpsiumHomeScreen extends StatefulWidget {
  const YpsiumHomeScreen({super.key});

  @override
  State<YpsiumHomeScreen> createState() => _YpsiumHomeScreenState();
}

class _YpsiumHomeScreenState extends State<YpsiumHomeScreen> {
  List<YpsiumTransportOrder> _orders = [];
  bool _isLoading = true;
  bool _isLoadingReferentiels = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  bool _showTermines = false;

  @override
  void initState() {
    super.initState();
    sl.ypsiumSpoolerService.addListener(_onSpoolerChanged);
    _loadReferentiels();
    _loadTransports();
  }

  @override
  void dispose() {
    sl.ypsiumSpoolerService.removeListener(_onSpoolerChanged);
    super.dispose();
  }

  void _onSpoolerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadReferentiels() async {
    final result = await sl.ypsiumReferentielRepository.loadAll();
    if (!mounted) return;
    result.fold(
      (_) {},
      (_) {},
    );
    setState(() => _isLoadingReferentiels = false);
  }

  Future<void> _loadTransports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dateStr = DateFormat('yyyyMMdd').format(_selectedDate);
    final result = await sl.ypsiumTransportRepository.getListeTransport(
      date: dateStr,
    );

    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _errorMessage = failure.message;
        _isLoading = false;
      }),
      (orders) => setState(() {
        _orders = orders;
        _isLoading = false;
      }),
    );
  }

  void _changeDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _loadTransports();
  }

  void _openDetail(YpsiumTransportOrder order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YpsiumTransportDetailScreen(order: order),
      ),
    );
    if (mounted) _loadTransports();
  }

  void _openVehicules() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const YpsiumVehiculeScreen()),
    );
  }

  void _openSpooler() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const YpsiumSpoolerScreen()),
    );
  }

  Future<void> _logout() async {
    await sl.ypsiumAuthRepository.logout();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _buildPopupMenu(AppColors colors) {
    final spoolerCount = sl.ypsiumSpoolerService.pendingCount;
    return PopupMenuButton<String>(
      icon: Badge(
        isLabelVisible: spoolerCount > 0,
        label: Text(
          '$spoolerCount',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
        backgroundColor: colors.destructive,
        textColor: colors.destructiveForeground,
        child: Icon(Icons.more_vert, size: 22, color: colors.foreground),
      ),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colors.border),
      ),
      offset: const Offset(0, 48),
      onSelected: (value) {
        switch (value) {
          case 'spooler':
            _openSpooler();
          case 'vehicules':
            _openVehicules();
          case 'logout':
            _logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'spooler',
          height: 48,
          child: Row(
            children: [
              Icon(Icons.outbox, size: 20, color: colors.foreground),
              const SizedBox(width: AppSpacing.md),
              Text('Spooler', style: TextStyle(color: colors.foreground)),
              if (spoolerCount > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  text: '$spoolerCount',
                  variant: BadgeVariant.destructive,
                ),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: 'vehicules',
          height: 48,
          child: Row(
            children: [
              Icon(Icons.directions_car, size: 20, color: colors.foreground),
              const SizedBox(width: AppSpacing.md),
              Text('Véhicule / Km', style: TextStyle(color: colors.foreground)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          height: 48,
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: colors.destructive),
              const SizedBox(width: AppSpacing.md),
              Text('Déconnexion', style: TextStyle(color: colors.destructive)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.foreground, size: 20),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Ypsium',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: colors.foreground,
          ),
        ),
        actions: [
          _buildPopupMenu(colors),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransports,
        color: colors.primary,
        backgroundColor: colors.card,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date picker
              _buildDateSelector(colors),
              const SizedBox(height: AppSpacing.base),

              // Referentiels loading indicator
              if (_isLoadingReferentiels)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.mutedForeground,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Chargement des référentiels...',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isLoading)
                _buildLoadingSkeleton(colors)
              else if (_errorMessage != null)
                _buildError(colors)
              else if (_orders.isEmpty)
                _buildEmpty(colors)
              else
                ..._buildGroupedOrders(colors),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        final colors = context.colors;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: colors.primary,
              brightness: colors.isDarkMode ? Brightness.dark : Brightness.light,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: colors.card,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              dayStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.foreground),
              headerBackgroundColor: colors.primary,
              headerForegroundColor: colors.primaryForeground,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && !DateUtils.isSameDay(picked, _selectedDate)) {
      setState(() => _selectedDate = picked);
      _loadTransports();
    }
  }

  Widget _buildDateSelector(AppColors colors) {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final dateLabel = isToday
        ? "Aujourd'hui"
        : DateFormat('EEEE d MMMM', 'fr_FR').format(_selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, size: 22, color: colors.foreground),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => _changeDate(-1),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Text(
                dateLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.foreground,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, size: 22, color: colors.foreground),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => _changeDate(1),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedOrders(AppColors colors) {
    final aEnlever = _orders.where((o) => o.isAEnlever).toList();
    final enleves = _orders.where((o) => o.isEnleve).toList();
    final livres = _orders.where((o) => o.isLivre).toList();

    final widgets = <Widget>[];

    if (aEnlever.isNotEmpty) {
      widgets.add(_buildSectionHeader(
        colors,
        'À enlever',
        aEnlever.length,
        Icons.upload_outlined,
        colors.info,
      ));
      for (final order in aEnlever) {
        widgets.add(_buildOrderCard(order, colors));
      }
    }

    if (enleves.isNotEmpty) {
      widgets.add(_buildSectionHeader(
        colors,
        'À livrer',
        enleves.length,
        Icons.download_outlined,
        colors.warning,
      ));
      for (final order in enleves) {
        widgets.add(_buildOrderCard(order, colors));
      }
    }

    if (livres.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
          child: GestureDetector(
            onTap: () => setState(() => _showTermines = !_showTermines),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 20, color: colors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Livrés',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.foreground,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${livres.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.success,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showTermines ? Icons.expand_less : Icons.expand_more,
                    size: 22,
                    color: colors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (_showTermines) {
        for (final order in livres) {
          widgets.add(_buildOrderCard(order, colors));
        }
      }
    }

    return widgets;
  }

  Widget _buildSectionHeader(
    AppColors colors,
    String title,
    int count,
    IconData icon,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.foreground,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(YpsiumTransportOrder order, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: () => _openDetail(order),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: client + état
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.client,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _buildEtatBadge(order, colors),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Enlèvement
                _buildStopRow(
                  colors: colors,
                  icon: Icons.upload_outlined,
                  iconColor: colors.info,
                  label: 'Enlèvement',
                  name: order.eNom,
                  ville: '${order.eCodePostal} ${order.eVille}'.trim(),
                  heure: order.eHeureFormatted,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Container(
                    width: 1,
                    height: 12,
                    color: colors.border,
                  ),
                ),

                // Livraison
                _buildStopRow(
                  colors: colors,
                  icon: Icons.download_outlined,
                  iconColor: colors.success,
                  label: 'Livraison',
                  name: order.lNom,
                  ville: '${order.lCodePostal} ${order.lVille}'.trim(),
                  heure: order.lHeureFormatted,
                ),

                // N° ordre
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Ordre #${order.idOrdre}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStopRow({
    required AppColors colors,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String name,
    required String ville,
    required String heure,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isNotEmpty ? name : label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.foreground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (ville.isNotEmpty)
                Text(
                  ville,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (heure.isNotEmpty)
          Text(
            heure,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.foreground,
            ),
          ),
      ],
    );
  }

  Widget _buildEtatBadge(YpsiumTransportOrder order, AppColors colors) {
    BadgeVariant variant;
    switch (order.idEtat) {
      case 4:
      case 5:
        variant = BadgeVariant.success;
        break;
      case 2:
        variant = BadgeVariant.warning;
        break;
      default:
        variant = BadgeVariant.secondary;
    }
    return AppBadge(text: order.etatLabel, variant: variant);
  }

  Widget _buildLoadingSkeleton(AppColors colors) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppSkeleton(
            height: 140,
            borderRadius: AppRadius.lg,
          ),
        ),
      ),
    );
  }

  Widget _buildError(AppColors colors) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: _errorMessage!,
      actionText: 'Réessayer',
      onAction: _loadTransports,
    );
  }

  Widget _buildEmpty(AppColors colors) {
    return AppEmptyState(
      icon: Icons.inbox_outlined,
      title: 'Aucun ordre de transport',
      subtitle: 'Pas de commande prévue pour cette date',
    );
  }
}

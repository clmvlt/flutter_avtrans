import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/complete_profile_dialog.dart';
import '../../widgets/update_dialog.dart';
import '../absences/absences_screen.dart';
import '../acomptes/acomptes_screen.dart';
import '../auth/login_screen.dart';
import '../couchettes/couchettes_screen.dart';
import '../notifications/notifications_screen.dart';
import '../rapports/create_rapport_screen.dart';
import '../services/history_screen.dart';
import '../services/mes_heures_screen.dart';
import '../services/services_screen.dart';
import '../settings/settings_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../signatures/sign_screen.dart';
import '../signatures/signatures_screen.dart';
import '../todos/todos_screen.dart';
import '../uta/uta_map_screen.dart';
import '../vehicules/vehicules_list_screen.dart';
import '../ypsium/ypsium_login_screen.dart';

/// Page d'accueil — navigation bottom bar + grille d'outils
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  User? _user;
  bool _isLoading = true;
  bool _isCheckingUpdate = false;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
    _checkSignatureRequired();
    _loadUnreadCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkForUpdateOnResume();
      _checkSignatureRequired();
    }
  }

  Future<void> _checkForUpdateOnResume() async {
    if (_isCheckingUpdate) return;
    _isCheckingUpdate = true;
    try {
      final updateResponse = await sl.updateCheckerService.checkForUpdate();
      if (!mounted) return;
      if (updateResponse != null && updateResponse.latestVersion != null) {
        final currentVersion = await sl.updateCheckerService.currentVersionName;
        if (!mounted) return;
        await UpdateDialog.show(
          context,
          version: updateResponse.latestVersion!,
          currentVersion: currentVersion,
          onSkip: () {
            sl.updateCheckerService.skipVersion(
              updateResponse.latestVersion!.versionCode,
            );
          },
        );
      }
    } finally {
      _isCheckingUpdate = false;
    }
  }

  Future<void> _loadUser() async {
    _user = sl.authRepository.getCachedUser();
    if (_user != null) setState(() => _isLoading = false);

    final result = await sl.authRepository.getCurrentUser();
    if (!mounted) return;
    result.fold(
      (failure) {
        if (failure.message.contains('Session') || failure.message.contains('expir')) {
          _logout();
        } else if (_user == null) {
          setState(() => _isLoading = false);
        }
      },
      (user) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
        _checkProfileComplete(user);
      },
    );
  }

  Future<void> _checkSignatureRequired() async {
    final result = await sl.signatureRepository.getLastSignatureSummary();
    if (!mounted) return;
    result.fold(
      (_) {},
      (summary) {
        if (summary.needsToSign) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SignScreen(heuresLastMonth: summary.heuresLastMonth),
                ),
              );
            }
          });
        }
      },
    );
  }

  void _checkProfileComplete(User user) {
    if (!CompleteProfileDialog.isProfileIncomplete(user)) return;

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      CompleteProfileDialog.showIfNeeded(
        context,
        user: user,
        onComplete: _openEditProfile,
      );
    });
  }

  Future<void> _logout() async {
    await sl.authRepository.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _loadUnreadCount() async {
    final result = await sl.notificationRepository.getUnreadCount();
    if (!mounted) return;
    result.fold(
      (_) {},
      (count) => setState(() => _unreadNotificationCount = count),
    );
  }

  bool get _isAdminOrMecano {
    final roleName = _user?.role?.nom.toLowerCase() ?? '';
    return roleName == 'admin' || roleName == 'mecanicien';
  }

  // Navigation helpers
  void _openServices() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ServicesScreen()));
  void _openHistory() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
  void _openAbsences() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AbsencesScreen()));
  void _openMesHeures() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MesHeuresScreen()));
  void _openAcomptes() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AcomptesScreen()));
  void _openSignatures() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignaturesScreen()));
  void _openVehicules() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VehiculesListScreen()));
  void _openRapportVehicule() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateRapportScreen()));
  void _openUtaMap() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UtaMapScreen()));
  void _openTodos() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TodosScreen()));
  void _openNotifications() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    if (mounted) _loadUnreadCount();
  }
  void _openCouchettes() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CouchettesScreen()));
  void _openYpsium() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const YpsiumLoginScreen()));

  void _openSettings() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    if (mounted) _refreshUser();
  }

  void _openEditProfile() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (mounted) _refreshUser();
  }

  void _refreshUser() {
    final cachedUser = sl.authRepository.getCachedUser();
    if (cachedUser != null && cachedUser != _user) {
      setState(() => _user = cachedUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2.5))
          : RefreshIndicator(
              onRefresh: _loadUser,
              color: colors.primary,
              backgroundColor: colors.card,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // SliverAppBar collapsible
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    backgroundColor: colors.background,
                    surfaceTintColor: Colors.transparent,
                    title: Text(
                      'AVTRANS',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        letterSpacing: -0.3,
                        color: colors.foreground,
                      ),
                    ),
                    actions: [
                      // Notifications avec badge
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(Icons.notifications_outlined, size: 24, color: colors.mutedForeground),
                            onPressed: _openNotifications,
                            tooltip: 'Notifications',
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          ),
                          if (_unreadNotificationCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colors.destructive,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                child: Text(
                                  _unreadNotificationCount > 99
                                      ? '99+'
                                      : '$_unreadNotificationCount',
                                  style: TextStyle(
                                    color: colors.destructiveForeground,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.logout_rounded, size: 22, color: colors.mutedForeground),
                        onPressed: _logout,
                        tooltip: 'Deconnexion',
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      ),
                    ],
                  ),

                  // Contenu
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // En-tete utilisateur
                        _buildWelcomeHeader(colors, textTheme),
                        const SizedBox(height: AppSpacing.lg),

                        // Actions rapides — les plus utilisees
                        Text(
                          'Actions rapides',
                          style: textTheme.labelSmall?.copyWith(
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildQuickActions(colors),
                        const SizedBox(height: AppSpacing.lg),

                        // Tous les outils
                        Text(
                          'Tous les outils',
                          style: textTheme.labelSmall?.copyWith(
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildToolsGrid(colors, textTheme),
                        const SizedBox(height: AppSpacing.base),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// En-tete avec avatar, nom, role
  Widget _buildWelcomeHeader(AppColors colors, TextTheme textTheme) {
    final firstName = _user?.firstName ?? '';
    final lastName = _user?.lastName ?? '';
    final greeting = _getGreeting();
    final pictureUrl = _user?.pictureUrl;

    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: _openEditProfile,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              AppAvatar(
                imageUrl: pictureUrl,
                fallbackText: _getInitials(firstName, lastName),
                size: 52,
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$firstName $lastName',
                      style: textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    if (_user?.role != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppBadge(
                        text: _user!.role!.nom,
                        variant: BadgeVariant.secondary,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: colors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }

  /// Actions rapides — 3 boutons horizontaux (pointage, heures, historique)
  Widget _buildQuickActions(AppColors colors) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.play_circle_filled,
            label: 'Pointage',
            color: colors.primary,
            onTap: _openServices,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.schedule,
            label: 'Mes heures',
            color: colors.success,
            onTap: _openMesHeures,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.local_shipping,
            label: 'Ypsium',
            color: colors.chart4,
            onTap: _openYpsium,
          ),
        ),
      ],
    );
  }

  /// Grille d'outils — 2 colonnes, cartes lisibles
  Widget _buildToolsGrid(AppColors colors, TextTheme textTheme) {
    final tools = [
      _ToolItem(title: 'Historique', subtitle: 'Mes pointages', icon: Icons.history, color: colors.chart4, onTap: _openHistory),
      _ToolItem(title: 'Absences', subtitle: 'Gerer les demandes', icon: Icons.event_busy, color: colors.warning, onTap: _openAbsences),
      _ToolItem(title: 'Acomptes', subtitle: 'Demander un acompte', icon: Icons.payments, color: colors.info, onTap: _openAcomptes),
      _ToolItem(title: 'Signatures', subtitle: 'Signer vos heures', icon: Icons.draw, color: colors.success, onTap: _openSignatures),
      _ToolItem(title: 'Vehicules', subtitle: 'Gerer les vehicules', icon: Icons.directions_car, color: colors.chart4, onTap: _openVehicules),
      _ToolItem(title: 'Rapport', subtitle: 'Creer un rapport', icon: Icons.description, color: colors.chart3, onTap: _openRapportVehicule),
      if (_isAdminOrMecano)
        _ToolItem(title: 'Taches', subtitle: 'Gerer les todos', icon: Icons.checklist, color: colors.chart3, onTap: _openTodos),
      _ToolItem(title: 'Carte UTA', subtitle: 'Trouver une station', icon: Icons.map, color: colors.info, onTap: _openUtaMap),
      _ToolItem(title: 'Ypsium', subtitle: 'Transport / Commandes', icon: Icons.local_shipping, color: colors.chart4, onTap: _openYpsium),
      if (_user?.isCouchette == true)
        _ToolItem(title: 'Couchettes', subtitle: 'Gerer les couchettes', icon: Icons.hotel, color: colors.info, onTap: _openCouchettes),
      _ToolItem(title: 'Parametres', subtitle: 'Personnaliser l\'app', icon: Icons.settings_outlined, color: colors.mutedForeground, onTap: _openSettings),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) => _buildToolCard(tools[index], colors, textTheme),
    );
  }

  Widget _buildToolCard(_ToolItem tool, AppColors colors, TextTheme textTheme) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: tool.onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: tool.color.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(tool.icon, size: 22, color: tool.color),
              ),
              const Spacer(),
              Text(
                tool.title,
                style: textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                tool.subtitle,
                style: textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon apres-midi';
    return 'Bonsoir';
  }

  String _getInitials(String firstName, String lastName) {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }
}

/// Bouton d'action rapide — icone + label, touch target 48dp+
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: color.withValues(alpha: 0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

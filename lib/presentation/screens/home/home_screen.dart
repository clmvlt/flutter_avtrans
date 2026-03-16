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

/// Page d'accueil - design shadcn/ui
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

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'AVTRANS',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
            color: colors.foreground,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, size: 22, color: colors.mutedForeground),
                onPressed: _openNotifications,
                tooltip: 'Notifications',
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
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      _unreadNotificationCount > 99
                          ? '99+'
                          : '$_unreadNotificationCount',
                      style: TextStyle(
                        color: colors.destructiveForeground,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.logout, size: 18, color: colors.mutedForeground),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _loadUser,
              color: colors.primary,
              backgroundColor: colors.card,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(colors),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Outils',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.mutedForeground,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildToolsGrid(colors),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeHeader(AppColors colors) {
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
                size: 48,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$firstName $lastName',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                        letterSpacing: -0.3,
                      ),
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
              Icon(Icons.chevron_right, size: 18, color: colors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolsGrid(AppColors colors) {
    final tools = [
      _ToolItem(title: 'Services', subtitle: 'Gérer vos pointages', icon: Icons.access_time, color: colors.primary, onTap: _openServices),
      _ToolItem(title: 'Historique', subtitle: 'Services passés', icon: Icons.history, color: colors.chart4, onTap: _openHistory),
      _ToolItem(title: 'Mes heures', subtitle: 'Heures travaillées', icon: Icons.schedule, color: colors.success, onTap: _openMesHeures),
      _ToolItem(title: 'Absences', subtitle: 'Gérer les demandes', icon: Icons.event_busy, color: colors.warning, onTap: _openAbsences),
      _ToolItem(title: 'Acomptes', subtitle: 'Demander un acompte', icon: Icons.payments, color: colors.info, onTap: _openAcomptes),
      _ToolItem(title: 'Signatures', subtitle: 'Signer vos heures', icon: Icons.draw, color: colors.success, onTap: _openSignatures),
      _ToolItem(title: 'Véhicules', subtitle: 'Gérer les véhicules', icon: Icons.directions_car, color: colors.chart4, onTap: _openVehicules),
      _ToolItem(title: 'Rapport', subtitle: 'Créer un rapport', icon: Icons.description, color: colors.chart3, onTap: _openRapportVehicule),
      _ToolItem(title: 'Tâches', subtitle: 'Gérer les todos', icon: Icons.checklist, color: colors.chart3, onTap: _openTodos),
      _ToolItem(title: 'Carte UTA', subtitle: 'Trouver une station', icon: Icons.map, color: colors.info, onTap: _openUtaMap),
      if (_user?.isCouchette == true)
        _ToolItem(title: 'Couchettes', subtitle: 'Gérer les couchettes', icon: Icons.hotel, color: colors.info, onTap: _openCouchettes),
      _ToolItem(title: 'Paramètres', subtitle: 'Personnaliser', icon: Icons.settings, color: colors.mutedForeground, onTap: _openSettings),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.85,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) => _buildToolCard(tools[index], colors),
    );
  }

  Widget _buildToolCard(_ToolItem tool, AppColors colors) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: tool.onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: colors.accent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, size: 20, color: tool.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tool.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
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
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  String _getInitials(String firstName, String lastName) {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
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

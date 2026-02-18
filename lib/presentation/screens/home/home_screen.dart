import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/update_dialog.dart';
import '../absences/absences_screen.dart';
import '../acomptes/acomptes_screen.dart';
import '../auth/login_screen.dart';
import '../rapports/create_rapport_screen.dart';
import '../services/history_screen.dart';
import '../services/mes_heures_screen.dart';
import '../services/services_screen.dart';
import '../settings/settings_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../signatures/sign_screen.dart';
import '../signatures/signatures_screen.dart';
import '../uta/uta_map_screen.dart';
import '../vehicules/vehicules_list_screen.dart';

/// Page d'accueil après connexion
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  User? _user;
  bool _isLoading = true;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
    _checkSignatureRequired();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Vérifie les mises à jour et signatures quand l'app revient au premier plan
    if (state == AppLifecycleState.resumed) {
      _checkForUpdateOnResume();
      _checkSignatureRequired();
    }
  }

  Future<void> _checkForUpdateOnResume() async {
    // Évite les checks multiples simultanés
    if (_isCheckingUpdate) return;
    _isCheckingUpdate = true;

    try {
      // Le service gère automatiquement la logique des 24h
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

    if (_user != null) {
      setState(() => _isLoading = false);
    }

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
      },
    );
  }

  /// Vérifie quotidiennement si une signature est requise
  Future<void> _checkSignatureRequired() async {
    final result = await sl.signatureRepository.getLastSignatureSummary();

    if (!mounted) return;

    result.fold(
      (_) {}, // Ignore les erreurs
      (summary) {
        if (summary.needsToSign) {
          // Navigue vers l'écran de signature avec les heures du mois dernier
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SignScreen(
                    heuresLastMonth: summary.heuresLastMonth,
                  ),
                ),
              );
            }
          });
        }
      },
    );
  }

  Future<void> _logout() async {
    await sl.authRepository.logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openServices() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ServicesScreen()),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  void _openAbsences() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AbsencesScreen()),
    );
  }

  void _openMesHeures() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MesHeuresScreen()),
    );
  }

  void _openAcomptes() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AcomptesScreen()),
    );
  }

  void _openSignatures() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignaturesScreen()),
    );
  }

  void _openVehicules() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VehiculesListScreen()),
    );
  }

  void _openRapportVehicule() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateRapportScreen()),
    );
  }

  void _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    // Rafraîchir les données utilisateur au retour (si profil modifié)
    if (mounted) {
      _refreshUser();
    }
  }

  void _openUtaMap() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UtaMapScreen()),
    );
  }

  void _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    // Rafraîchir les données utilisateur au retour
    if (mounted) {
      _refreshUser();
    }
  }

  /// Rafraîchit les données utilisateur depuis le cache
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
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        title: const Text('AVTRANS'),
        backgroundColor: colors.bgSecondary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadUser,
              color: colors.primary,
              backgroundColor: colors.bgSecondary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(colors),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Outils',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
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
      color: colors.bgSecondary,
      borderRadius: BorderRadius.circular(AppRadius.base),
      child: InkWell(
        onTap: _openEditProfile,
        borderRadius: BorderRadius.circular(AppRadius.base),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.base),
            border: Border.all(color: colors.borderPrimary),
          ),
          child: Row(
            children: [
              // Photo de profil ou initiales
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: pictureUrl == null
                      ? LinearGradient(
                          colors: [colors.primary, colors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                clipBehavior: Clip.antiAlias,
                child: pictureUrl != null
                    ? Image.network(
                        pictureUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors.primary, colors.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _getInitials(firstName, lastName),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _getInitials(firstName, lastName),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$firstName $lastName',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (_user?.role != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _parseColor(_user!.role!.color, colors).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(
                          _user!.role!.nom,
                          style: TextStyle(
                            fontSize: 12,
                            color: _parseColor(_user!.role!.color, colors),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolsGrid(AppColors colors) {
    final tools = [
      _ToolItem(
        title: 'Services',
        subtitle: 'Gérer vos pointages',
        icon: Icons.access_time,
        color: colors.primary,
        onTap: _openServices,
      ),
      _ToolItem(
        title: 'Historique',
        subtitle: 'Voir vos services passés',
        icon: Icons.history,
        color: colors.secondary,
        onTap: _openHistory,
      ),
      _ToolItem(
        title: 'Mes heures',
        subtitle: 'Voir vos heures travaillées',
        icon: Icons.schedule,
        color: colors.success,
        onTap: _openMesHeures,
      ),
      _ToolItem(
        title: 'Absences',
        subtitle: 'Gérer vos demandes',
        icon: Icons.event_busy,
        color: colors.warning,
        onTap: _openAbsences,
      ),
      _ToolItem(
        title: 'Acomptes',
        subtitle: 'Demander des acomptes',
        icon: Icons.payments,
        color: colors.info,
        onTap: _openAcomptes,
      ),
      _ToolItem(
        title: 'Signatures',
        subtitle: 'Signer vos heures',
        icon: Icons.draw,
        color: colors.success,
        onTap: _openSignatures,
      ),
      _ToolItem(
        title: 'Véhicules',
        subtitle: 'Gérer les véhicules',
        icon: Icons.directions_car,
        color: const Color(0xFF9C27B0), // Violet
        onTap: _openVehicules,
      ),
      _ToolItem(
        title: 'Rapport véhicule',
        subtitle: 'Créer un rapport',
        icon: Icons.description,
        color: const Color(0xFFFF6F00), // Orange foncé
        onTap: _openRapportVehicule,
      ),
      _ToolItem(
        title: 'Carte UTA',
        subtitle: 'Trouver une station',
        icon: Icons.map,
        color: const Color(0xFF00796B), // Teal
        onTap: _openUtaMap,
      ),
      _ToolItem(
        title: 'Paramètres',
        subtitle: 'Personnaliser l\'app',
        icon: Icons.settings,
        color: colors.textSecondary,
        onTap: _openSettings,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        return _buildToolCard(tool, colors);
      },
    );
  }

  Widget _buildToolCard(_ToolItem tool, AppColors colors) {
    return Material(
      color: colors.bgSecondary,
      borderRadius: BorderRadius.circular(AppRadius.base),
      child: InkWell(
        onTap: tool.onTap,
        borderRadius: BorderRadius.circular(AppRadius.base),
        hoverColor: colors.bgHover,
        splashColor: colors.primary.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.base),
            border: Border.all(color: colors.borderPrimary),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Icon(
                  tool.icon,
                  size: 28,
                  color: tool.color,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                tool.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tool.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
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

  Color _parseColor(String colorString, AppColors colors) {
    try {
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
      return colors.primary;
    } catch (_) {
      return colors.primary;
    }
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

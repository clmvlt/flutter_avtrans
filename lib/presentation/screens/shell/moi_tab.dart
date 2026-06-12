import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/models.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_list.dart';
import '../absences/absences_screen.dart';
import '../acomptes/acomptes_screen.dart';
import '../auth/login_screen.dart';
import '../couchettes/couchettes_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../rapports/create_rapport_screen.dart';
import '../settings/notification_preferences_screen.dart';
import '../signatures/signatures_screen.dart';
import '../todos/todos_screen.dart';
import '../updates/updates_screen.dart';
import '../uta/uta_map_screen.dart';
import '../vehicules/vehicules_list_screen.dart';

/// Onglet « Moi » — profil, activité, terrain, réglages.
///
/// Absorbe l'ancienne grille « Tous les outils » + l'écran Paramètres,
/// rangés en sections type « Réglages iOS ».
class MoiTab extends StatefulWidget {
  const MoiTab({super.key});

  @override
  State<MoiTab> createState() => _MoiTabState();
}

class _MoiTabState extends State<MoiTab> {
  User? _user;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _user = sl.authRepository.getCachedUser();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = '${info.version} (${info.buildNumber})');
  }

  bool get _isAdminOrMecano {
    final role = _user?.role?.nom.toLowerCase() ?? '';
    return role == 'admin' || role == 'mecanicien';
  }

  void _push(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      if (mounted) setState(() => _user = sl.authRepository.getCachedUser());
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Veux-tu vraiment te déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.destructive),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await sl.authRepository.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.base,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: [
            Text('Moi', style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.base),
            _profileCard(colors, textTheme),
            const SizedBox(height: AppSpacing.lg),

            AppSection(
              title: 'Mon activité',
              children: [
                AppTile(
                  icon: Icons.event_busy_rounded,
                  label: 'Absences',
                  color: colors.domainAbsence,
                  isFirst: true,
                  onTap: () => _push(const AbsencesScreen()),
                ),
                AppTile(
                  icon: Icons.payments_rounded,
                  label: 'Acomptes',
                  color: colors.domainAcompte,
                  onTap: () => _push(const AcomptesScreen()),
                ),
                AppTile(
                  icon: Icons.draw_rounded,
                  label: 'Signatures',
                  color: colors.domainHours,
                  isLast: true,
                  onTap: () => _push(const SignaturesScreen()),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            AppSection(
              title: 'Véhicules & terrain',
              children: [
                AppTile(
                  icon: Icons.directions_car_rounded,
                  label: 'Véhicules',
                  color: colors.domainVehicule,
                  isFirst: true,
                  onTap: () => _push(const VehiculesListScreen()),
                ),
                AppTile(
                  icon: Icons.description_rounded,
                  label: 'Rapports véhicule',
                  color: colors.domainAbsence,
                  onTap: () => _push(const CreateRapportScreen()),
                ),
                AppTile(
                  icon: Icons.local_gas_station_rounded,
                  label: 'Carte UTA',
                  color: colors.domainYpsium,
                  isLast: !(_user?.isCouchette == true || _isAdminOrMecano),
                  onTap: () => _push(const UtaMapScreen()),
                ),
                if (_user?.isCouchette == true)
                  AppTile(
                    icon: Icons.hotel_rounded,
                    label: 'Couchettes',
                    color: colors.domainYpsium,
                    isLast: !_isAdminOrMecano,
                    onTap: () => _push(const CouchettesScreen()),
                  ),
                if (_isAdminOrMecano)
                  AppTile(
                    icon: Icons.checklist_rounded,
                    label: 'Tâches',
                    color: colors.domainAbsence,
                    isLast: true,
                    onTap: () => _push(const TodosScreen()),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            AppSection(
              title: 'Application',
              children: [
                AppTile(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  color: colors.domainPointage,
                  isFirst: true,
                  onTap: () => _push(const NotificationPreferencesScreen()),
                ),
                _themeTile(colors, textTheme),
                if (!Platform.isIOS)
                  AppTile(
                    icon: Icons.system_update_rounded,
                    label: 'Mises à jour',
                    color: colors.domainVehicule,
                    onTap: () => _push(const UpdatesScreen()),
                  ),
                AppTile(
                  icon: Icons.info_outline_rounded,
                  label: 'Version',
                  color: colors.mutedForeground,
                  badgeText: _version.isEmpty ? null : _version,
                  badgeColor: colors.mutedForeground,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              padding: EdgeInsets.zero,
              child: AppTile(
                icon: Icons.logout_rounded,
                label: 'Déconnexion',
                color: colors.destructive,
                isFirst: true,
                isLast: true,
                trailing: const SizedBox.shrink(),
                onTap: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(AppColors colors, TextTheme textTheme) {
    final name = _user?.fullName ?? 'Mon profil';
    final role = _user?.role?.nom;

    return AppCard(
      onTap: () => _push(const EditProfileScreen()),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: _user?.pictureUrl,
            fallbackText: name.isNotEmpty ? name[0].toUpperCase() : 'U',
            size: 56,
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: textTheme.titleLarge, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  role != null ? '$role · AVTRANS' : (_user?.email ?? ''),
                  style: textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.mutedForeground),
        ],
      ),
    );
  }

  Widget _themeTile(AppColors colors, TextTheme textTheme) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final dark = themeProvider.isDarkMode;
    return AppTile(
      icon: dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
      label: 'Mode sombre',
      color: colors.domainAcompte,
      onTap: themeProvider.toggleTheme,
      trailing: Switch(
        value: dark,
        onChanged: (_) => themeProvider.toggleTheme(),
      ),
    );
  }
}

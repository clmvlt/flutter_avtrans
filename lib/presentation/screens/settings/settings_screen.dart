import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_separator.dart';
import '../profile/edit_profile_screen.dart';
import '../updates/updates_screen.dart';
import 'notification_preferences_screen.dart';

/// Page des paramètres - design shadcn/ui
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          _buildSection(
            context,
            title: 'COMPTE',
            children: [_buildProfileTile(context)],
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildSection(
            context,
            title: 'NOTIFICATIONS',
            children: [
              _buildActionTile(
                context,
                title: 'Préférences de notification',
                subtitle: 'Gérer les types de notification',
                icon: Icons.notifications_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            const NotificationPreferencesScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildSection(
            context,
            title: 'APPARENCE',
            children: [_buildDarkModeToggle(context)],
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildSection(
            context,
            title: 'À PROPOS',
            children: [
              _buildInfoTile(
                context,
                title: 'Version',
                subtitle: _version.isEmpty
                    ? 'Chargement...'
                    : '$_version ($_buildNumber)',
                icon: Icons.info_outline,
              ),
              if (!Platform.isIOS) ...[
                AppSeparator(color: colors.border),
                _buildActionTile(
                  context,
                  title: 'Mises à jour',
                  subtitle: 'Vérifier les nouvelles versions',
                  icon: Icons.system_update,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UpdatesScreen()),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.mutedForeground,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildProfileTile(BuildContext context) {
    final colors = context.colors;
    final user = sl.authRepository.getCachedUser();

    return ListTile(
      leading: AppAvatar(
        imageUrl: user?.pictureUrl,
        fallbackText: (user?.fullName ?? 'U').substring(0, 1).toUpperCase(),
        size: 40,
      ),
      title: Text(
        user?.fullName ?? 'Mon profil',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colors.foreground,
        ),
      ),
      subtitle: Text(
        user?.email ?? 'Modifier mes informations',
        style: TextStyle(
          fontSize: 13,
          color: colors.mutedForeground,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: colors.mutedForeground, size: 18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
        );
      },
    );
  }

  Widget _buildDarkModeToggle(BuildContext context) {
    final colors = context.colors;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.muted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: colors.foreground,
          size: 18,
        ),
      ),
      title: Text(
        'Mode sombre',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colors.foreground,
        ),
      ),
      subtitle: Text(
        themeProvider.isDarkMode ? 'Activé' : 'Désactivé',
        style: TextStyle(
          fontSize: 13,
          color: colors.mutedForeground,
        ),
      ),
      trailing: Switch(
        value: themeProvider.isDarkMode,
        onChanged: (_) => themeProvider.toggleTheme(),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final colors = context.colors;

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.muted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: colors.foreground, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colors.foreground,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: colors.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.muted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: colors.foreground, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colors.foreground,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: colors.mutedForeground,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: colors.mutedForeground, size: 18),
      onTap: onTap,
    );
  }
}

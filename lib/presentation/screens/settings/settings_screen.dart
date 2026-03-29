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

/// Page des parametres — sections groupees, touch targets 48dp
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Parametres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          _buildSection(
            context,
            title: 'COMPTE',
            children: [_buildProfileTile(context, textTheme)],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSection(
            context,
            title: 'NOTIFICATIONS',
            children: [
              _buildActionTile(
                context,
                textTheme: textTheme,
                title: 'Preferences de notification',
                subtitle: 'Gerer les types de notification',
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
          const SizedBox(height: AppSpacing.lg),
          _buildSection(
            context,
            title: 'APPARENCE',
            children: [_buildDarkModeToggle(context, textTheme)],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSection(
            context,
            title: 'A PROPOS',
            children: [
              _buildInfoTile(
                context,
                textTheme: textTheme,
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
                  textTheme: textTheme,
                  title: 'Mises a jour',
                  subtitle: 'Verifier les nouvelles versions',
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
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
          child: Text(
            title,
            style: textTheme.labelSmall?.copyWith(
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

  Widget _buildProfileTile(BuildContext context, TextTheme textTheme) {
    final colors = context.colors;
    final user = sl.authRepository.getCachedUser();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      leading: AppAvatar(
        imageUrl: user?.pictureUrl,
        fallbackText: (user?.fullName ?? 'U').substring(0, 1).toUpperCase(),
        size: 44,
      ),
      title: Text(
        user?.fullName ?? 'Mon profil',
        style: textTheme.titleSmall,
      ),
      subtitle: Text(
        user?.email ?? 'Modifier mes informations',
        style: textTheme.bodySmall,
      ),
      trailing: Icon(Icons.chevron_right, color: colors.mutedForeground, size: 20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
        );
      },
    );
  }

  Widget _buildDarkModeToggle(BuildContext context, TextTheme textTheme) {
    final colors = context.colors;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.muted,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(
          themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: colors.foreground,
          size: 20,
        ),
      ),
      title: Text(
        'Mode sombre',
        style: textTheme.titleSmall,
      ),
      subtitle: Text(
        themeProvider.isDarkMode ? 'Active' : 'Desactive',
        style: textTheme.bodySmall,
      ),
      trailing: Switch(
        value: themeProvider.isDarkMode,
        onChanged: (_) => themeProvider.toggleTheme(),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required TextTheme textTheme,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final colors = context.colors;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.muted,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(icon, color: colors.foreground, size: 20),
      ),
      title: Text(title, style: textTheme.titleSmall),
      subtitle: Text(subtitle, style: textTheme.bodySmall),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required TextTheme textTheme,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.muted,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(icon, color: colors.foreground, size: 20),
      ),
      title: Text(title, style: textTheme.titleSmall),
      subtitle: Text(subtitle, style: textTheme.bodySmall),
      trailing: Icon(Icons.chevron_right, color: colors.mutedForeground, size: 20),
      onTap: onTap,
    );
  }
}

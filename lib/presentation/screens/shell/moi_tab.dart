import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import '../absences/absences_screen.dart';
import '../acomptes/acomptes_screen.dart';
import '../auth/login_screen.dart';
import '../couchettes/couchettes_screen.dart';
import '../entretiens/entretiens_screen.dart';
import '../entretiens/types_entretien_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../rapports/create_rapport_screen.dart';
import '../settings/notification_preferences_screen.dart';
import '../signatures/signatures_screen.dart';
import '../todos/todos_screen.dart';
import '../updates/updates_screen.dart';
import '../uta/uta_map_screen.dart';
import '../vehicules/vehicules_list_screen.dart';
import 'widgets/moi_profile_card.dart';

/// Onglet « Moi » : profil, activité, terrain, atelier, réglages, rangés en
/// groupes façon « Réglages iOS » ([AppSection] + [AppTile]).
///
/// Racine d'onglet : elle vit dans `MainShell`, au-dessus de la tab bar en
/// verre, dont `AppScrollView` réserve déjà la hauteur.
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

  /// Administrateur ou mécanicien, comparé par UUID de rôle (l'atelier est
  /// réservé à ces deux rôles, comme l'API).
  bool get _canManageFleet => _user?.canManageFleet ?? false;

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    setState(() => _user = sl.authRepository.getCachedUser());
  }

  Future<void> _logout() async {
    final confirm = await AppConfirmSheet.show(
      context,
      title: 'Te déconnecter ?',
      message: 'Tu devras te reconnecter pour utiliser l\'app.',
      confirmLabel: 'Me déconnecter',
      confirmIcon: Icons.logout_rounded,
      tone: AppConfirmTone.danger,
    );
    if (!confirm || !mounted) return;

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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final dark = themeProvider.isDarkMode;

    return AppPage(
      title: 'Moi',
      body: AppScrollView(
        children: [
          MoiProfileCard(
            user: _user,
            onTap: () => _push(const EditProfileScreen()),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSection(
            title: 'Mon activité',
            children: _tiles([
              _Tile(
                icon: Icons.event_busy_rounded,
                label: 'Absences',
                color: colors.domainAbsence,
                onTap: () => _push(const AbsencesScreen()),
              ),
              _Tile(
                icon: Icons.payments_rounded,
                label: 'Acomptes',
                color: colors.domainAcompte,
                onTap: () => _push(const AcomptesScreen()),
              ),
              _Tile(
                icon: Icons.draw_rounded,
                label: 'Signatures',
                color: colors.domainHours,
                onTap: () => _push(const SignaturesScreen()),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSection(
            title: 'Véhicules & terrain',
            children: _tiles([
              _Tile(
                icon: Icons.directions_car_rounded,
                label: 'Véhicules',
                color: colors.domainVehicule,
                onTap: () => _push(const VehiculesListScreen()),
              ),
              _Tile(
                icon: Icons.description_rounded,
                label: 'Rapports véhicule',
                color: colors.domainAbsence,
                onTap: () => _push(const CreateRapportScreen()),
              ),
              _Tile(
                icon: Icons.local_gas_station_rounded,
                label: 'Carte UTA',
                color: colors.domainYpsium,
                onTap: () => _push(const UtaMapScreen()),
              ),
              if (_user?.isCouchette == true)
                _Tile(
                  icon: Icons.hotel_rounded,
                  label: 'Couchettes',
                  color: colors.domainYpsium,
                  onTap: () => _push(const CouchettesScreen()),
                ),
            ]),
          ),
          if (_canManageFleet) ...[
            const SizedBox(height: AppSpacing.lg),
            AppSection(
              title: 'Atelier',
              children: _tiles([
                _Tile(
                  icon: Icons.build_rounded,
                  label: 'Entretiens',
                  color: colors.domainVehicule,
                  onTap: () => _push(const EntretiensScreen()),
                ),
                _Tile(
                  icon: Icons.category_rounded,
                  label: 'Types d\'entretien',
                  color: colors.info,
                  onTap: () => _push(const TypesEntretienScreen()),
                ),
                _Tile(
                  icon: Icons.checklist_rounded,
                  label: 'Tâches',
                  color: colors.domainAbsence,
                  onTap: () => _push(const TodosScreen()),
                ),
              ]),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppSection(
            title: 'Application',
            children: _tiles([
              _Tile(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                color: colors.domainPointage,
                onTap: () => _push(const NotificationPreferencesScreen()),
              ),
              _Tile(
                icon: dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                label: 'Mode sombre',
                color: colors.domainAcompte,
                onTap: themeProvider.toggleTheme,
                trailing: Switch(
                  value: dark,
                  onChanged: (_) => themeProvider.toggleTheme(),
                ),
              ),
              if (!Platform.isIOS)
                _Tile(
                  icon: Icons.system_update_rounded,
                  label: 'Mises à jour',
                  color: colors.domainVehicule,
                  onTap: () => _push(const UpdatesScreen()),
                ),
              _Tile(
                icon: Icons.info_outline_rounded,
                label: 'Version',
                color: colors.mutedForeground,
                badgeText: _version.isEmpty ? null : _version,
                badgeColor: colors.mutedForeground,
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSection(
            children: [
              AppTile(
                icon: Icons.logout_rounded,
                label: 'Se déconnecter',
                color: colors.destructive,
                isFirst: true,
                isLast: true,
                trailing: const SizedBox.shrink(),
                onTap: _logout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tuiles d'un groupe, avec les coins arrondis en tête et en fin.
  List<Widget> _tiles(List<_Tile> tiles) => [
        for (var i = 0; i < tiles.length; i++)
          AppTile(
            icon: tiles[i].icon,
            label: tiles[i].label,
            color: tiles[i].color,
            onTap: tiles[i].onTap,
            badgeText: tiles[i].badgeText,
            badgeColor: tiles[i].badgeColor,
            trailing: tiles[i].trailing,
            isFirst: i == 0,
            isLast: i == tiles.length - 1,
          ),
      ];
}

/// Description d'une tuile d'un groupe (voir `_tiles`).
class _Tile {
  const _Tile({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.badgeText,
    this.badgeColor,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String? badgeText;
  final Color? badgeColor;
  final Widget? trailing;
}

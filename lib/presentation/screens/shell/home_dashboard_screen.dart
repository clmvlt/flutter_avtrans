import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import '../absences/absences_screen.dart';
import '../acomptes/acomptes_screen.dart';
import '../circuit/circuit_screen.dart';
import '../entretiens/entretiens_screen.dart';
import '../entretiens/widgets/atelier_home_card.dart';
import '../notifications/notifications_screen.dart';
import '../services/mes_heures_screen.dart';
import '../services/widgets/hours_strip.dart';
import '../signatures/sign_screen.dart';
import '../vehicules/vehicules_list_screen.dart';
import 'widgets/circuit_card.dart';
import 'widgets/home_pointage_card.dart';
import 'widgets/home_skeleton.dart';
import 'widgets/notification_bell_button.dart';
import 'widgets/profile_avatar_button.dart';
import 'widgets/quick_access_card.dart';
import 'widgets/signature_callout.dart';

/// Onglet « Accueil » : l'état du pointage en point focal, ce qui est à
/// faire, les repères d'heures, puis les accès rapides.
///
/// Racine d'onglet : elle vit dans `MainShell`, au-dessus de la tab bar en
/// verre, dont `AppScrollView` réserve déjà la hauteur.
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    required this.onOpenPointage,
    required this.onOpenMoi,
  });

  /// Bascule vers l'onglet Pointage.
  final VoidCallback onOpenPointage;

  /// Bascule vers l'onglet Moi.
  final VoidCallback onOpenMoi;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  User? _user;
  Service? _activeService;
  WorkedHours? _hours;
  int _unread = 0;

  // Signature requise
  bool _needsSignature = false;
  double? _heuresLastMonth;

  /// Premier chargement en cours : squelette du haut de page.
  bool _loading = true;

  /// Statut de pointage introuvable : carte d'erreur à la place du hero.
  String? _statusError;

  // Atelier (Administrateur, Mécanicien) : échéances de la flotte.
  FleetSummary? _fleet;
  bool _fleetLoading = false;
  bool _fleetError = false;

  bool get _showAtelier => _user?.canManageFleet ?? false;

  @override
  void initState() {
    super.initState();
    _user = sl.authRepository.getCachedUser();
    _load();
  }

  Future<void> _load() async {
    if (_showAtelier) unawaited(_loadFleet());
    final (userRes, activeRes, hoursRes, unreadRes, signatureRes) = await (
      sl.authRepository.getCurrentUser(),
      sl.serviceRepository.getActiveService(),
      sl.serviceRepository.getWorkedHours(const WorkedHoursParams()),
      sl.notificationRepository.getUnreadCount(),
      sl.signatureRepository.getLastSignatureSummary(),
    ).wait;
    if (!mounted) return;

    setState(() {
      _loading = false;
      userRes.fold((_) {}, (u) {
        _user = u;
      });
      activeRes.fold(
        (failure) {
          _statusError = failure.message;
        },
        (s) {
          _activeService = s;
          _statusError = null;
        },
      );
      // Échec : « 0h » comme avant, plutôt qu'un squelette sans fin.
      hoursRes.fold((_) {
        _hours ??= const WorkedHours();
      }, (h) {
        _hours = h;
      });
      unreadRes.fold((_) {}, (c) {
        _unread = c;
      });
      signatureRes.fold((_) {}, (summary) {
        _needsSignature = summary.needsToSign;
        _heuresLastMonth = summary.heuresLastMonth;
      });
    });
  }

  Future<void> _loadFleet() async {
    setState(() => _fleetLoading = true);
    final result = await FleetSummary.load();
    if (!mounted) return;
    setState(() {
      _fleetLoading = false;
      result.fold((_) => _fleetError = true, (s) {
        _fleet = s;
        _fleetError = false;
      });
    });
  }

  // ---- navigation ------------------------------------------------------

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    await _load();
  }

  // Comme depuis la page Pointage : sans total connu, l'écran le demande.
  void _openSign() => _push(SignScreen(heuresLastMonth: _heuresLastMonth));

  String get _greeting {
    final h = DateTime.now().hour;
    final hello = h < 12
        ? 'Bonjour'
        : h < 18
            ? 'Bon après-midi'
            : 'Bonsoir';
    final name = _user?.firstName.trim() ?? '';
    return name.isEmpty ? hello : '$hello, $name';
  }

  // ---- build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return AppPage(
      title: 'Accueil',
      actions: [
        NotificationBellButton(
          count: _unread,
          onPressed: () => _push(const NotificationsScreen()),
        ),
        ProfileAvatarButton(user: _user, onPressed: widget.onOpenMoi),
      ],
      body: AppScrollView(
        onRefresh: _load,
        topPadding: AppSpacing.xs,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              _greeting,
              style:
                  textTheme.bodyLarge?.copyWith(color: colors.mutedForeground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading) const HomeSkeleton() else ..._buildFocus(),
          // ---- Cartes métier -------------------------------------------
          // Cartes propres à un rôle, juste après le point focal, chacune
          // précédée de `const SizedBox(height: AppSpacing.md)`.
          if (_showAtelier) ...[
            const SizedBox(height: AppSpacing.md),
            AtelierHomeCard(
              summary: _fleet,
              loading: _fleetLoading,
              error: _fleetError,
              onTap: () => _push(const EntretiensScreen()),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ..._buildShortcuts(),
        ],
      ),
    );
  }

  /// Point focal : état du pointage, signature à faire, repères d'heures.
  List<Widget> _buildFocus() {
    final error = _statusError;
    return [
      if (error != null)
        AppErrorState(
          title: 'Statut du pointage indisponible',
          message: error,
          onRetry: _load,
        )
      else
        HomePointageCard(
          activeService: _activeService,
          hoursToday: _hours?.day,
          onTap: widget.onOpenPointage,
        ),
      if (_needsSignature) ...[
        const SizedBox(height: AppSpacing.md),
        SignatureCallout(heuresLastMonth: _heuresLastMonth, onTap: _openSign),
      ],
      const SizedBox(height: AppSpacing.md),
      HoursStrip(
        hours: _hours,
        onTap: () => _push(const MesHeuresScreen()),
      ),
    ];
  }

  /// Accès rapides et carte Circuit.
  List<Widget> _buildShortcuts() {
    return [
      const AppSectionHeader(title: 'Accès rapide'),
      QuickAccessCard(
        onHours: () => _push(const MesHeuresScreen()),
        onAbsences: () => _push(const AbsencesScreen()),
        onAcomptes: () => _push(const AcomptesScreen()),
        onVehicules: () => _push(const VehiculesListScreen()),
      ),
      const SizedBox(height: AppSpacing.md),
      CircuitCard(onTap: () => _push(const CircuitScreen())),
    ];
  }
}

import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_card.dart';
import '../absences/absences_screen.dart';
import '../acomptes/acomptes_screen.dart';
import '../circuit/circuit_screen.dart';
import '../notifications/notifications_screen.dart';
import '../services/mes_heures_screen.dart';
import '../signatures/sign_screen.dart';

/// Onglet « Accueil » — tableau de bord chaleureux.
///
/// Met en scène l'action reine (le pointage) au lieu d'une grille d'outils.
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

  @override
  void initState() {
    super.initState();
    _user = sl.authRepository.getCachedUser();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      sl.authRepository.getCurrentUser(),
      sl.serviceRepository.getActiveService(),
      sl.serviceRepository.getWorkedHours(const WorkedHoursParams()),
      sl.notificationRepository.getUnreadCount(),
      sl.signatureRepository.getLastSignatureSummary(),
    ]);
    if (!mounted) return;

    setState(() {
      (results[0] as dynamic).fold((_) {}, (u) => _user = u as User);
      (results[1] as dynamic).fold((_) {}, (s) => _activeService = s as Service?);
      (results[2] as dynamic).fold((_) {}, (h) => _hours = h as WorkedHours);
      (results[3] as dynamic).fold((_) {}, (c) => _unread = c as int);
      (results[4] as dynamic).fold((_) {}, (sum) {
        _needsSignature = (sum as dynamic).needsToSign as bool;
        _heuresLastMonth = (sum).heuresLastMonth as double?;
      });
    });
  }

  // ---- helpers ---------------------------------------------------------

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  String _initials() {
    final f = (_user?.firstName ?? '').trim();
    final l = (_user?.lastName ?? '').trim();
    final a = f.isNotEmpty ? f[0] : '';
    final b = l.isNotEmpty ? l[0] : '';
    final s = '$a$b'.toUpperCase();
    return s.isEmpty ? 'U' : s;
  }

  /// Convertit un nombre d'heures décimal en « Xh YY » / « X min ».
  String _fmtHours(double? hours) {
    if (hours == null || hours <= 0) return '0h';
    final totalMin = (hours * 60).round();
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '${h}h';
    return '${h}h ${m.toString().padLeft(2, '0')}';
  }

  _PointageVisual _visual(AppColors c) {
    if (_activeService == null) {
      return _PointageVisual('Hors service', Icons.bedtime_outlined,
          c.mutedForeground, c.surfaceSunken);
    }
    if (_activeService!.isBreak) {
      return _PointageVisual(
          'En pause', Icons.pause_circle_outline, c.warning, c.warningMuted);
    }
    return _PointageVisual(
        'En service', Icons.bolt_rounded, c.primary, c.primarySoft);
  }

  // ---- build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: colors.primary,
          backgroundColor: colors.card,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.sm,
              AppSpacing.screen,
              AppSpacing.lg,
            ),
            children: [
              _header(colors, textTheme),
              const SizedBox(height: AppSpacing.lg),
              _pointageHero(colors, textTheme),
              const SizedBox(height: AppSpacing.md),
              _weekStats(colors, textTheme),
              if (_needsSignature) ...[
                const SizedBox(height: AppSpacing.md),
                _signatureBanner(colors, textTheme),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Accès rapide', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _quickAccess(colors, textTheme),
              const SizedBox(height: AppSpacing.md),
              _circuitCard(colors, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppColors colors, TextTheme textTheme) {
    return Row(
      children: [
        GestureDetector(
          onTap: widget.onOpenMoi,
          child: AppAvatar(
            imageUrl: _user?.pictureUrl,
            fallbackText: _initials(),
            size: 46,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: textTheme.bodySmall),
              Text(
                _user?.firstName.isNotEmpty == true
                    ? _user!.firstName
                    : 'Bienvenue',
                style: textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _NotifBell(count: _unread, onTap: _openNotifications),
      ],
    );
  }

  Widget _pointageHero(AppColors colors, TextTheme textTheme) {
    final v = _visual(colors);
    final today = _fmtHours(_hours?.day);

    return AppCard(
      elevation: AppCardElevation.hero,
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: widget.onOpenPointage,
      color: v.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: v.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(v.icon, color: v.accent, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pointage', style: textTheme.bodySmall),
                    Text(v.label,
                        style: textTheme.titleLarge?.copyWith(color: v.accent)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.mutedForeground),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text("Aujourd'hui", style: textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(today, style: textTheme.displaySmall),
        ],
      ),
    );
  }

  Widget _weekStats(AppColors colors, TextTheme textTheme) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_view_week_rounded,
            accent: colors.domainHours,
            label: 'Cette semaine',
            value: _fmtHours(_hours?.week),
            onTap: () => _push(const MesHeuresScreen()),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_month_rounded,
            accent: colors.domainPointage,
            label: 'Ce mois',
            value: _fmtHours(_hours?.month),
            onTap: () => _push(const MesHeuresScreen()),
          ),
        ),
      ],
    );
  }

  Widget _signatureBanner(AppColors colors, TextTheme textTheme) {
    return AppCard(
      color: colors.warningMuted,
      elevation: AppCardElevation.flat,
      onTap: () => _push(SignScreen(heuresLastMonth: _heuresLastMonth ?? 0)),
      child: Row(
        children: [
          Icon(Icons.draw_rounded, color: colors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Signature requise',
                    style: textTheme.titleSmall
                        ?.copyWith(color: colors.warningForeground)),
                Text('Tu dois signer tes heures du mois dernier',
                    style: textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.warning),
        ],
      ),
    );
  }

  Widget _circuitCard(AppColors colors, TextTheme textTheme) {
    return AppCard(
      elevation: AppCardElevation.raised,
      padding: const EdgeInsets.all(AppSpacing.base),
      onTap: () => _push(const CircuitScreen()),
      color: colors.primarySoft,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.route_rounded, color: colors.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Circuit', style: textTheme.titleMedium),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'Nouveauté',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.primaryForeground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Optimisez vos tournées', style: textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.mutedForeground),
        ],
      ),
    );
  }

  Widget _quickAccess(AppColors colors, TextTheme textTheme) {
    final items = [
      _Quick('Mes heures', Icons.schedule_rounded, colors.domainHours,
          () => _push(const MesHeuresScreen())),
      _Quick('Absences', Icons.event_busy_rounded, colors.domainAbsence,
          () => _push(const AbsencesScreen())),
      _Quick('Acomptes', Icons.payments_rounded, colors.domainAcompte,
          () => _push(const AcomptesScreen())),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: _QuickPill(item: items[i])),
        ],
      ],
    );
  }

  // ---- navigation ------------------------------------------------------

  void _push(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      if (mounted) _load();
    });
  }

  void _openNotifications() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))
        .then((_) {
      if (mounted) _load();
    });
  }
}

// ---- petits widgets internes ------------------------------------------

class _PointageVisual {
  final String label;
  final IconData icon;
  final Color accent;
  final Color soft;
  _PointageVisual(this.label, this.icon, this.accent, this.soft);
}

class _Quick {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _Quick(this.label, this.icon, this.color, this.onTap);
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: textTheme.headlineSmall),
          const SizedBox(height: 1),
          Text(label, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _QuickPill extends StatelessWidget {
  const _QuickPill({required this.item});
  final _Quick item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: item.onTap,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.base, horizontal: AppSpacing.sm),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.label,
            style: textTheme.labelMedium,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _NotifBell extends StatelessWidget {
  const _NotifBell({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: colors.card,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: colors.cardShadow,
              ),
              child: Icon(Icons.notifications_none_rounded,
                  color: colors.foreground, size: 24),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              decoration: BoxDecoration(
                color: colors.destructive,
                shape: BoxShape.circle,
                border: Border.all(color: colors.background, width: 2),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.destructiveForeground,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

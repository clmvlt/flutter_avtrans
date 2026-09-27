import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../widgets/widgets.dart';
import '../notifications/widgets/notification_visual.dart';
import 'widgets/preference_choice_sheet.dart';

/// Préférences de notification : un groupe de lignes (une par type
/// d'événement, avec le mode actuel en sous-ligne), le choix du mode dans
/// une feuille, puis « Enregistrer les préférences » dans le dock.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> with DockNoticeMixin {
  NotificationPreferences? _preferences;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final result =
        await sl.notificationRepository.getNotificationPreferences();

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (prefs) {
        setState(() {
          _preferences = prefs;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _savePreferences() async {
    if (_preferences == null || _isSaving) return;

    clearDockNotice();
    setState(() => _isSaving = true);

    final result = await sl.notificationRepository
        .updateNotificationPreferences(_preferences!);

    if (!mounted) return;

    setState(() => _isSaving = false);

    result.fold(
      (failure) => showDockError(failure.message),
      (prefs) {
        setState(() => _preferences = prefs);
        showDockSuccess('Préférences enregistrées');
      },
    );
  }

  void _updatePreference(String key, NotificationPreference value) {
    if (_preferences == null) return;
    setState(() {
      switch (key) {
        case 'acompte':
          _preferences = _preferences!.copyWith(acompte: value);
          break;
        case 'absence':
          _preferences = _preferences!.copyWith(absence: value);
          break;
        case 'userCreated':
          _preferences = _preferences!.copyWith(userCreated: value);
          break;
        case 'rapportVehicule':
          _preferences = _preferences!.copyWith(rapportVehicule: value);
          break;
        case 'todo':
          _preferences = _preferences!.copyWith(todo: value);
          break;
      }
    });
  }

  Future<void> _choose(_Category category, NotificationPreference current) async {
    final picked = await PreferenceChoiceSheet.show(
      context,
      title: category.title,
      description: category.description,
      current: current,
    );
    if (picked == null || !mounted) return;
    _updatePreference(category.key, picked);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Notifications',
      body: _buildBody(),
      dock: AppDock(
        actions: [
          if (_preferences != null && !_isLoading)
            DockAction(
              label: 'Enregistrer les préférences',
              icon: Icons.check_rounded,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _savePreferences,
            ),
        ],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppScrollView(
        children: [
          AppSkeleton(height: 16),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton(width: 220, height: 16),
          SizedBox(height: AppSpacing.lg),
          AppListSkeleton(rows: 5),
        ],
      );
    }

    final error = _error;
    if (error != null) {
      return AppScrollView(
        children: [
          AppErrorState(message: error, onRetry: _loadPreferences),
        ],
      );
    }

    final prefs = _preferences;
    if (prefs == null) {
      return AppScrollView(
        children: [
          AppEmptyCard(
            icon: Icons.notifications_off_outlined,
            message: 'Aucune préférence à afficher',
            actionLabel: 'Réessayer',
            onAction: _loadPreferences,
          ),
        ],
      );
    }

    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final categories = <(_Category, NotificationPreference)>[
      (_Category.acompte, prefs.acompte),
      (_Category.absence, prefs.absence),
      (_Category.rapportVehicule, prefs.rapportVehicule),
      (_Category.todo, prefs.todo),
      (_Category.userCreated, prefs.userCreated),
    ];

    return AppScrollView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            'Choisis comment recevoir tes notifications pour chaque type '
            'd\'événement.',
            style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSection(
          children: [
            for (var i = 0; i < categories.length; i++)
              _tile(
                categories[i].$1,
                categories[i].$2,
                colors,
                isFirst: i == 0,
                isLast: i == categories.length - 1,
              ),
          ],
        ),
      ],
    );
  }

  Widget _tile(
    _Category category,
    NotificationPreference value,
    AppColors colors, {
    required bool isFirst,
    required bool isLast,
  }) {
    final (icon, accent) = notificationVisual(category.key, colors);
    return AppTile(
      icon: icon,
      label: category.title,
      subtitle: value.label,
      color: accent,
      isFirst: isFirst,
      isLast: isLast,
      onTap: () => _choose(category, value),
    );
  }
}

/// Type d'événement réglable : clé de l'API, libellé, explication.
enum _Category {
  acompte(
    'acompte',
    'Acomptes',
    'Mises à jour de tes demandes d\'acompte.',
  ),
  absence(
    'absence',
    'Absences',
    'Mises à jour de tes demandes d\'absence.',
  ),
  rapportVehicule(
    'rapportVehicule',
    'Rapports véhicule',
    'Nouveaux rapports de véhicule.',
  ),
  todo('todo', 'Tâches', 'Mises à jour de tes tâches.'),
  userCreated(
    'userCreated',
    'Création de compte',
    'Quand un nouvel utilisateur est créé.',
  );

  const _Category(this.key, this.title, this.description);

  final String key;
  final String title;
  final String description;
}

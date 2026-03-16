import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../widgets/widgets.dart';

/// Page de gestion des préférences de notification
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
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
    setState(() {
      _isLoading = true;
      _error = null;
    });

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

    setState(() => _isSaving = true);

    final result = await sl.notificationRepository
        .updateNotificationPreferences(_preferences!);

    if (!mounted) return;

    setState(() => _isSaving = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (prefs) {
        setState(() => _preferences = prefs);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Préférences mises à jour')),
        );
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_preferences != null)
            TextButton(
              onPressed: _isSaving ? null : _savePreferences,
              child: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : Text(
                      'Sauvegarder',
                      style: TextStyle(color: colors.primary),
                    ),
            ),
        ],
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Chargement...');
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.destructive),
            const SizedBox(height: AppSpacing.base),
            Text(_error!,
                style: TextStyle(color: colors.mutedForeground),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              text: 'Réessayer',
              onPressed: _loadPreferences,
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryForeground,
            ),
          ],
        ),
      );
    }

    if (_preferences == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: [
        Text(
          'Choisissez comment recevoir vos notifications pour chaque type d\'événement.',
          style: TextStyle(fontSize: 13, color: colors.mutedForeground),
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildPreferenceCard(
          colors,
          title: 'Acomptes',
          subtitle: 'Mises à jour de vos demandes d\'acompte',
          icon: Icons.payments,
          iconColor: colors.info,
          currentValue: _preferences!.acompte,
          onChanged: (v) => _updatePreference('acompte', v),
        ),
        _buildPreferenceCard(
          colors,
          title: 'Absences',
          subtitle: 'Mises à jour de vos demandes d\'absence',
          icon: Icons.event_busy,
          iconColor: colors.warning,
          currentValue: _preferences!.absence,
          onChanged: (v) => _updatePreference('absence', v),
        ),
        _buildPreferenceCard(
          colors,
          title: 'Rapports véhicule',
          subtitle: 'Nouveaux rapports de véhicule',
          icon: Icons.description,
          iconColor: colors.chart3,
          currentValue: _preferences!.rapportVehicule,
          onChanged: (v) => _updatePreference('rapportVehicule', v),
        ),
        _buildPreferenceCard(
          colors,
          title: 'Tâches',
          subtitle: 'Mises à jour de vos tâches',
          icon: Icons.checklist,
          iconColor: colors.success,
          currentValue: _preferences!.todo,
          onChanged: (v) => _updatePreference('todo', v),
        ),
        _buildPreferenceCard(
          colors,
          title: 'Création de compte',
          subtitle: 'Quand un nouvel utilisateur est créé',
          icon: Icons.person_add,
          iconColor: colors.primary,
          currentValue: _preferences!.userCreated,
          onChanged: (v) => _updatePreference('userCreated', v),
        ),
      ],
    );
  }

  Widget _buildPreferenceCard(
    AppColors colors, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required NotificationPreference currentValue,
    required ValueChanged<NotificationPreference> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.foreground,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: NotificationPreference.values
                  .map((pref) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _buildOptionChip(
                            colors,
                            label: pref.label,
                            isSelected: currentValue == pref,
                            onTap: () => onChanged(pref),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionChip(
    AppColors colors, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.muted,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? colors.primaryForeground : colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

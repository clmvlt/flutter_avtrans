import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';

/// Dialog demandant à l'utilisateur de compléter son profil
/// (adresse et numéro de permis de conduire)
class CompleteProfileDialog extends StatelessWidget {
  final User user;
  final VoidCallback onComplete;
  final VoidCallback onLater;

  const CompleteProfileDialog({
    super.key,
    required this.user,
    required this.onComplete,
    required this.onLater,
  });

  /// Vérifie si le profil est incomplet (adresse ou permis manquant)
  static bool isProfileIncomplete(User? user) {
    if (user == null) return false;

    final hasAddress = user.address != null &&
        user.address!.street != null &&
        user.address!.street!.isNotEmpty &&
        user.address!.city != null &&
        user.address!.city!.isNotEmpty;

    final hasDriverLicense = user.driverLicenseNumber != null &&
        user.driverLicenseNumber!.isNotEmpty;

    return !hasAddress || !hasDriverLicense;
  }

  /// Retourne la liste des informations manquantes
  static List<String> getMissingInfo(User user) {
    final missing = <String>[];

    final hasAddress = user.address != null &&
        user.address!.street != null &&
        user.address!.street!.isNotEmpty &&
        user.address!.city != null &&
        user.address!.city!.isNotEmpty;

    final hasDriverLicense = user.driverLicenseNumber != null &&
        user.driverLicenseNumber!.isNotEmpty;

    if (!hasAddress) missing.add('Votre adresse');
    if (!hasDriverLicense) missing.add('Votre numéro de permis de conduire');

    return missing;
  }

  /// Affiche le dialog si le profil est incomplet
  static Future<void> showIfNeeded(
    BuildContext context, {
    required User user,
    required VoidCallback onComplete,
  }) async {
    if (!isProfileIncomplete(user)) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CompleteProfileDialog(
        user: user,
        onComplete: () {
          Navigator.of(context).pop();
          onComplete();
        },
        onLater: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final missingInfo = getMissingInfo(user);

    return AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              size: 40,
              color: colors.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Complétez votre profil',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pour une meilleure expérience, veuillez renseigner les informations suivantes :',
            style: TextStyle(
              fontSize: 13,
              color: colors.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.base),
          ...missingInfo.map((info) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.arrow_right, size: 20, color: colors.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        info,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onLater,
          child: Text(
            'Plus tard',
            style: TextStyle(color: colors.mutedForeground),
          ),
        ),
        FilledButton(
          onPressed: onComplete,
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.primaryForeground,
          ),
          child: const Text('Renseigner'),
        ),
      ],
    );
  }
}

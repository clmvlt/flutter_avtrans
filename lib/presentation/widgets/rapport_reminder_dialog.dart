import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Dialog shadcn/ui pour rappel de rapport véhicule
class RapportReminderDialog extends StatelessWidget {
  final VoidCallback onCreateRapport;
  final bool isRequired;

  const RapportReminderDialog({
    super.key,
    required this.onCreateRapport,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accentColor = isRequired ? colors.destructive : colors.warning;

    return AlertDialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colors.border),
      ),
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isRequired ? Icons.error_rounded : Icons.warning_amber_rounded,
          size: 32,
          color: accentColor,
        ),
      ),
      title: Text(
        isRequired ? 'Rapport obligatoire' : 'Rapport de véhicule',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: colors.foreground,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isRequired
                ? 'Votre dernier rapport date de plus d\'une semaine.'
                : 'Vous n\'avez pas encore fait de rapport cette semaine.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isRequired
                ? 'Vous devez créer un rapport de l\'état du véhicule pour pouvoir pointer.'
                : 'Pensez à créer un rapport de l\'état du véhicule.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
      actions: [
        if (!isRequired)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Plus tard',
              style: TextStyle(color: colors.mutedForeground),
            ),
          ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(true);
            onCreateRapport();
          },
          icon: const Icon(Icons.description, size: 16),
          label: const Text('Créer un rapport'),
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.primaryForeground,
          ),
        ),
      ],
    );
  }

  static Future<bool> show(
    BuildContext context, {
    required VoidCallback onCreateRapport,
    bool isRequired = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isRequired,
      builder: (context) => RapportReminderDialog(
        onCreateRapport: onCreateRapport,
        isRequired: isRequired,
      ),
    );
    return result ?? false;
  }
}

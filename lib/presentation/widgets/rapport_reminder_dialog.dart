import 'package:flutter/material.dart';

/// Dialogue pour rappeler à l'utilisateur de faire un rapport de véhicule
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
    return AlertDialog(
      icon: Icon(
        isRequired ? Icons.error_rounded : Icons.warning_amber_rounded,
        size: 64,
        color: isRequired ? Colors.red : Colors.orange,
      ),
      title: Text(
        isRequired ? 'Rapport obligatoire' : 'Rapport de véhicule',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 22,
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
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            isRequired
                ? 'Vous devez créer un rapport de l\'état du véhicule pour pouvoir pointer.'
                : 'Pensez à créer un rapport de l\'état du véhicule.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isRequired ? Colors.red.shade700 : Colors.grey,
              fontWeight: isRequired ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
      actions: [
        if (!isRequired)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Plus tard'),
          ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(true);
            onCreateRapport();
          },
          icon: const Icon(Icons.description),
          label: const Text('Créer un rapport'),
        ),
      ],
    );
  }

  /// Affiche le dialogue et retourne true si l'utilisateur veut créer un rapport
  /// [isRequired] : si true, le bouton "Plus tard" est masqué (rapport obligatoire)
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

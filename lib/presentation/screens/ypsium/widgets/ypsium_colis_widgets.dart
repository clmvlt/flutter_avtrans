import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/widgets.dart';
import 'ypsium_order_visual.dart';

/// Colis saisi pendant le chargement (liste locale, avant envoi à l'API).
class YpsiumColisEntry {
  const YpsiumColisEntry({
    this.codeBarre = '',
    required this.refArticle,
    required this.designation,
    this.quantite = 1,
  });

  final String codeBarre;
  final String refArticle;
  final String designation;
  final int quantite;
}

/// Feuille « Ajouter un colis » : code-barres, référence, quantité,
/// désignation. Retourne le colis saisi, `null` si fermée.
abstract final class YpsiumAddColisSheet {
  static Future<YpsiumColisEntry?> show(BuildContext context) {
    return AppSheet.show<YpsiumColisEntry>(
      context,
      title: 'Ajouter un colis',
      builder: (_) => const _AddColisForm(),
    );
  }
}

class _AddColisForm extends StatefulWidget {
  const _AddColisForm();

  @override
  State<_AddColisForm> createState() => _AddColisFormState();
}

class _AddColisFormState extends State<_AddColisForm> {
  final _refController = TextEditingController(text: 'COLIS');
  final _desController = TextEditingController(text: 'COLIS');
  final _qtyController = TextEditingController(text: '1');
  final _cbController = TextEditingController();

  @override
  void dispose() {
    _refController.dispose();
    _desController.dispose();
    _qtyController.dispose();
    _cbController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      YpsiumColisEntry(
        codeBarre: _cbController.text,
        refArticle: _refController.text,
        designation: _desController.text,
        quantite: int.tryParse(_qtyController.text) ?? 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _cbController,
          label: 'Code-barres',
          hint: 'Scanner ou saisir (facultatif)',
          prefixIcon: const Icon(Icons.qr_code_rounded, size: 20),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _refController,
                label: 'Référence',
                hint: 'COLIS',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                controller: _qtyController,
                label: 'Quantité',
                hint: '1',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _desController,
          label: 'Désignation',
          hint: 'Description du colis',
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          text: 'Ajouter le colis',
          icon: Icons.add_rounded,
          size: ButtonSize.lg,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 52,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: colors.foreground),
            child: const Text('Annuler'),
          ),
        ),
      ],
    );
  }
}

/// Liste des colis chargés : numéro, désignation (référence), quantité.
class YpsiumColisList extends StatelessWidget {
  const YpsiumColisList({super.key, required this.colis});

  final List<YpsiumColisEntry> colis;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return YpsiumRowGroup(
      children: [
        for (var i = 0; i < colis.length; i++)
          AppListRow(
            leading: _NumberBox(number: i + 1),
            title: '${colis[i].designation} (${colis[i].refArticle})',
            subtitle: 'Quantité : ${colis[i].quantite}',
            trailing: Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: colors.success,
            ),
            showChevron: false,
          ),
      ],
    );
  }
}

class _NumberBox extends StatelessWidget {
  const _NumberBox({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: AppLayout.iconBox,
      height: AppLayout.iconBox,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.success.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        '$number',
        style: textTheme.labelLarge?.copyWith(
          color: colors.success,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

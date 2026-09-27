import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';
import '../../absences/widgets/request_widgets.dart';

/// Filtres de la liste des acomptes (statut, période, montant).
@immutable
class AcompteFilters {
  const AcompteFilters({
    this.startDate,
    this.endDate,
    this.status,
    this.montantMin,
    this.montantMax,
  });

  static const none = AcompteFilters();

  final DateTime? startDate;
  final DateTime? endDate;
  final AcompteStatus? status;
  final double? montantMin;
  final double? montantMax;

  bool get isActive =>
      startDate != null ||
      endDate != null ||
      status != null ||
      montantMin != null ||
      montantMax != null;

  /// Groupes actifs : statut, période, montant.
  int get count =>
      (status != null ? 1 : 0) +
      (startDate != null || endDate != null ? 1 : 0) +
      (montantMin != null || montantMax != null ? 1 : 0);

  /// Libellés des groupes actifs, dans l'ordre statut, période, montant.
  List<({String label, IconData icon})> get labels {
    final d = DateFormat('dd/MM', 'fr_FR');
    String euros(double v) => DisplayFormat.euros(v);

    String? period;
    if (startDate != null && endDate != null) {
      period = '${d.format(startDate!)} – ${d.format(endDate!)}';
    } else if (startDate != null) {
      period = 'Depuis ${d.format(startDate!)}';
    } else if (endDate != null) {
      period = 'Jusqu\'au ${d.format(endDate!)}';
    }

    String? amount;
    if (montantMin != null && montantMax != null) {
      amount = '${euros(montantMin!)} – ${euros(montantMax!)}';
    } else if (montantMin != null) {
      amount = 'Dès ${euros(montantMin!)}';
    } else if (montantMax != null) {
      amount = 'Jusqu\'à ${euros(montantMax!)}';
    }

    return [
      if (status != null) (label: status!.label, icon: Icons.flag_rounded),
      if (period != null) (label: period, icon: Icons.event_rounded),
      if (amount != null) (label: amount, icon: Icons.euro_rounded),
    ];
  }
}

/// Feuille « Filtres » : retourne les nouveaux filtres (`none` pour « Tout
/// effacer »), ou `null` si elle est fermée sans choix.
abstract final class AcompteFiltersSheet {
  static Future<AcompteFilters?> show(
    BuildContext context, {
    required AcompteFilters initial,
  }) {
    return AppSheet.show<AcompteFilters>(
      context,
      title: 'Filtres',
      trailing: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).pop(AcompteFilters.none),
          style: TextButton.styleFrom(
            foregroundColor: ctx.colors.primary,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('Tout effacer'),
        ),
      ),
      builder: (ctx) => _FiltersBody(
        initial: initial,
        onApply: (filters) => Navigator.of(ctx).pop(filters),
      ),
    );
  }
}

class _FiltersBody extends StatefulWidget {
  const _FiltersBody({required this.initial, required this.onApply});

  final AcompteFilters initial;
  final ValueChanged<AcompteFilters> onApply;

  @override
  State<_FiltersBody> createState() => _FiltersBodyState();
}

class _FiltersBodyState extends State<_FiltersBody> {
  late DateTime? _startDate = widget.initial.startDate;
  late DateTime? _endDate = widget.initial.endDate;
  late AcompteStatus? _status = widget.initial.status;
  late final _montantMinController = TextEditingController(
    text: widget.initial.montantMin?.toString() ?? '',
  );
  late final _montantMaxController = TextEditingController(
    text: widget.initial.montantMax?.toString() ?? '',
  );

  @override
  void dispose() {
    _montantMinController.dispose();
    _montantMaxController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? current) {
    final first = DateTime(2020);
    final last = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: clampPickerDate(current ?? DateTime.now(), first, last),
      firstDate: first,
      lastDate: last,
      locale: const Locale('fr', 'FR'),
    );
  }

  Future<void> _selectStartDate() async {
    final date = await _pickDate(_startDate);
    if (!mounted || date == null) return;
    setState(() => _startDate = date);
  }

  Future<void> _selectEndDate() async {
    final date = await _pickDate(_endDate);
    if (!mounted || date == null) return;
    setState(() => _endDate = date);
  }

  void _apply() {
    widget.onApply(
      AcompteFilters(
        startDate: _startDate,
        endDate: _endDate,
        status: _status,
        montantMin: _parseMontant(_montantMinController.text),
        montantMax: _parseMontant(_montantMaxController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppFieldLabel('Statut'),
        ChoiceChipsWrap<AcompteStatus?>(
          options: [
            const ChoiceOption(value: null, label: 'Tous'),
            for (final s in AcompteStatus.values)
              ChoiceOption(value: s, label: s.label),
          ],
          selected: _status,
          onChanged: (s) => setState(() => _status = s),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPickerField(
          label: 'Du',
          value: _startDate == null ? null : DisplayFormat.date(_startDate!),
          placeholder: 'Début de période',
          icon: Icons.event_rounded,
          trailingIcon: Icons.expand_more_rounded,
          onTap: _selectStartDate,
          onClear: () => setState(() => _startDate = null),
        ),
        const SizedBox(height: AppSpacing.base),
        AppPickerField(
          label: 'Au',
          value: _endDate == null ? null : DisplayFormat.date(_endDate!),
          placeholder: 'Fin de période',
          icon: Icons.event_rounded,
          trailingIcon: Icons.expand_more_rounded,
          onTap: _selectEndDate,
          onClear: () => setState(() => _endDate = null),
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppFieldLabel('Montant'),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _montantMinController,
                hint: 'Min (€)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                controller: _montantMaxController,
                hint: 'Max (€)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          text: 'Appliquer les filtres',
          icon: Icons.check_rounded,
          size: ButtonSize.lg,
          onPressed: _apply,
        ),
      ],
    );
  }
}

/// Montant saisi au clavier français : « 150,50 » comme « 150.50 ».
double? _parseMontant(String? text) {
  if (text == null) return null;
  final cleaned = text.trim().replaceAll(RegExp(r'[\s\u00A0\u202F€]'), '');
  return double.tryParse(cleaned.replaceAll(',', '.'));
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';
import 'absence_visuals.dart';
import 'request_widgets.dart';

/// Filtres de la liste des absences (période, statut, type).
@immutable
class AbsenceFilters {
  const AbsenceFilters({this.startDate, this.endDate, this.status, this.type});

  static const none = AbsenceFilters();

  /// Filtre du hero : « En attente » seul.
  static const pendingOnly = AbsenceFilters(status: 'PENDING');

  final DateTime? startDate;
  final DateTime? endDate;

  /// Valeur API du statut (`PENDING`, `APPROVED`, `REJECTED`).
  final String? status;
  final AbsenceType? type;

  bool get isActive =>
      startDate != null || endDate != null || status != null || type != null;

  bool get isPendingOnly =>
      status == 'PENDING' && startDate == null && endDate == null && type == null;

  /// Groupes actifs : période, statut, type.
  int get count =>
      (startDate != null || endDate != null ? 1 : 0) +
      (status != null ? 1 : 0) +
      (type != null ? 1 : 0);

  AbsenceFilters withoutPeriod() =>
      AbsenceFilters(status: status, type: type);
  AbsenceFilters withoutStatus() =>
      AbsenceFilters(startDate: startDate, endDate: endDate, type: type);
  AbsenceFilters withoutType() =>
      AbsenceFilters(startDate: startDate, endDate: endDate, status: status);

  /// Libellé court de la période : « 12/03 – 14/03 », « Depuis 12/03 »…
  String? get periodLabel {
    final f = DateFormat('dd/MM', 'fr_FR');
    if (startDate != null && endDate != null) {
      return '${f.format(startDate!)} – ${f.format(endDate!)}';
    }
    if (startDate != null) return 'Depuis ${f.format(startDate!)}';
    if (endDate != null) return 'Jusqu\'au ${f.format(endDate!)}';
    return null;
  }
}

/// Filtres actifs en tête de liste, chacun retirable seul : [onChanged]
/// reçoit les filtres restants.
List<ActiveFilter> activeAbsenceFilters(
  AbsenceFilters f,
  ValueChanged<AbsenceFilters> onChanged,
) {
  return [
    if (f.periodLabel != null)
      ActiveFilter(
        label: f.periodLabel!,
        icon: Icons.event_rounded,
        onRemove: () => onChanged(f.withoutPeriod()),
      ),
    if (f.status != null)
      ActiveFilter(
        label: AbsenceStatus.fromString(f.status!).displayName,
        icon: Icons.flag_rounded,
        onRemove: () => onChanged(f.withoutStatus()),
      ),
    if (f.type != null)
      ActiveFilter(
        label: f.type!.name,
        icon: Icons.category_rounded,
        onRemove: () => onChanged(f.withoutType()),
      ),
  ];
}

/// Options de statut du filtre.
const _statusOptions = <ChoiceOption<String?>>[
  ChoiceOption(value: null, label: 'Tous'),
  ChoiceOption(value: 'PENDING', label: 'En attente'),
  ChoiceOption(value: 'APPROVED', label: 'Approuvée'),
  ChoiceOption(value: 'REJECTED', label: 'Refusée'),
];

/// Feuille « Filtres » : retourne les nouveaux filtres (`none` pour « Tout
/// effacer »), ou `null` si elle est fermée sans choix.
abstract final class AbsenceFiltersSheet {
  static Future<AbsenceFilters?> show(
    BuildContext context, {
    required AbsenceFilters initial,
    required List<AbsenceType> absenceTypes,
  }) {
    return AppSheet.show<AbsenceFilters>(
      context,
      title: 'Filtres',
      trailing: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).pop(AbsenceFilters.none),
          style: TextButton.styleFrom(
            foregroundColor: ctx.colors.primary,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('Tout effacer'),
        ),
      ),
      builder: (ctx) => _FiltersBody(
        initial: initial,
        absenceTypes: absenceTypes,
        onApply: (filters) => Navigator.of(ctx).pop(filters),
      ),
    );
  }
}

class _FiltersBody extends StatefulWidget {
  const _FiltersBody({
    required this.initial,
    required this.absenceTypes,
    required this.onApply,
  });

  final AbsenceFilters initial;
  final List<AbsenceType> absenceTypes;
  final ValueChanged<AbsenceFilters> onApply;

  @override
  State<_FiltersBody> createState() => _FiltersBodyState();
}

class _FiltersBodyState extends State<_FiltersBody> {
  late DateTime? _startDate = widget.initial.startDate;
  late DateTime? _endDate = widget.initial.endDate;
  late String? _status = widget.initial.status;
  late AbsenceType? _type = widget.initial.type;

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final first = now.subtract(const Duration(days: 365));
    final last = now.add(const Duration(days: 365));
    final date = await showDatePicker(
      context: context,
      initialDate: clampPickerDate(
        _startDate ?? now.subtract(const Duration(days: 30)),
        first,
        last,
      ),
      firstDate: first,
      lastDate: last,
    );
    if (!mounted || date == null) return;
    setState(() {
      _startDate = date;
      if (_endDate != null && _endDate!.isBefore(date)) _endDate = date;
    });
  }

  Future<void> _selectEndDate() async {
    final now = DateTime.now();
    final first = _startDate ?? now.subtract(const Duration(days: 365));
    final last = now.add(const Duration(days: 365));
    final date = await showDatePicker(
      context: context,
      initialDate: clampPickerDate(_endDate ?? now, first, last),
      firstDate: first,
      lastDate: last,
    );
    if (!mounted || date == null) return;
    setState(() => _endDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = widget.absenceTypes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const AppFieldLabel('Statut'),
        ChoiceChipsWrap<String?>(
          options: _statusOptions,
          selected: _status,
          onChanged: (v) => setState(() => _status = v),
        ),
        if (types.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const AppFieldLabel('Type d\'absence'),
          ChoiceChipsWrap<String?>(
            options: [
              const ChoiceOption(value: null, label: 'Tous'),
              for (final t in types)
                ChoiceOption(
                  value: t.uuid,
                  label: t.name,
                  dotColor: absenceTypeColor(t.color, colors),
                ),
            ],
            selected: _type?.uuid,
            onChanged: (uuid) => setState(() {
              _type = uuid == null
                  ? null
                  : types.firstWhere((t) => t.uuid == uuid);
            }),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          text: 'Appliquer les filtres',
          icon: Icons.check_rounded,
          size: ButtonSize.lg,
          onPressed: () => widget.onApply(
            AbsenceFilters(
              startDate: _startDate,
              endDate: _endDate,
              status: _status,
              type: _type,
            ),
          ),
        ),
      ],
    );
  }
}

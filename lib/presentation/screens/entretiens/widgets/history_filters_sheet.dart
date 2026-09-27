import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/entretien_model.dart';
import '../../../../data/models/vehicule_model.dart';
import '../../../widgets/widgets.dart';
import 'type_entretien_picker.dart';

/// Entier saisi (« 150 000 », « 150000 ») → `int`, `null` si vide/invalide.
int? parseIntInput(String text) {
  final digits = text.replaceAll(RegExp(r'[\s\u00A0\u202F]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

/// Montant saisi (« 120,50 », « 120.5 ») → `double`, `null` si vide/invalide.
double? parseAmountInput(String text) {
  final cleaned =
      text.replaceAll(RegExp(r'[\s\u00A0\u202F€]'), '').replaceAll(',', '.');
  return cleaned.isEmpty ? null : double.tryParse(cleaned);
}

/// Feuille des filtres et du tri de l'historique. Retourne la nouvelle
/// requête (page 0), ou `null` si fermée sans appliquer.
Future<EntretienHistoryQuery?> showHistoryFiltersSheet(
  BuildContext context, {
  required EntretienHistoryQuery query,
  required List<TypeEntretien> types,
  required List<DossierTypeEntretien> dossiers,
  List<Vehicule>? vehicules,
}) {
  return AppSheet.show<EntretienHistoryQuery>(
    context,
    title: 'Filtrer l\'historique',
    builder: (_) => _FiltersBody(
      query: query,
      types: types,
      dossiers: dossiers,
      vehicules: vehicules,
    ),
  );
}

class _FiltersBody extends StatefulWidget {
  const _FiltersBody({
    required this.query,
    required this.types,
    required this.dossiers,
    this.vehicules,
  });

  final EntretienHistoryQuery query;
  final List<TypeEntretien> types;
  final List<DossierTypeEntretien> dossiers;

  /// `null` : le véhicule est imposé par la page, pas de champ Véhicule.
  final List<Vehicule>? vehicules;

  @override
  State<_FiltersBody> createState() => _FiltersBodyState();
}

class _FiltersBodyState extends State<_FiltersBody> {
  late String? _vehiculeId = widget.query.vehiculeId;
  late String? _dossierId = widget.query.dossierId;
  late String? _typeId = widget.query.typeEntretienId;
  late DateTime? _start = widget.query.startDate;
  late DateTime? _end = widget.query.endDate;
  late EntretienSort _sort = widget.query.sort;
  late bool _ascending = widget.query.ascending;

  late final _kmMin = TextEditingController(text: widget.query.kmMin?.toString());
  late final _kmMax = TextEditingController(text: widget.query.kmMax?.toString());
  late final _coutMin =
      TextEditingController(text: _amount(widget.query.coutMin));
  late final _coutMax =
      TextEditingController(text: _amount(widget.query.coutMax));

  static String? _amount(double? v) {
    if (v == null) return null;
    return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
  }

  @override
  void dispose() {
    _kmMin.dispose();
    _kmMax.dispose();
    _coutMin.dispose();
    _coutMax.dispose();
    super.dispose();
  }

  List<TypeEntretien> get _typesInScope => _dossierId == null
      ? widget.types
      : widget.types.where((t) => t.dossier?.id == _dossierId).toList();

  TypeEntretien? get _type =>
      widget.types.where((t) => t.id == _typeId).firstOrNull;

  void _reset() {
    setState(() {
      if (widget.vehicules != null) _vehiculeId = null;
      _dossierId = null;
      _typeId = null;
      _start = null;
      _end = null;
      _sort = EntretienSort.date;
      _ascending = false;
      _kmMin.clear();
      _kmMax.clear();
      _coutMin.clear();
      _coutMax.clear();
    });
  }

  void _apply() {
    var start = _start;
    var end = _end;
    if (start != null && end != null && end.isBefore(start)) {
      (start, end) = (end, start);
    }
    Navigator.of(context).pop(
      EntretienHistoryQuery(
        size: widget.query.size,
        sort: _sort,
        ascending: _ascending,
        vehiculeId: _vehiculeId,
        dossierId: _dossierId,
        typeEntretienId: _typeId,
        startDate: start,
        endDate: end,
        kmMin: parseIntInput(_kmMin.text),
        kmMax: parseIntInput(_kmMax.text),
        coutMin: parseAmountInput(_coutMin.text),
        coutMax: parseAmountInput(_coutMax.text),
      ),
    );
  }

  (String, String) get _orderLabels => switch (_sort) {
        EntretienSort.date => ('Récents d\'abord', 'Anciens d\'abord'),
        EntretienSort.kilometrage => ('Km élevé d\'abord', 'Km bas d\'abord'),
        EntretienSort.cout => ('Plus chers d\'abord', 'Moins chers d\'abord'),
      };

  @override
  Widget build(BuildContext context) {
    final vehicules = widget.vehicules;
    final dossier =
        widget.dossiers.where((d) => d.id == _dossierId).firstOrNull;
    final vehicule = vehicules?.where((v) => v.id == _vehiculeId).firstOrNull;
    final (desc, asc) = _orderLabels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vehicules != null) ...[
          AppSearchableSelect<Vehicule>(
            label: 'Véhicule',
            items: vehicules,
            selectedItem: vehicule,
            onChanged: (v) => setState(() => _vehiculeId = v?.id),
            itemLabel: (v) => v.immat.toUpperCase(),
            itemSubtitle: (v) => '${v.brand} ${v.model}'.trim(),
            itemIcon: (_) => Icons.directions_car_rounded,
            placeholder: 'Tous les véhicules',
            sheetTitle: 'Véhicule',
            searchHint: 'Immatriculation, marque…',
            clearable: true,
          ),
          const SizedBox(height: AppSpacing.base),
        ],
        AppSearchableSelect<DossierTypeEntretien>(
          label: 'Dossier',
          items: widget.dossiers,
          selectedItem: dossier,
          onChanged: (d) => setState(() {
            _dossierId = d?.id;
            // Le type choisi doit appartenir au dossier.
            if (_type != null && d != null && _type!.dossier?.id != d.id) {
              _typeId = null;
            }
          }),
          itemLabel: (d) => d.nom,
          itemIcon: (_) => Icons.folder_rounded,
          placeholder: 'Tous les dossiers',
          sheetTitle: 'Dossier',
          clearable: true,
        ),
        const SizedBox(height: AppSpacing.base),
        AppPickerField(
          label: 'Type d\'entretien',
          value: _type?.nom,
          subtitle: _type?.dossier?.nom,
          placeholder: 'Tous les types',
          icon: Icons.build_rounded,
          onTap: () async {
            final picked = await showTypeEntretienPicker(
              context,
              types: _typesInScope,
              selected: _type,
            );
            if (picked != null && mounted) {
              setState(() => _typeId = picked.id);
            }
          },
          onClear: () => setState(() => _typeId = null),
        ),
        const SizedBox(height: AppSpacing.base),
        const AppFieldLabel('Période'),
        Row(
          children: [
            Expanded(
              child: AppDateField(
                value: _start,
                placeholder: 'Du',
                clearable: true,
                lastDate: DateTime.now().add(const Duration(days: 366)),
                onChanged: (d) => setState(() => _start = d),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppDateField(
                value: _end,
                placeholder: 'Au',
                clearable: true,
                lastDate: DateTime.now().add(const Duration(days: 366)),
                onChanged: (d) => setState(() => _end = d),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        const AppFieldLabel('Kilométrage'),
        _RangeFields(
          min: _kmMin,
          max: _kmMax,
          suffix: 'km',
          decimal: false,
        ),
        const SizedBox(height: AppSpacing.base),
        const AppFieldLabel('Coût HT'),
        _RangeFields(
          min: _coutMin,
          max: _coutMax,
          suffix: '€',
          decimal: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppFieldLabel('Trier par'),
        AppSegmented<EntretienSort>(
          segments: [
            for (final s in EntretienSort.values)
              AppSegment(value: s, label: s.label),
          ],
          selected: _sort,
          onChanged: (s) => setState(() => _sort = s),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSegmented<bool>(
          segments: [
            AppSegment(value: false, label: desc),
            AppSegment(value: true, label: asc),
          ],
          selected: _ascending,
          onChanged: (v) => setState(() => _ascending = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          text: 'Afficher les résultats',
          icon: Icons.check_rounded,
          size: ButtonSize.lg,
          onPressed: _apply,
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 52,
          child: TextButton(
            onPressed: _reset,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.foreground,
            ),
            child: const Text('Tout effacer'),
          ),
        ),
      ],
    );
  }
}

/// Deux champs « min » / « max » côte à côte.
class _RangeFields extends StatelessWidget {
  const _RangeFields({
    required this.min,
    required this.max,
    required this.suffix,
    required this.decimal,
  });

  final TextEditingController min;
  final TextEditingController max;
  final String suffix;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String hint) => TextField(
          controller: c,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              decimal ? RegExp(r'[0-9,.\s]') : RegExp(r'[0-9\s]'),
            ),
          ],
          textInputAction: TextInputAction.next,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(hintText: hint, suffixText: suffix),
        );

    return Row(
      children: [
        Expanded(child: field(min, 'Min')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: field(max, 'Max')),
      ],
    );
  }
}

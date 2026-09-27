import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/widgets.dart';
import 'absence_visuals.dart';
import 'request_widgets.dart';

/// Valeur de la pastille « Autre » (type personnalisé).
const _customTypeKey = '__custom__';

/// Formulaire « Nouvelle absence » en plein écran : type (ou type
/// personnalisé), dates, demi-journée, motif. Le bouton d'envoi vit dans le
/// dock. Retourne l'absence créée, ou `null` si on ferme sans envoyer.
class CreateAbsencePage extends StatefulWidget {
  const CreateAbsencePage({super.key});

  static Future<Absence?> open(BuildContext context) {
    return Navigator.of(context).push<Absence>(
      MaterialPageRoute(
        builder: (_) => const CreateAbsencePage(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<CreateAbsencePage> createState() => _CreateAbsencePageState();
}

class _CreateAbsencePageState extends State<CreateAbsencePage>
    with DockNoticeMixin {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _customTypeController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  AbsencePeriod? _selectedPeriod;
  bool _isLoading = false;
  bool _isLoadingTypes = true;
  List<AbsenceType> _absenceTypes = [];
  AbsenceType? _selectedType;
  bool _useCustomType = false;

  /// Un envoi a été tenté : les champs manquants s'affichent en erreur.
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _loadAbsenceTypes();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadAbsenceTypes() async {
    final result = await sl.absenceRepository.getAbsenceTypes();
    if (!mounted) return;
    result.fold(
      (failure) => setState(() => _isLoadingTypes = false),
      (types) => setState(() {
        _absenceTypes = types;
        _isLoadingTypes = false;
      }),
    );
  }

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final last = now.add(const Duration(days: 365));
    final date = await showDatePicker(
      context: context,
      initialDate: clampPickerDate(_startDate ?? now, now, last),
      firstDate: now,
      lastDate: last,
    );
    if (!mounted || date == null) return;
    setState(() {
      _startDate = date;
      if (_endDate != null && _endDate!.isBefore(date)) _endDate = date;
    });
  }

  Future<void> _selectEndDate() async {
    // Sans date de début, on la demande d'abord.
    if (_startDate == null) {
      await _selectStartDate();
      return;
    }
    final last = DateTime.now().add(const Duration(days: 365));
    final date = await showDatePicker(
      context: context,
      initialDate: clampPickerDate(_endDate ?? _startDate!, _startDate!, last),
      firstDate: _startDate!,
      lastDate: last,
    );
    if (!mounted || date == null) return;
    setState(() => _endDate = date);
  }

  void _selectType(String? key) {
    setState(() {
      if (key == _customTypeKey) {
        _useCustomType = true;
        _selectedType = null;
      } else {
        _selectedType = _absenceTypes.firstWhere((t) => t.uuid == key);
        _useCustomType = false;
      }
    });
  }

  Future<void> _submit() async {
    clearDockNotice();
    setState(() => _attempted = true);
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      showDockError('Choisis les dates de début et de fin');
      return;
    }
    if (_selectedType == null && !_useCustomType) {
      showDockError('Choisis un type d\'absence');
      return;
    }
    if (_useCustomType && _customTypeController.text.trim().isEmpty) {
      showDockError('Précise le type d\'absence');
      return;
    }

    setState(() => _isLoading = true);

    final result = await sl.absenceRepository.createAbsence(
      CreateAbsenceRequest(
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
        absenceTypeUuid: _useCustomType ? null : _selectedType?.uuid,
        customType: _useCustomType ? _customTypeController.text.trim() : null,
        period: _selectedPeriod,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isLoading = false);
        showDockError(failure.message);
      },
      (absence) => Navigator.of(context).pop(absence),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typeMissing = _attempted && _selectedType == null && !_useCustomType;
    final customMissing = _attempted &&
        _useCustomType &&
        _customTypeController.text.trim().isEmpty;

    return AppPage(
      title: 'Nouvelle absence',
      body: Form(
        key: _formKey,
        child: AppScrollView(
          topPadding: AppSpacing.base,
          children: [
            const AppFieldLabel('Type d\'absence'),
            if (_isLoadingTypes)
              const _TypeChipsSkeleton()
            else
              ChoiceChipsWrap<String?>(
                options: [
                  for (final t in _absenceTypes)
                    ChoiceOption(
                      value: t.uuid,
                      label: t.name,
                      dotColor: absenceTypeColor(t.color, colors),
                    ),
                  const ChoiceOption(
                    value: _customTypeKey,
                    label: 'Autre',
                    icon: Icons.add_rounded,
                  ),
                ],
                selected: _useCustomType ? _customTypeKey : _selectedType?.uuid,
                onChanged: _selectType,
                errorText: typeMissing ? 'Choisis un type d\'absence' : null,
              ),
            if (_useCustomType) ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _customTypeController,
                hint: 'Précise le type d\'absence',
                errorText: customMissing ? 'Précise le type d\'absence' : null,
                onChanged: (_) {
                  if (_attempted) setState(() {});
                },
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppPickerField(
              label: 'Date de début',
              value: _startDate == null ? null : DisplayFormat.date(_startDate!),
              placeholder: 'Choisir une date',
              icon: Icons.event_rounded,
              trailingIcon: Icons.expand_more_rounded,
              onTap: _selectStartDate,
              errorText: _attempted && _startDate == null
                  ? 'Choisis la date de début'
                  : null,
            ),
            const SizedBox(height: AppSpacing.base),
            AppPickerField(
              label: 'Date de fin',
              value: _endDate == null ? null : DisplayFormat.date(_endDate!),
              placeholder: 'Choisir une date',
              icon: Icons.event_rounded,
              trailingIcon: Icons.expand_more_rounded,
              onTap: _selectEndDate,
              errorText: _attempted && _endDate == null
                  ? 'Choisis la date de fin'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppFieldLabel('Période', optional: true),
            AppSegmented<AbsencePeriod?>(
              segments: const [
                AppSegment(value: null, label: 'Journée'),
                AppSegment(value: AbsencePeriod.morning, label: 'Matin'),
                AppSegment(
                  value: AbsencePeriod.afternoon,
                  label: 'Après-midi',
                ),
              ],
              selected: _selectedPeriod,
              onChanged: (p) => setState(() => _selectedPeriod = p),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppFieldLabel('Motif', optional: true),
            AppTextField(
              controller: _reasonController,
              hint: 'Explique en quelques mots…',
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
          ],
        ),
      ),
      dock: AppDock(
        actions: [
          DockAction(
            label: 'Envoyer la demande',
            icon: Icons.send_rounded,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submit,
          ),
        ],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
        absorbing: _isLoading,
      ),
    );
  }
}

/// Pastilles fantômes pendant le chargement des types.
class _TypeChipsSkeleton extends StatelessWidget {
  const _TypeChipsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppSkeleton(width: 120, height: 44, borderRadius: AppRadius.full),
        AppSkeleton(width: 90, height: 44, borderRadius: AppRadius.full),
        AppSkeleton(width: 140, height: 44, borderRadius: AppRadius.full),
        AppSkeleton(width: 80, height: 44, borderRadius: AppRadius.full),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/entretien_model.dart';
import '../../../widgets/widgets.dart';
import '../logic/fleet_status.dart';
import 'history_filters_sheet.dart';
import 'type_entretien_picker.dart';

/// Ajout ou modification d'un suivi périodique (« Vidange tous les
/// 30 000 km »). Retourne `true` si le suivi a été enregistré ou supprimé.
abstract final class ConfigEntretienSheet {
  static Future<bool> show(
    BuildContext context, {
    required String vehiculeId,
    VehiculeTypeEntretien? config,
    required List<TypeEntretien> availableTypes,
  }) async {
    final changed = await AppSheet.show<bool>(
      context,
      title: config == null ? 'Nouveau suivi' : 'Modifier le suivi',
      builder: (_) => _ConfigBody(
        vehiculeId: vehiculeId,
        config: config,
        availableTypes: availableTypes,
      ),
    );
    return changed ?? false;
  }
}

class _ConfigBody extends StatefulWidget {
  const _ConfigBody({
    required this.vehiculeId,
    required this.config,
    required this.availableTypes,
  });

  final String vehiculeId;
  final VehiculeTypeEntretien? config;

  /// Types pas encore suivis pour ce véhicule (création).
  final List<TypeEntretien> availableTypes;

  @override
  State<_ConfigBody> createState() => _ConfigBodyState();
}

class _ConfigBodyState extends State<_ConfigBody> {
  late TypeEntretien? _type = widget.config?.typeEntretien;
  late PeriodiciteType _kind =
      widget.config?.periodiciteType ?? PeriodiciteType.kilometrage;
  late PeriodUnit _unit = widget.config == null ||
          widget.config!.periodiciteType == PeriodiciteType.kilometrage
      ? PeriodUnit.months
      : PeriodUnit.bestFor(widget.config!.periodiciteValeur);
  late final _value = TextEditingController(text: _initialValue());
  late bool _actif = widget.config?.actif ?? true;

  bool _saving = false;
  bool _deleting = false;
  String? _error;
  String? _typeError;
  String? _valueError;

  bool get _isEdit => widget.config != null;

  String _initialValue() {
    final c = widget.config;
    if (c == null) return '';
    if (c.periodiciteType == PeriodiciteType.kilometrage) {
      return c.periodiciteValeur.toString();
    }
    final unit = PeriodUnit.bestFor(c.periodiciteValeur);
    return (c.periodiciteValeur ~/ unit.dayCount).toString();
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  /// Valeur envoyée à l'API : km, ou jours (unité × nombre).
  int? get _apiValue {
    final n = parseIntInput(_value.text);
    if (n == null || n <= 0) return null;
    return _kind == PeriodiciteType.kilometrage ? n : n * _unit.dayCount;
  }

  void _switchKind(PeriodiciteType kind) {
    // Changer d'unité de mesure remet la valeur à zéro : 30 000 km ne
    // doivent pas devenir 30 000 jours.
    setState(() {
      _kind = kind;
      _value.clear();
      _valueError = null;
    });
  }

  Future<void> _pickType() async {
    final picked = await showTypeEntretienPicker(
      context,
      types: widget.availableTypes,
      selected: _type,
    );
    if (picked != null && mounted) {
      setState(() {
        _type = picked;
        _typeError = null;
      });
    }
  }

  Future<void> _save() async {
    final value = _apiValue;
    setState(() {
      _typeError = _type == null ? 'Choisis le type d\'entretien.' : null;
      _valueError = value == null ? 'Indique un intervalle supérieur à 0.' : null;
      _error = null;
    });
    if (_typeError != null || _valueError != null) {
      HapticFeedback.vibrate();
      return;
    }

    setState(() => _saving = true);
    final repo = sl.entretienRepository;
    final result = _isEdit
        ? await repo.updateVehiculeConfig(
            widget.config!.id,
            VehiculeTypeEntretienUpdateRequest(
              periodiciteType: _kind,
              periodiciteValeur: value!,
              actif: _actif,
            ),
          )
        : await repo.createVehiculeConfig(
            VehiculeTypeEntretienCreateRequest(
              vehiculeId: widget.vehiculeId,
              typeEntretienId: _type!.id,
              periodiciteType: _kind,
              periodiciteValeur: value!,
            ),
          );
    if (!mounted) return;
    result.fold(
      (failure) {
        HapticFeedback.heavyImpact();
        setState(() {
          _saving = false;
          _error = failure.message;
        });
      },
      (_) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(true);
      },
    );
  }

  Future<void> _delete() async {
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Supprimer ce suivi ?',
      message: 'Les échéances de « ${_type?.nom ?? 'cet entretien'} » ne '
          'seront plus calculées pour ce véhicule. Les entretiens déjà '
          'enregistrés sont conservés.',
      confirmLabel: 'Supprimer le suivi',
      confirmIcon: Icons.delete_rounded,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    final result =
        await sl.entretienRepository.deleteVehiculeConfig(widget.config!.id);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _deleting = false;
        _error = failure.message;
      }),
      (_) => Navigator.of(context).pop(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final busy = _saving || _deleting;
    final value = _apiValue;

    return AbsorbPointer(
      absorbing: busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Un suivi rappelle l\'entretien à intervalle régulier, au '
            'kilométrage ou dans le temps, à partir du dernier fait.',
            style: textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppPickerField(
            label: 'Entretien',
            value: _type?.nom,
            subtitle: _type?.dossier?.nom,
            placeholder: 'Choisir le type',
            icon: Icons.build_rounded,
            // Le type d'un suivi existant ne change pas : lisible, pas grisé.
            trailingIcon:
                _isEdit ? Icons.lock_outline_rounded : Icons.unfold_more_rounded,
            errorText: _typeError,
            onTap: _isEdit ? null : _pickType,
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppFieldLabel('Rappeler selon'),
          AppSegmented<PeriodiciteType>(
            segments: const [
              AppSegment(
                value: PeriodiciteType.kilometrage,
                label: 'Kilométrage',
                icon: Icons.route_rounded,
              ),
              AppSegment(
                value: PeriodiciteType.temporel,
                label: 'Durée',
                icon: Icons.event_rounded,
              ),
            ],
            selected: _kind,
            onChanged: _switchKind,
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppFieldLabel('Intervalle'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _value,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\s]')),
                  ],
                  onChanged: (_) => setState(() => _valueError = null),
                  style: textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText:
                        _kind == PeriodiciteType.kilometrage ? 'Ex. 30000' : 'Ex. 6',
                    suffixText:
                        _kind == PeriodiciteType.kilometrage ? 'km' : null,
                    errorText: _valueError,
                  ),
                ),
              ),
              if (_kind == PeriodiciteType.temporel) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AppSegmented<PeriodUnit>(
                      segments: [
                        for (final u in PeriodUnit.values)
                          AppSegment(value: u, label: u.label),
                      ],
                      selected: _unit,
                      onChanged: (u) => setState(() => _unit = u),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.xs),
              child: Text(
                formatPeriodicite(_kind, value),
                style: textTheme.bodySmall,
              ),
            ),
          if (_isEdit) ...[
            const SizedBox(height: AppSpacing.lg),
            // Material (et non Container) : le ListTile y peint son encre.
            Material(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                value: _actif,
                onChanged: (v) => setState(() => _actif = v),
                title: Text('Suivi actif', style: textTheme.titleSmall),
                subtitle: Text(
                  _actif
                      ? 'Les échéances sont calculées'
                      : 'En pause : aucune échéance calculée',
                  style: textTheme.bodySmall,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.base),
            AppAlert(variant: AlertVariant.destructive, description: _error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: _isEdit ? 'Enregistrer le suivi' : 'Ajouter le suivi',
            icon: Icons.check_rounded,
            size: ButtonSize.lg,
            isLoading: _saving,
            onPressed: busy ? null : _save,
          ),
          if (_isEdit) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 52,
              child: TextButton.icon(
                onPressed: busy ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: colors.destructive),
                icon: _deleting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.destructive,
                        ),
                      )
                    : const Icon(Icons.delete_outline_rounded, size: 20),
                label: const Text('Supprimer le suivi'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

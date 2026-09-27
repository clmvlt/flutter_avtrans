import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/entretien_model.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';
import 'logic/entretien_catalog.dart';
import 'logic/entretien_files.dart';
import 'widgets/entretien_files_list.dart';
import 'widgets/history_filters_sheet.dart';
import 'widgets/type_entretien_picker.dart';

/// Saisie ou modification d'un entretien, en page plein écran : véhicule,
/// type, date, kilométrage, coût, commentaire, fichiers. Le bouton
/// d'enregistrement est dans le dock.
///
/// Retourne `true` si quelque chose a été enregistré (entretien ou fichier).
class EntretienFormScreen extends StatefulWidget {
  const EntretienFormScreen({
    super.key,
    this.entretien,
    this.vehicule,
    this.initialType,
  });

  /// Entretien à modifier (sinon création).
  final Entretien? entretien;

  /// Véhicule imposé (création depuis la page d'un véhicule).
  final Vehicule? vehicule;

  /// Type présélectionné (échéance validée depuis la page d'un véhicule).
  final TypeEntretien? initialType;

  static Future<bool> open(
    BuildContext context, {
    Entretien? entretien,
    Vehicule? vehicule,
    TypeEntretien? initialType,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EntretienFormScreen(
          entretien: entretien,
          vehicule: vehicule,
          initialType: initialType,
        ),
      ),
    );
    return saved ?? false;
  }

  @override
  State<EntretienFormScreen> createState() => _EntretienFormScreenState();
}

class _EntretienFormScreenState extends State<EntretienFormScreen>
    with DockNoticeMixin {
  bool get _isEdit => widget.entretien != null;

  // Données de référence.
  bool _loading = true;
  String? _loadError;
  List<Vehicule> _vehicules = const [];
  List<TypeEntretien> _types = const [];

  // Valeurs du formulaire.
  Vehicule? _vehicule;
  TypeEntretien? _type;
  DateTime _date = DateTime.now();
  late final _km = TextEditingController();
  late final _cout = TextEditingController();
  late final _commentaire = TextEditingController();
  final List<PendingFile> _pending = [];
  late List<EntretienFile> _existing = widget.entretien?.files ?? const [];

  // Erreurs de validation.
  String? _vehiculeError;
  String? _typeError;
  String? _kmError;
  String? _coutError;

  bool _saving = false;
  bool _dirty = false;

  /// Quelque chose a été enregistré côté serveur (le retour le signale).
  bool _changed = false;
  String? _deletingFileId;

  @override
  void initState() {
    super.initState();
    final e = widget.entretien;
    _vehicule = widget.vehicule;
    _type = e?.typeEntretien ?? widget.initialType;
    if (e != null) {
      _date = e.dateEntretien;
      if (e.kilometrage != null) _km.text = e.kilometrage.toString();
      if (e.cout != null) _cout.text = _formatAmount(e.cout!);
      _commentaire.text = e.commentaire ?? '';
    } else if (widget.vehicule?.latestKm != null) {
      _km.text = widget.vehicule!.latestKm.toString();
    }
    for (final c in [_km, _cout, _commentaire]) {
      c.addListener(_markDirty);
    }
    _load();
  }

  @override
  void dispose() {
    _km.dispose();
    _cout.dispose();
    _commentaire.dispose();
    super.dispose();
  }

  static String _formatAmount(double v) => v == v.truncateToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceAll('.', ',');

  void _markDirty() => _dirty = true;

  bool get _needsVehiclePicker => !_isEdit && widget.vehicule == null;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final catalog = await EntretienCatalog.load();
    final vehicules = _needsVehiclePicker
        ? await sl.vehiculeRepository.getAllVehicules()
        : null;
    if (!mounted) return;

    String? error;
    catalog.fold((f) => error = f.message, (c) => _types = c.types);
    vehicules?.fold((f) => error ??= f.message, (v) {
      _vehicules = [...v]..sort((a, b) => a.immat.compareTo(b.immat));
    });

    setState(() {
      _loading = false;
      _loadError = error;
    });
  }

  // ---- saisie -----------------------------------------------------------

  Future<void> _pickType() async {
    final picked = await showTypeEntretienPicker(
      context,
      types: _types,
      selected: _type,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _type = picked;
      _typeError = null;
      _dirty = true;
    });
  }

  void _selectVehicule(Vehicule? v) {
    setState(() {
      _vehicule = v;
      _vehiculeError = null;
      _dirty = true;
      if (_km.text.trim().isEmpty && v?.latestKm != null) {
        _km.text = v!.latestKm.toString();
      }
    });
  }

  Future<void> _addFile(FileSource source) async {
    final result = await pickEntretienFile(source);
    if (!mounted) return;
    switch (result) {
      case PickedFile(:final file):
        setState(() {
          _pending.add(file);
          _dirty = true;
        });
      case PickError(:final message):
        showDockError(message);
      case PickCancelled():
        break;
    }
  }

  Future<void> _deleteExisting(EntretienFile file) async {
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Supprimer ce fichier ?',
      message: '« ${file.originalName} » sera supprimé tout de suite et '
          'définitivement, même si tu n\'enregistres pas l\'entretien.',
      confirmLabel: 'Supprimer le fichier',
      confirmIcon: Icons.delete_rounded,
    );
    if (!confirmed || !mounted) return;
    setState(() => _deletingFileId = file.id);
    final result = await sl.entretienRepository.deleteFile(file.id);
    if (!mounted) return;
    result.fold(
      (failure) => showDockError(failure.message),
      (_) {
        _changed = true;
        _existing = _existing.where((f) => f.id != file.id).toList();
      },
    );
    setState(() => _deletingFileId = null);
  }

  // ---- validation et envoi ---------------------------------------------

  bool _validate() {
    final km = parseIntInput(_km.text);
    final coutText = _cout.text.trim();
    final cout = parseAmountInput(coutText);

    setState(() {
      _vehiculeError = _needsVehiclePicker && _vehicule == null
          ? 'Choisis le véhicule.'
          : null;
      _typeError = _type == null ? 'Choisis le type d\'entretien.' : null;
      _kmError = km == null
          ? 'Indique le kilométrage du véhicule.'
          : (km < 0 || km > 9999999 ? 'Kilométrage invalide.' : null);
      if (coutText.isNotEmpty && (cout == null || cout < 0)) {
        _coutError = 'Montant invalide.';
      } else if (coutText.isEmpty && _isEdit && widget.entretien!.cout != null) {
        // L'API ignore un coût absent : il ne peut pas être retiré.
        _coutError = 'Le coût ne peut pas être retiré : indique 0 si besoin.';
      } else {
        _coutError = null;
      }
    });
    return _vehiculeError == null &&
        _typeError == null &&
        _kmError == null &&
        _coutError == null;
  }

  Future<void> _save() async {
    clearDockNotice();
    if (!_validate()) {
      HapticFeedback.vibrate();
      return;
    }
    setState(() => _saving = true);

    final km = parseIntInput(_km.text)!;
    final cout = parseAmountInput(_cout.text);
    final commentaire = _commentaire.text.trim();

    if (!_isEdit) {
      final result = await sl.entretienRepository.createEntretien(
        EntretienCreateRequest(
          vehiculeId: (widget.vehicule ?? _vehicule)!.id,
          typeEntretienId: _type!.id,
          dateEntretien: _date,
          kilometrage: km,
          commentaire: commentaire.isEmpty ? null : commentaire,
          cout: cout,
          files: _pending.map((f) => f.toUpload()).toList(),
        ),
      );
      if (!mounted) return;
      result.fold(
        (failure) {
          HapticFeedback.heavyImpact();
          setState(() => _saving = false);
          showDockError(failure.message);
        },
        (_) {
          HapticFeedback.mediumImpact();
          Navigator.of(context).pop(true);
        },
      );
      return;
    }

    final e = widget.entretien!;
    final updated = await sl.entretienRepository.updateEntretien(
      e.id,
      EntretienUpdateRequest(
        typeEntretienId: _type!.id,
        dateEntretien: _date,
        kilometrage: km,
        commentaire: commentaire,
        cout: cout,
      ),
    );
    if (!mounted) return;
    final failure = updated.fold((f) => f, (_) => null);
    if (failure != null) {
      HapticFeedback.heavyImpact();
      setState(() => _saving = false);
      showDockError(failure.message);
      return;
    }
    _changed = true;

    // Fichiers ajoutés : un par un ; ceux envoyés quittent la liste, pour
    // qu'un nouvel essai ne les duplique pas.
    String? uploadError;
    while (_pending.isNotEmpty) {
      final file = _pending.first;
      final result =
          await sl.entretienRepository.addFile(e.id, file.toUpload());
      if (!mounted) return;
      final error = result.fold((f) => f.message, (_) => null);
      if (error != null) {
        uploadError = error;
        break;
      }
      setState(() => _pending.removeAt(0));
    }

    if (uploadError != null) {
      HapticFeedback.heavyImpact();
      setState(() => _saving = false);
      showDockError(
        'Entretien enregistré, mais « ${_pending.first.name} » n\'a pas pu '
        'être envoyé : $uploadError',
      );
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(true);
  }

  Future<void> _close() async {
    if (_dirty && !_saving) {
      final leave = await AppConfirmSheet.show(
        context,
        title: 'Abandonner la saisie ?',
        message: 'Ce que tu as saisi ne sera pas enregistré.',
        confirmLabel: 'Abandonner',
        cancelLabel: 'Continuer la saisie',
      );
      if (!leave || !mounted) return;
    }
    Navigator.of(context).pop(_changed);
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _close();
      },
      child: AppPage(
        title: _isEdit ? 'Modifier l\'entretien' : 'Nouvel entretien',
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Fermer',
          onPressed: _saving ? null : _close,
        ),
        body: _buildBody(),
        dock: AppDock(
          actions: _loading || _loadError != null
              ? const []
              : [
                  DockAction(
                    label: _isEdit
                        ? 'Enregistrer les modifications'
                        : 'Enregistrer l\'entretien',
                    icon: Icons.check_rounded,
                    isLoading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ],
          notice: dockNotice,
          onDismissNotice: clearDockNotice,
          absorbing: _saving,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppScrollView(
        children: [AppListSkeleton(rows: 5)],
      );
    }
    if (_loadError != null) {
      return AppScrollView(
        children: [AppErrorState(message: _loadError!, onRetry: _load)],
      );
    }

    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final vehicule = widget.vehicule ?? _vehicule;
    final lockedImmat = _isEdit
        ? widget.entretien!.vehiculeImmat
        : widget.vehicule?.immat;

    return AbsorbPointer(
      absorbing: _saving,
      child: AppScrollView(
        children: [
          if (!_needsVehiclePicker)
            _LockedVehicle(
              immat: lockedImmat ?? '',
              vehicule: vehicule,
            )
          else
            AppSearchableSelect<Vehicule>(
              label: 'Véhicule',
              items: _vehicules,
              selectedItem: _vehicule,
              onChanged: _selectVehicule,
              itemLabel: (v) => v.immat.toUpperCase(),
              itemSubtitle: (v) => [
                '${v.brand} ${v.model}'.trim(),
                if (v.latestKm != null) DisplayFormat.km(v.latestKm!),
              ].where((s) => s.isNotEmpty).join(' · '),
              itemIcon: (_) => Icons.directions_car_rounded,
              prefixIcon: Icons.directions_car_rounded,
              placeholder: 'Choisir le véhicule',
              sheetTitle: 'Véhicule',
              searchHint: 'Immatriculation, marque…',
            ),
          if (_vehiculeError != null) _FieldError(_vehiculeError!),
          const SizedBox(height: AppSpacing.lg),
          AppPickerField(
            label: 'Type d\'entretien',
            value: _type?.nom,
            subtitle: _type?.dossier?.nom,
            placeholder: 'Choisir le type',
            icon: Icons.build_rounded,
            errorText: _typeError,
            onTap: _pickType,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppDateField(
            label: 'Date',
            value: _date,
            lastDate: DateTime.now().add(const Duration(days: 366)),
            onChanged: (d) {
              if (d == null) return;
              setState(() {
                _date = d;
                _dirty = true;
              });
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppFieldLabel('Kilométrage'),
          TextField(
            controller: _km,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\s]')),
            ],
            textInputAction: TextInputAction.next,
            style: textTheme.bodyLarge,
            onChanged: (_) {
              if (_kmError != null) setState(() => _kmError = null);
            },
            decoration: InputDecoration(
              hintText: 'Ex. 150000',
              suffixText: 'km',
              errorText: _kmError,
              helperText: vehicule?.latestKm != null
                  ? 'Dernier relevé : ${DisplayFormat.km(vehicule!.latestKm!)}'
                      '${vehicule.latestKmDate != null ? ' (${DisplayFormat.dateSmart(vehicule.latestKmDate!)})' : ''}'
                  : null,
              helperStyle: textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppFieldLabel('Coût HT', optional: true),
          TextField(
            controller: _cout,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]')),
            ],
            textInputAction: TextInputAction.next,
            style: textTheme.bodyLarge,
            onChanged: (_) {
              if (_coutError != null) setState(() => _coutError = null);
            },
            decoration: InputDecoration(
              hintText: 'Ex. 120,50',
              suffixText: '€',
              errorText: _coutError,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppFieldLabel('Commentaire', optional: true),
          TextField(
            controller: _commentaire,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            style: textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Pièces changées, remarques…',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Fichiers', style: textTheme.titleSmall),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: AppSpacing.md),
            child: Text(
              'Factures, photos, bons d\'intervention (15 Mo max par fichier).',
              style: textTheme.bodySmall,
            ),
          ),
          if (_existing.isNotEmpty) ...[
            EntretienFilesList(
              entretienId: widget.entretien!.id,
              files: _existing,
              onDelete: _deletingFileId == null ? _deleteExisting : null,
              deletingId: _deletingFileId,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_pending.isNotEmpty) ...[
            PendingFilesList(
              files: _pending,
              onRemove: (i) => setState(() => _pending.removeAt(i)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AddFileButtons(onPick: _addFile, enabled: !_saving),
          if (_isEdit && _pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Les nouveaux fichiers seront envoyés à l\'enregistrement.',
                style: textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
              ),
            ),
        ],
      ),
    );
  }
}

/// Véhicule imposé, en lecture seule.
class _LockedVehicle extends StatelessWidget {
  const _LockedVehicle({required this.immat, this.vehicule});

  final String immat;
  final Vehicule? vehicule;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = vehicule;
    final model = v == null ? '' : '${v.brand} ${v.model}'.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppFieldLabel('Véhicule'),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: AppListRow(
            title: immat.toUpperCase(),
            subtitle: model.isEmpty ? null : model,
            icon: Icons.directions_car_rounded,
            iconColor: colors.domainVehicule,
            trailing: Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: colors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.destructive,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

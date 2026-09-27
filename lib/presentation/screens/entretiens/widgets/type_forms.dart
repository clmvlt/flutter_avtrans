import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/display_format.dart';
import '../../../../data/models/entretien_model.dart';
import '../../../widgets/widgets.dart';

/// Message lisible quand la base refuse une suppression (élément encore
/// utilisé : contrainte de clé étrangère).
String friendlyDeleteError(Failure f, String inUseMessage) {
  final m = f.message.toLowerCase();
  final isConstraint = m.contains('constraint') ||
      m.contains('violates') ||
      m.contains('foreign key') ||
      m.contains('could not execute');
  return isConstraint ? inUseMessage : f.message;
}

/// Création / modification d'un type d'entretien. Retourne `true` si le type
/// a été enregistré ou supprimé.
abstract final class TypeEntretienFormSheet {
  static Future<bool> show(
    BuildContext context, {
    TypeEntretien? type,
    required List<DossierTypeEntretien> dossiers,
    String? initialDossierId,
  }) async {
    final changed = await AppSheet.show<bool>(
      context,
      title: type == null ? 'Nouveau type d\'entretien' : 'Modifier le type',
      builder: (_) => _TypeForm(
        type: type,
        dossiers: dossiers,
        initialDossierId: initialDossierId,
      ),
    );
    return changed ?? false;
  }
}

class _TypeForm extends StatefulWidget {
  const _TypeForm({
    required this.type,
    required this.dossiers,
    required this.initialDossierId,
  });

  final TypeEntretien? type;
  final List<DossierTypeEntretien> dossiers;
  final String? initialDossierId;

  @override
  State<_TypeForm> createState() => _TypeFormState();
}

class _TypeFormState extends State<_TypeForm> {
  late final _nom = TextEditingController(text: widget.type?.nom);
  late final _description =
      TextEditingController(text: widget.type?.description);
  late String? _dossierId = widget.type?.dossier?.id ?? widget.initialDossierId;

  bool _saving = false;
  bool _deleting = false;
  String? _nomError;
  String? _error;

  bool get _isEdit => widget.type != null;

  /// L'API ignore un dossier absent : un type classé ne peut que changer de
  /// dossier, pas redevenir « non classé ».
  bool get _dossierLocked => _isEdit && widget.type!.dossier != null;

  @override
  void dispose() {
    _nom.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nom = _nom.text.trim();
    setState(() {
      _nomError = nom.isEmpty ? 'Donne un nom au type.' : null;
      _error = null;
    });
    if (_nomError != null) {
      HapticFeedback.vibrate();
      return;
    }
    setState(() => _saving = true);

    final description = _description.text.trim();
    final request = TypeEntretienRequest(
      nom: nom,
      // En modification, '' efface la description ; à la création, rien.
      description: _isEdit || description.isNotEmpty ? description : null,
      dossierId: _dossierId,
    );
    final result = _isEdit
        ? await sl.entretienRepository.updateType(widget.type!.id, request)
        : await sl.entretienRepository.createType(request);
    if (!mounted) return;
    result.fold(
      (f) {
        HapticFeedback.heavyImpact();
        setState(() {
          _saving = false;
          _error = f.message;
        });
      },
      (_) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(true);
      },
    );
  }

  Future<void> _delete() async {
    final type = widget.type!;
    setState(() {
      _deleting = true;
      _error = null;
    });

    // Un type déjà utilisé ne peut pas être supprimé : on le dit avant.
    final usage = await sl.entretienRepository.searchHistory(
      EntretienHistoryQuery(typeEntretienId: type.id, size: 1),
    );
    if (!mounted) return;
    final used = usage.fold((_) => 0, (page) => page.totalElements);
    if (used > 0) {
      setState(() {
        _deleting = false;
        _error = 'Ce type est utilisé par '
            '${DisplayFormat.plural(used, 'entretien')} : il ne peut pas '
            'être supprimé. Renomme-le si besoin.';
      });
      return;
    }
    setState(() => _deleting = false);

    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Supprimer ce type ?',
      message: '« ${type.nom} » sera supprimé définitivement.',
      confirmLabel: 'Supprimer le type',
      confirmIcon: Icons.delete_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    final result = await sl.entretienRepository.deleteType(type.id);
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _deleting = false;
        _error = friendlyDeleteError(
          f,
          'Ce type est encore utilisé (entretien ou suivi d\'un véhicule) : '
          'il ne peut pas être supprimé.',
        );
      }),
      (_) => Navigator.of(context).pop(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final busy = _saving || _deleting;
    final dossier = widget.dossiers.where((d) => d.id == _dossierId).firstOrNull;

    return AbsorbPointer(
      absorbing: busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppFieldLabel('Nom'),
          TextField(
            controller: _nom,
            autofocus: !_isEdit,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            style: textTheme.bodyLarge,
            onChanged: (_) {
              if (_nomError != null) setState(() => _nomError = null);
            },
            decoration: InputDecoration(
              hintText: 'Ex. Plaquettes de frein avant',
              errorText: _nomError,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          const AppFieldLabel('Description', optional: true),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Ce que comprend cet entretien',
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          AppSearchableSelect<DossierTypeEntretien>(
            label: 'Dossier',
            optional: !_dossierLocked,
            items: widget.dossiers,
            selectedItem: dossier,
            onChanged: (d) => setState(() => _dossierId = d?.id),
            itemLabel: (d) => d.nom,
            itemIcon: (_) => Icons.folder_rounded,
            placeholder: widget.dossiers.isEmpty
                ? 'Aucun dossier créé'
                : 'Aucun dossier (non classé)',
            sheetTitle: 'Dossier',
            enabled: widget.dossiers.isNotEmpty,
            clearable: !_dossierLocked,
          ),
          if (_dossierLocked)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: AppSpacing.xs),
              child: Text(
                'Un type rangé peut changer de dossier, mais pas redevenir '
                'non classé.',
                style: textTheme.bodySmall,
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.base),
            AppAlert(variant: AlertVariant.destructive, description: _error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: _isEdit ? 'Enregistrer le type' : 'Créer le type',
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
                label: const Text('Supprimer le type'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Création / modification d'un dossier. Retourne `true` si le dossier a
/// été enregistré ou supprimé.
abstract final class DossierFormSheet {
  static Future<bool> show(
    BuildContext context, {
    DossierTypeEntretien? dossier,
    int typeCount = 0,
  }) async {
    final changed = await AppSheet.show<bool>(
      context,
      title: dossier == null ? 'Nouveau dossier' : 'Modifier le dossier',
      builder: (_) => _DossierForm(dossier: dossier, typeCount: typeCount),
    );
    return changed ?? false;
  }
}

class _DossierForm extends StatefulWidget {
  const _DossierForm({required this.dossier, required this.typeCount});

  final DossierTypeEntretien? dossier;

  /// Types rangés dans ce dossier (un dossier non vide ne se supprime pas).
  final int typeCount;

  @override
  State<_DossierForm> createState() => _DossierFormState();
}

class _DossierFormState extends State<_DossierForm> {
  late final _nom = TextEditingController(text: widget.dossier?.nom);
  late final _description =
      TextEditingController(text: widget.dossier?.description);
  bool _saving = false;
  bool _deleting = false;
  String? _nomError;
  String? _error;

  bool get _isEdit => widget.dossier != null;

  @override
  void dispose() {
    _nom.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nom = _nom.text.trim();
    setState(() {
      _nomError = nom.isEmpty ? 'Donne un nom au dossier.' : null;
      _error = null;
    });
    if (_nomError != null) {
      HapticFeedback.vibrate();
      return;
    }
    setState(() => _saving = true);
    final description = _description.text.trim();
    final request = DossierTypeEntretienRequest(
      nom: nom,
      description: _isEdit || description.isNotEmpty ? description : null,
    );
    final result = _isEdit
        ? await sl.entretienRepository.updateDossier(widget.dossier!.id, request)
        : await sl.entretienRepository.createDossier(request);
    if (!mounted) return;
    result.fold(
      (f) {
        HapticFeedback.heavyImpact();
        setState(() {
          _saving = false;
          _error = f.message;
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
      title: 'Supprimer ce dossier ?',
      message: '« ${widget.dossier!.nom} » est vide : il sera supprimé '
          'définitivement.',
      confirmLabel: 'Supprimer le dossier',
      confirmIcon: Icons.delete_rounded,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    final result =
        await sl.entretienRepository.deleteDossier(widget.dossier!.id);
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _deleting = false;
        _error = friendlyDeleteError(
          f,
          'Ce dossier contient encore des types : range-les ailleurs '
          'avant de le supprimer.',
        );
      }),
      (_) => Navigator.of(context).pop(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final busy = _saving || _deleting;

    return AbsorbPointer(
      absorbing: busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppFieldLabel('Nom'),
          TextField(
            controller: _nom,
            autofocus: !_isEdit,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            style: textTheme.bodyLarge,
            onChanged: (_) {
              if (_nomError != null) setState(() => _nomError = null);
            },
            decoration: InputDecoration(
              hintText: 'Ex. Freinage',
              errorText: _nomError,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          const AppFieldLabel('Description', optional: true),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Ex. Tout ce qui touche au système de freinage',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.base),
            AppAlert(variant: AlertVariant.destructive, description: _error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: _isEdit ? 'Enregistrer le dossier' : 'Créer le dossier',
            icon: Icons.check_rounded,
            size: ButtonSize.lg,
            isLoading: _saving,
            onPressed: busy ? null : _save,
          ),
          if (_isEdit) ...[
            const SizedBox(height: AppSpacing.sm),
            if (widget.typeCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.xs,
                ),
                child: Text(
                  'Pour supprimer ce dossier, range d\'abord ses '
                  '${DisplayFormat.plural(widget.typeCount, 'type')} dans un '
                  'autre dossier.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
              )
            else
              SizedBox(
                height: 52,
                child: TextButton.icon(
                  onPressed: busy ? null : _delete,
                  style:
                      TextButton.styleFrom(foregroundColor: colors.destructive),
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
                  label: const Text('Supprimer le dossier'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

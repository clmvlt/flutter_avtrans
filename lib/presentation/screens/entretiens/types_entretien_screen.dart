import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/entretien_model.dart';
import '../../widgets/widgets.dart';
import 'logic/entretien_catalog.dart';
import 'widgets/fleet_widgets.dart';
import 'widgets/type_forms.dart';

/// Filtre « tous » et « non classés » des puces de dossiers.
const String _all = '__all__';
const String _unclassified = '__none__';

/// Types d'entretien, rangés par dossier (Administrateur et Mécanicien).
///
/// Puces de dossiers pour filtrer, recherche, liste des types ; un tap ouvre
/// la modification. « Ajouter un type » dans le dock, « Nouveau dossier »
/// dans la barre de titre.
class TypesEntretienScreen extends StatefulWidget {
  const TypesEntretienScreen({super.key});

  @override
  State<TypesEntretienScreen> createState() => _TypesEntretienScreenState();
}

class _TypesEntretienScreenState extends State<TypesEntretienScreen>
    with DockNoticeMixin {
  bool _loading = true;
  String? _error;
  EntretienCatalog? _catalog;

  String _scope = _all;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = _catalog == null;
      _error = null;
    });
    final result = await EntretienCatalog.load(force: force);
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold((f) => _error = f.message, (c) {
        _catalog = c;
        // Le dossier affiché a pu être supprimé.
        if (_scope != _all &&
            _scope != _unclassified &&
            !c.dossiers.any((d) => d.id == _scope)) {
          _scope = _all;
        }
      });
    });
  }

  Future<void> _afterChange(bool changed) async {
    if (!changed || !mounted) return;
    EntretienCatalog.invalidate();
    await _load(force: true);
  }

  DossierTypeEntretien? get _selectedDossier =>
      _catalog?.dossiers.where((d) => d.id == _scope).firstOrNull;

  Future<void> _createType() async {
    final c = _catalog;
    if (c == null) return;
    final changed = await TypeEntretienFormSheet.show(
      context,
      dossiers: c.dossiers,
      initialDossierId: _selectedDossier?.id,
    );
    await _afterChange(changed);
  }

  Future<void> _editType(TypeEntretien t) async {
    final changed = await TypeEntretienFormSheet.show(
      context,
      type: t,
      dossiers: _catalog?.dossiers ?? const [],
    );
    await _afterChange(changed);
  }

  Future<void> _createDossier() async {
    final changed = await DossierFormSheet.show(context);
    await _afterChange(changed);
  }

  Future<void> _editDossier(DossierTypeEntretien d) async {
    final changed = await DossierFormSheet.show(
      context,
      dossier: d,
      typeCount: _catalog?.countIn(d.id) ?? 0,
    );
    await _afterChange(changed);
  }

  List<TypeEntretien> _visibleTypes(EntretienCatalog c) {
    Iterable<TypeEntretien> list = switch (_scope) {
      _all => c.types,
      _unclassified => c.typesIn(null),
      _ => c.typesIn(_scope),
    };
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((t) =>
          t.nom.toLowerCase().contains(q) ||
          (t.description?.toLowerCase().contains(q) ?? false));
    }
    return list.toList();
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPage(
      title: 'Types d\'entretien',
      actions: [
        AppIconButton(
          icon: Icons.create_new_folder_rounded,
          tooltip: 'Nouveau dossier',
          color: colors.foreground,
          onPressed: _catalog == null ? null : _createDossier,
        ),
      ],
      body: _buildBody(),
      dock: AppDock(
        actions: [
          DockAction(
            label: 'Ajouter un type',
            icon: Icons.add_rounded,
            onPressed: _catalog == null ? null : _createType,
          ),
        ],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppScrollView(children: [AppListSkeleton(rows: 6)]);
    }
    final c = _catalog;
    if (c == null) {
      return AppScrollView(
        onRefresh: () => _load(force: true),
        children: [
          AppErrorState(
            message: _error ?? 'Erreur inconnue',
            onRetry: () => _load(force: true),
          ),
        ],
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final types = _visibleTypes(c);
    final dossier = _selectedDossier;
    final unclassifiedCount = c.countIn(null);
    final scopeLabel = switch (_scope) {
      _all => 'Tous les types',
      _unclassified => 'Non classés',
      _ => dossier?.nom ?? '',
    };

    return AppScrollView(
      onRefresh: () => _load(force: true),
      children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          style: textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Rechercher un type',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Les puces débordent la colonne pour défiler jusqu'au bord.
        AppFilterChips<String>(
          segments: [
            AppSegment(value: _all, label: 'Tous', count: c.types.length),
            for (final d in c.dossiers)
              AppSegment(
                value: d.id,
                label: d.nom,
                icon: Icons.folder_rounded,
                count: c.countIn(d.id),
              ),
            if (unclassifiedCount > 0 || c.dossiers.isNotEmpty)
              AppSegment(
                value: _unclassified,
                label: 'Non classés',
                icon: Icons.folder_open_rounded,
                count: unclassifiedCount,
              ),
          ],
          selected: _scope,
          onChanged: (v) => setState(() => _scope = v),
        ),
        if (dossier != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: AppListRow(
              title: dossier.nom,
              subtitle: dossier.description ?? 'Dossier',
              icon: Icons.folder_rounded,
              iconColor: colors.warning,
              trailing: Text(
                'Modifier',
                style: textTheme.labelLarge?.copyWith(color: colors.primary),
              ),
              onTap: () => _editDossier(dossier),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: scopeLabel,
          summary: DisplayFormat.plural(types.length, 'type'),
        ),
        if (types.isEmpty)
          AppEmptyCard(
            icon: Icons.build_outlined,
            message: _query.isNotEmpty
                ? 'Aucun type ne correspond à « ${_query.trim()} »'
                : c.types.isEmpty
                    ? 'Aucun type d\'entretien'
                    : _scope == _unclassified
                        ? 'Aucun type non classé'
                        : 'Ce dossier est vide',
            detail: c.types.isEmpty
                ? 'Crée les entretiens que l\'atelier réalise : vidange, '
                    'pneus, freins…'
                : null,
          )
        else
          DividedCard(
            children: [
              for (final t in types)
                AppListRow(
                  key: ValueKey(t.id),
                  title: t.nom,
                  subtitle: _scope == _all
                      ? [
                          t.dossier?.nom ?? 'Non classé',
                          if (t.description != null) t.description!,
                        ].join(' · ')
                      : t.description,
                  icon: Icons.build_rounded,
                  iconColor: colors.domainVehicule,
                  onTap: () => _editType(t),
                ),
            ],
          ),
      ],
    );
  }
}

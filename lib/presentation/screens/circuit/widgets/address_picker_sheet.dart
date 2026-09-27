import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/address_suggestion.dart';
import '../../../widgets/app_list_row.dart';
import '../../../widgets/app_state_views.dart';
import '../../../widgets/app_text_field.dart';
import 'tour_widgets.dart';

/// Feuille de recherche / sélection d'adresse via l'autocomplétion ORS.
///
/// Sert à deux usages :
/// - **saisie manuelle** : champ vide, l'utilisateur tape et choisit ;
/// - **confirmation après scan** : [initialQuery] pré-rempli par l'OCR, la
///   recherche se lance automatiquement et l'utilisateur confirme ou ajuste.
///
/// Renvoie l'[AddressSuggestion] choisie via `Navigator.pop`, ou `null` si
/// l'utilisateur ferme la feuille.
class AddressPickerSheet extends StatefulWidget {
  const AddressPickerSheet({
    super.key,
    this.initialQuery = '',
    this.fromScan = false,
  });

  final String initialQuery;

  /// Indique que [initialQuery] provient d'un scan (affiche une ligne d'aide).
  final bool fromScan;

  /// Affiche la feuille et renvoie l'adresse sélectionnée, ou `null`.
  static Future<AddressSuggestion?> show(
    BuildContext context, {
    String initialQuery = '',
    bool fromScan = false,
  }) {
    return showModalBottomSheet<AddressSuggestion>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surfaceElevated,
      // La poignée est dessinée par la feuille (sinon elle serait doublée par
      // celle du thème).
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => AddressPickerSheet(
        initialQuery: initialQuery,
        fromScan: fromScan,
      ),
    );
  }

  @override
  State<AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<AddressPickerSheet> {
  static const int _minChars = 3;

  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery);
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  int _requestId = 0;

  bool _loading = false;
  String? _error;
  List<AddressSuggestion> _results = const [];

  // Position de l'utilisateur, pour pondérer la pertinence par la proximité.
  double? _originLat;
  double? _originLon;

  @override
  void initState() {
    super.initState();
    _resolveOrigin();
    if (widget.initialQuery.trim().length >= _minChars) {
      _search(widget.initialQuery);
    } else {
      // Ouvre le clavier pour une saisie immédiate.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  /// Récupère la position de l'utilisateur (sans bloquer la saisie) puis
  /// reclasse les résultats déjà affichés en tenant compte de la distance.
  Future<void> _resolveOrigin() async {
    var position = await sl.locationService.getLastKnownPosition();
    position ??= await sl.locationService.getCurrentPosition();
    if (!mounted || position == null) return;
    final lat = position.latitude;
    final lon = position.longitude;
    setState(() {
      _originLat = lat;
      _originLon = lon;
    });
    final query = _controller.text.trim();
    if (query.length >= _minChars) _search(query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < _minChars) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await sl.geocodingRepository.search(
      query,
      limit: 50,
      originLat: _originLat,
      originLon: _originLon,
    );

    // Ignore les réponses obsolètes (une frappe plus récente a eu lieu).
    if (!mounted || requestId != _requestId) return;

    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
        _results = const [];
      }),
      (suggestions) => setState(() {
        _loading = false;
        _error = null;
        _results = suggestions;
      }),
    );
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
    setState(() {});
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    // Espace disponible au-dessus du clavier : sert de hauteur stable.
    final available =
        media.size.height - media.viewInsets.bottom - media.padding.top;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          // Hauteur fixe : la feuille ne se redimensionne plus selon l'état
          // (squelette / message / liste) — uniquement à l'ouverture du clavier.
          height: available * 0.9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.sm,
                  AppSpacing.screen,
                  AppSpacing.sm,
                ),
                child: Text(
                  widget.fromScan
                      ? 'Confirmer l\'adresse'
                      : 'Ajouter une adresse',
                  style: textTheme.titleLarge,
                ),
              ),
              if (widget.fromScan)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    0,
                    AppSpacing.screen,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Adresse détectée : vérifie et choisis la bonne '
                          'proposition.',
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.xs,
                  AppSpacing.screen,
                  AppSpacing.md,
                ),
                child: AppTextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  hint: 'Ex. 12 rue du Bocage, Rennes',
                  keyboardType: TextInputType.streetAddress,
                  textInputAction: TextInputAction.search,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Effacer',
                          onPressed: _clear,
                        ),
                  onChanged: (v) {
                    _onChanged(v);
                    setState(() {}); // rafraîchit le bouton « effacer »
                  },
                  onSubmitted: (v) => _search(v),
                ),
              ),
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final query = _controller.text.trim();

    // États sans résultat : en tête de zone, à hauteur de feuille constante.
    if (_results.isEmpty) {
      final Widget state;
      if (_loading) {
        state = const AppListSkeleton(rows: 5);
      } else if (_error != null) {
        state = AppErrorState(
          title: 'Recherche impossible',
          message: _error!,
          onRetry: () => _search(_controller.text),
        );
      } else if (query.length < _minChars) {
        state = const AppEmptyCard(
          icon: Icons.edit_location_alt_outlined,
          message: 'Tape une rue, une ville ou un code postal',
        );
      } else {
        state = const AppEmptyCard(
          icon: Icons.location_off_outlined,
          message: 'Aucune adresse trouvée',
          detail: 'Vérifie l\'orthographe ou précise la commune.',
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.lg,
        ),
        child: state,
      );
    }

    // Résultats présents : liste stable + fine barre pendant un rechargement
    // (on garde les résultats affichés au lieu de tout remplacer).
    return Column(
      children: [
        SizedBox(
          height: 2,
          child:
              _loading ? const LinearProgressIndicator(minHeight: 2) : null,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.sm,
              AppSpacing.screen,
              AppSpacing.lg,
            ),
            children: [
              RowsCard(
                children: [
                  for (final suggestion in _results)
                    _SuggestionRow(
                      suggestion: suggestion,
                      onTap: () => Navigator.of(context).pop(suggestion),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Une proposition d'adresse : niveau (« Rue » pour une voie agrégée) et
/// distance en sous-ligne.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion, required this.onTap});

  final AddressSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final meta = <String>[
      if (suggestion.isStreet) 'Rue',
      if (suggestion.distanceLabel != null) 'à ${suggestion.distanceLabel}',
    ];

    return AppListRow(
      icon: suggestion.isStreet
          ? Icons.signpost_outlined
          : Icons.location_on_outlined,
      iconColor: colors.primary,
      title: suggestion.label,
      subtitle: meta.isEmpty ? null : meta.join(' · '),
      trailing: Icon(
        Icons.add_circle_outline_rounded,
        size: 22,
        color: colors.mutedForeground,
      ),
      showChevron: false,
      onTap: onTap,
    );
  }
}

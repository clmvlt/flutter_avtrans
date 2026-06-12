import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/address_suggestion.dart';
import '../../../widgets/app_text_field.dart';

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

  /// Indique que [initialQuery] provient d'un scan (affiche un bandeau d'aide).
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Container(
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
                  AppSpacing.base,
                  AppSpacing.screen,
                  AppSpacing.sm,
                ),
                child: Text(
                  widget.fromScan ? 'Confirmer l\'adresse' : 'Ajouter une adresse',
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
                  child: _ScanHint(colors: colors, textTheme: textTheme),
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
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                            setState(() {});
                            _focusNode.requestFocus();
                          },
                        ),
                  onChanged: (v) {
                    _onChanged(v);
                    setState(() {}); // rafraîchit le bouton « effacer »
                  },
                  onSubmitted: (v) => _search(v),
                ),
              ),
              Flexible(child: _buildResults(colors, textTheme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(AppColors colors, TextTheme textTheme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: _error!,
        actionLabel: 'Réessayer',
        onAction: () => _search(_controller.text),
        colors: colors,
        textTheme: textTheme,
      );
    }

    final query = _controller.text.trim();
    if (query.length < _minChars) {
      return _Message(
        icon: Icons.edit_location_alt_outlined,
        title: 'Tape une rue, une ville ou un code postal',
        colors: colors,
        textTheme: textTheme,
      );
    }

    if (_results.isEmpty) {
      return _Message(
        icon: Icons.location_off_outlined,
        title: 'Aucune adresse trouvée',
        subtitle: 'Précise la rue ou la ville.',
        colors: colors,
        textTheme: textTheme,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        AppSpacing.lg,
      ),
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: colors.border),
      itemBuilder: (context, index) {
        final suggestion = _results[index];
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Navigator.of(context).pop(suggestion),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 20, color: colors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.label,
                        style: textTheme.bodyLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (suggestion.distanceLabel != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.near_me_outlined,
                                size: 13, color: colors.mutedForeground),
                            const SizedBox(width: 4),
                            Text(
                              suggestion.distanceLabel!,
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.add_circle_outline_rounded,
                    size: 22, color: colors.mutedForeground),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScanHint extends StatelessWidget {
  const _ScanHint({required this.colors, required this.textTheme});
  final AppColors colors;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Adresse détectée — vérifie et choisis la bonne proposition.',
              style: textTheme.bodySmall?.copyWith(color: colors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    required this.colors,
    required this.textTheme,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AppColors colors;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: colors.mutedForeground),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: textTheme.titleSmall, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!,
                style: textTheme.bodySmall, textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_format.dart';
import '../../../data/models/ypsium_models.dart';
import '../../widgets/widgets.dart';
import 'widgets/ypsium_dock_lines.dart';
import 'widgets/ypsium_order_visual.dart';
import 'widgets/ypsium_vehicule_sheet.dart';

/// Choix du véhicule Ypsium : touche un véhicule, saisis son kilométrage et
/// son état dans une feuille ; le hero confirme le véhicule enregistré.
class YpsiumVehiculeScreen extends StatefulWidget {
  const YpsiumVehiculeScreen({super.key});

  @override
  State<YpsiumVehiculeScreen> createState() => _YpsiumVehiculeScreenState();
}

class _YpsiumVehiculeScreenState extends State<YpsiumVehiculeScreen>
    with DockNoticeMixin {
  List<YpsiumVehicule> _vehicules = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  /// Échec du chargement de la liste (les échecs d'enregistrement passent
  /// par le dock).
  String? _errorMessage;
  String? _successMessage;
  int? _selectedVehiculeId;

  @override
  void initState() {
    super.initState();
    _loadVehicules();
  }

  Future<void> _loadVehicules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await sl.ypsiumVehiculeRepository.getListeVehicules();

    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _errorMessage = failure.message;
        _isLoading = false;
      }),
      (vehicules) => setState(() {
        _vehicules = vehicules;
        _isLoading = false;
      }),
    );
  }

  Future<void> _selectVehicule(YpsiumVehicule vehicule) async {
    setState(() => _selectedVehiculeId = vehicule.idVehicule);
    final choice = await YpsiumVehiculeSheet.show(context, vehicule);
    if (!mounted) return;
    if (choice == null) {
      // Annulée ou fermée : rien n'est sélectionné.
      setState(() => _selectedVehiculeId = null);
      return;
    }
    _confirmVehicule(
      vehicule,
      choice.kilometrage,
      choice.noteEtat,
      choice.commentaire,
    );
  }

  Future<void> _confirmVehicule(
    YpsiumVehicule vehicule,
    int km,
    int note,
    String comment,
  ) async {
    clearDockNotice();
    setState(() {
      _isSubmitting = true;
      _successMessage = null;
    });

    final session = sl.ypsiumAuthRepository.currentSession!;
    final result = await sl.ypsiumVehiculeRepository.setChoixVehicule(
      YpsiumChoixVehiculeRequest(
        idChauffeur: session.idChauffeur,
        idVehicule: vehicule.idVehicule,
        kilometrage: km,
        noteEtat: note,
        commentaire: comment,
      ),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) {
        setState(() => _selectedVehiculeId = null);
        showDockError(failure.message);
      },
      (_) => setState(() {
        _successMessage =
            'Véhicule ${vehicule.immatriculation} sélectionné';
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Choix du véhicule',
      body: AbsorbPointer(
        absorbing: _isSubmitting,
        child: AppScrollView(
          onRefresh: _loadVehicules,
          children: _buildContent(),
        ),
      ),
      dock: AppDock(
        status: _isSubmitting
            ? const YpsiumBusyLine(text: 'Enregistrement du véhicule…')
            : null,
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
        bottomGap: AppSpacing.lg,
      ),
    );
  }

  List<Widget> _buildContent() {
    final colors = context.colors;

    if (_isLoading) {
      return const [
        AppHeroSkeleton(showFigure: false),
        SizedBox(height: AppSpacing.lg),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppSkeleton(width: 160, height: 16),
          ),
        ),
        SizedBox(height: AppSpacing.md),
        AppListSkeleton(rows: 4),
      ];
    }

    if (_errorMessage != null) {
      return [AppErrorState(message: _errorMessage!, onRetry: _loadVehicules)];
    }

    return [
      if (_successMessage != null)
        AppHeroCard(
          icon: Icons.check_circle_rounded,
          accent: colors.success,
          title: 'Véhicule enregistré',
          subtitle: _successMessage,
        )
      else
        AppHeroCard(
          icon: Icons.directions_car_rounded,
          accent: colors.domainVehicule,
          title: 'Choisis ton véhicule',
          subtitle: 'Touche un véhicule pour saisir son kilométrage',
        ),
      const SizedBox(height: AppSpacing.lg),
      AppSectionHeader(
        title: 'Véhicules disponibles',
        summary: _vehicules.isEmpty
            ? null
            : DisplayFormat.plural(_vehicules.length, 'véhicule'),
      ),
      if (_vehicules.isEmpty)
        AppEmptyCard(
          icon: Icons.directions_car_outlined,
          message: 'Aucun véhicule disponible',
          actionLabel: 'Réessayer',
          onAction: _loadVehicules,
        )
      else
        YpsiumRowGroup(
          children: [for (final v in _vehicules) _buildVehiculeRow(v, colors)],
        ),
    ];
  }

  Widget _buildVehiculeRow(YpsiumVehicule vehicule, AppColors colors) {
    final isSelected = _selectedVehiculeId == vehicule.idVehicule;

    Widget? trailing;
    if (isSelected && _isSubmitting) {
      trailing = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
      );
    } else if (isSelected) {
      trailing = Icon(Icons.check_circle_rounded, size: 22, color: colors.primary);
    }

    return AppListRow(
      icon: Icons.directions_car_rounded,
      iconColor: isSelected ? colors.primary : colors.domainVehicule,
      title: vehicule.immatriculation,
      subtitle: DisplayFormat.km(vehicule.kilometrage),
      trailing: trailing,
      showChevron: !isSelected,
      onTap: () => _selectVehicule(vehicule),
      semanticsLabel: '${vehicule.immatriculation}, '
          '${DisplayFormat.km(vehicule.kilometrage)}'
          '${isSelected ? ', sélectionné' : ''}',
    );
  }
}

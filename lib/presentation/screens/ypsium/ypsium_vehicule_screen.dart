import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ypsium_models.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/loading_overlay.dart';

/// Écran de sélection de véhicule Ypsium
class YpsiumVehiculeScreen extends StatefulWidget {
  const YpsiumVehiculeScreen({super.key});

  @override
  State<YpsiumVehiculeScreen> createState() => _YpsiumVehiculeScreenState();
}

class _YpsiumVehiculeScreenState extends State<YpsiumVehiculeScreen> {
  List<YpsiumVehicule> _vehicules = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
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

  void _selectVehicule(YpsiumVehicule vehicule) {
    setState(() => _selectedVehiculeId = vehicule.idVehicule);
    _showConfirmDialog(vehicule);
  }

  void _showConfirmDialog(YpsiumVehicule vehicule) {
    final colors = context.colors;
    final kmController = TextEditingController(
      text: vehicule.kilometrage.toString(),
    );
    final commentController = TextEditingController();
    int noteEtat = 3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Text(
            vehicule.immatriculation,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: kmController,
                  label: 'Kilométrage',
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.speed, size: 18),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  'État du véhicule',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final note = index + 1;
                    final isSelected = note <= noteEtat;
                    return GestureDetector(
                      onTap: () => setDialogState(() => noteEtat = note),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          isSelected ? Icons.star : Icons.star_border,
                          color: isSelected ? colors.warning : colors.mutedForeground,
                          size: 28,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.base),
                AppTextField(
                  controller: commentController,
                  label: 'Commentaire',
                  hint: 'Optionnel',
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _selectedVehiculeId = null);
              },
              child: Text(
                'Annuler',
                style: TextStyle(color: colors.mutedForeground),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _confirmVehicule(
                  vehicule,
                  int.tryParse(kmController.text) ?? 0,
                  noteEtat,
                  commentController.text,
                );
              },
              child: Text(
                'Confirmer',
                style: TextStyle(color: colors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmVehicule(
    YpsiumVehicule vehicule,
    int km,
    int note,
    String comment,
  ) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
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
      (failure) => setState(() {
        _errorMessage = failure.message;
        _selectedVehiculeId = null;
      }),
      (_) => setState(() {
        _successMessage =
            'Véhicule ${vehicule.immatriculation} sélectionné';
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.foreground, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Véhicules',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
            color: colors.foreground,
          ),
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isSubmitting,
        message: 'Enregistrement...',
        child: RefreshIndicator(
          onRefresh: _loadVehicules,
          color: colors.primary,
          backgroundColor: colors.card,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_successMessage != null) ...[
                  AppAlert(description: _successMessage!),
                  const SizedBox(height: AppSpacing.base),
                ],
                if (_errorMessage != null) ...[
                  AppAlert(
                    description: _errorMessage!,
                    variant: AlertVariant.destructive,
                  ),
                  const SizedBox(height: AppSpacing.base),
                ],

                Text(
                  'Sélectionnez votre véhicule',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.mutedForeground,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                if (_isLoading)
                  ...List.generate(
                    4,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppSkeleton(
                        height: 80,
                        borderRadius: AppRadius.lg,
                      ),
                    ),
                  )
                else if (_vehicules.isEmpty)
                  _buildEmpty(colors)
                else
                  ..._vehicules.map((v) => _buildVehiculeCard(v, colors)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehiculeCard(YpsiumVehicule vehicule, AppColors colors) {
    final isSelected = _selectedVehiculeId == vehicule.idVehicule;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: () => _selectVehicule(vehicule),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isSelected ? colors.primary : colors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.chart4.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    size: 22,
                    color: colors.chart4,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicule.immatriculation,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatKm(vehicule.kilometrage)} km',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, size: 22, color: colors.primary)
                else
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colors.mutedForeground,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.directions_car_outlined, size: 40, color: colors.mutedForeground),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Aucun véhicule disponible',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          AppButton(
            text: 'Réessayer',
            variant: ButtonVariant.outline,
            onPressed: _loadVehicules,
            fullWidth: false,
          ),
        ],
      ),
    );
  }

  String _formatKm(int km) {
    if (km >= 1000) {
      final str = km.toString();
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buffer.write(' ');
        buffer.write(str[i]);
      }
      return buffer.toString();
    }
    return km.toString();
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';
import 'add_kilometrage_dialog.dart';
import 'add_adjust_info_screen.dart';
import 'upload_vehicule_file_dialog.dart';

/// Écran de détails d'un véhicule
class VehiculeDetailsScreen extends StatefulWidget {
  final String vehiculeId;

  const VehiculeDetailsScreen({
    super.key,
    required this.vehiculeId,
  });

  @override
  State<VehiculeDetailsScreen> createState() => _VehiculeDetailsScreenState();
}

class _VehiculeDetailsScreenState extends State<VehiculeDetailsScreen>
    with SingleTickerProviderStateMixin {
  Vehicule? _vehicule;
  List<VehiculeFile> _files = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      sl.vehiculeRepository.getVehiculeById(widget.vehiculeId),
      sl.vehiculeRepository.getVehiculeFiles(widget.vehiculeId),
    ]);

    if (!mounted) return;

    // Vehicule
    results[0].fold(
      (failure) => _showError(failure.message),
      (vehicule) => _vehicule = vehicule as Vehicule,
    );

    // Files
    results[1].fold(
      (failure) {},
      (files) => _files = files as List<VehiculeFile>,
    );

    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.destructive, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.card,
      ),
    );
  }

  void _showSuccess(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: colors.success, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.card,
      ),
    );
  }

  Future<void> _showAddKilometrageDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AddKilometrageDialog(vehiculeId: widget.vehiculeId),
    );

    if (result == true) {
      _showSuccess('Kilométrage ajouté avec succès');
      _loadData();
    }
  }

  Future<void> _openAddAdjustInfoScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddAdjustInfoScreen(
          vehiculeId: widget.vehiculeId,
          vehiculeImmat: _vehicule?.immat,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      _showSuccess('Information d\'ajustement créée avec succès');
      _loadData();
    }
  }

  Future<void> _showUploadFileDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => UploadVehiculeFileDialog(vehiculeId: widget.vehiculeId),
    );

    if (result == true) {
      _showSuccess('Fichier ajouté avec succès');
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: const Text('Détails du véhicule'),
        ),
        body: const LoadingIndicator(message: 'Chargement...'),
      );
    }

    if (_vehicule == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: const Text('Détails du véhicule'),
        ),
        body: Center(
          child: Text(
            'Véhicule non trouvé',
            style: TextStyle(color: colors.mutedForeground),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_vehicule!.immat),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Infos'),
            Tab(text: 'Fichiers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(colors),
          _buildFilesTab(colors),
        ],
      ),
    );
  }

  Widget _buildInfoTab(AppColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  'Immatriculation',
                  _vehicule!.immat,
                  Icons.confirmation_number,
                  colors,
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  'Marque',
                  _vehicule!.brand,
                  Icons.business,
                  colors,
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  'Modèle',
                  _vehicule!.model,
                  Icons.directions_car,
                  colors,
                ),
                if (_vehicule!.latestKm != null) ...[
                  const Divider(height: 24),
                  _buildInfoRow(
                    'Dernier kilométrage',
                    '${_vehicule!.latestKm} km',
                    Icons.speed,
                    colors,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          AppButton(
            text: 'Mettre à jour le kilométrage',
            icon: Icons.speed,
            onPressed: _showAddKilometrageDialog,
            backgroundColor: colors.primary,
            foregroundColor: colors.primaryForeground,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            text: 'Ajouter des informations',
            icon: Icons.info_outline,
            onPressed: _openAddAdjustInfoScreen,
            backgroundColor: colors.primary,
            foregroundColor: colors.primaryForeground,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    AppColors colors,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilesTab(AppColors colors) {
    return Column(
      children: [
        // Bouton d'upload
        Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: AppButton(
            text: 'Ajouter un fichier',
            icon: Icons.upload_file,
            onPressed: _showUploadFileDialog,
            backgroundColor: colors.primary,
            foregroundColor: colors.primaryForeground,
          ),
        ),
        // Liste des fichiers
        Expanded(
          child: _files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: colors.mutedForeground),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Aucun fichier',
                        style: TextStyle(color: colors.mutedForeground),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    return _buildFileCard(file, colors);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFileCard(VehiculeFile file, AppColors colors) {
    final date = '${file.createdAt.day.toString().padLeft(2, '0')}/'
        '${file.createdAt.month.toString().padLeft(2, '0')}/'
        '${file.createdAt.year}';

    return GestureDetector(
      onTap: () => _openFile(file),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadius.base),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.base),
                ),
                child: file.isImage
                    ? Image.network(
                        file.fileUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: colors.primary,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _buildFileIcon(file, colors);
                        },
                      )
                    : _buildFileIcon(file, colors),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.base),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.originalName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 10,
                        color: colors.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.mutedForeground,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        file.formattedSize,
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(VehiculeFile file, AppColors colors) {
    IconData icon;
    Color iconColor;
    Color bgColor;
    String extensionLabel = file.extension.toUpperCase();

    if (file.isPdf) {
      icon = Icons.picture_as_pdf;
      iconColor = Colors.red.shade700;
      bgColor = Colors.red.shade50;
    } else if (file.isImage) {
      icon = Icons.image;
      iconColor = colors.primary;
      bgColor = colors.primary.withValues(alpha: 0.1);
    } else if (file.mimeType.contains('word') || file.extension == 'doc' || file.extension == 'docx') {
      icon = Icons.description;
      iconColor = Colors.blue.shade700;
      bgColor = Colors.blue.shade50;
    } else if (file.mimeType.contains('excel') || file.extension == 'xls' || file.extension == 'xlsx') {
      icon = Icons.table_chart;
      iconColor = Colors.green.shade700;
      bgColor = Colors.green.shade50;
    } else {
      icon = Icons.insert_drive_file;
      iconColor = colors.mutedForeground;
      bgColor = colors.muted;
    }

    return Container(
      color: bgColor,
      child: Stack(
        children: [
          // Icône centrale
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 40, color: iconColor),
                ),
                const SizedBox(height: 8),
                // Badge d'extension
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    extensionLabel.isEmpty ? 'FILE' : extensionLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Coin plié (effet document)
          if (file.isPdf || file.mimeType.contains('word'))
            Positioned(
              top: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(24, 24),
                painter: _FoldedCornerPainter(iconColor.withValues(alpha: 0.3)),
              ),
            ),
        ],
      ),
    );
  }

  void _openFile(VehiculeFile file) {
    if (file.isImage) {
      _showImageFullScreen(file.fileUrl);
    } else {
      // Pour les PDFs et autres fichiers, ouvrir l'URL externe
      _openExternalUrl(file.fileUrl);
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showError('Impossible d\'ouvrir le fichier');
    }
  }

  void _showImageFullScreen(String imageUrl) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: colors.primary,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64,
                            color: colors.mutedForeground,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Impossible de charger l\'image',
                            style: TextStyle(color: colors.mutedForeground),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter pour dessiner un coin plié (effet document)
class _FoldedCornerPainter extends CustomPainter {
  final Color color;

  _FoldedCornerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

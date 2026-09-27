import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';
import '../entretiens/vehicule_entretiens_screen.dart';
import 'add_adjust_info_screen.dart';
import 'add_kilometrage_dialog.dart';
import 'upload_vehicule_file_dialog.dart';
import 'widgets/vehicule_details_skeleton.dart';
import 'widgets/vehicule_files_tab.dart';
import 'widgets/vehicule_hero_card.dart';
import 'widgets/vehicule_image_viewer.dart';
import 'widgets/vehicule_info_tab.dart';
import 'widgets/vehicule_photo.dart';

enum _DetailsTab { infos, files }

/// Fiche d'un véhicule : hero (immatriculation, dernier kilométrage), puis
/// « Infos / Fichiers ». Le dock porte l'action de l'onglet : mettre à jour
/// le kilométrage, ou ajouter un fichier.
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
    with DockNoticeMixin {
  Vehicule? _vehicule;
  List<VehiculeFile> _files = const [];
  bool _filesLoaded = false;
  bool _isLoading = true;
  String? _error;
  String? _filesError;
  _DetailsTab _tab = _DetailsTab.infos;

  /// L'atelier (entretiens, photo du véhicule) est réservé à
  /// l'Administrateur et au Mécanicien, comme dans l'API.
  late final bool _canManageFleet =
      sl.authRepository.getCachedUser()?.canManageFleet == true;

  /// Envoi de la photo en cours.
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Charge la fiche et ses fichiers en parallèle. Au rechargement, le
  /// contenu reste affiché ; un échec passe alors par le dock.
  Future<void> _loadData() async {
    final vehiculeFuture =
        sl.vehiculeRepository.getVehiculeById(widget.vehiculeId);
    final filesFuture =
        sl.vehiculeRepository.getVehiculeFiles(widget.vehiculeId);
    final vehiculeResult = await vehiculeFuture;
    final filesResult = await filesFuture;

    if (!mounted) return;

    String? refreshError;
    setState(() {
      vehiculeResult.fold(
        (failure) {
          if (_vehicule == null) {
            _error = failure.message;
          } else {
            refreshError = failure.message;
          }
        },
        (vehicule) {
          _vehicule = vehicule;
          _error = null;
        },
      );
      filesResult.fold(
        (failure) {
          if (!_filesLoaded) _filesError = failure.message;
        },
        (files) {
          _files = files;
          _filesLoaded = true;
          _filesError = null;
        },
      );
      _isLoading = false;
    });
    if (refreshError != null) showDockError(refreshError!);
  }

  Future<void> _retry() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _loadData();
  }

  // ---- actions ----------------------------------------------------------

  Future<void> _addKilometrage() async {
    final vehicule = _vehicule;
    if (vehicule == null) return;
    clearDockNotice();
    final saved = await AddKilometrageSheet.show(
      context,
      vehiculeId: widget.vehiculeId,
      latestKm: vehicule.latestKm,
      latestKmDate: vehicule.latestKmDate,
    );
    if (!saved || !mounted) return;
    // Le hero affiche le nouveau relevé : pas de message.
    await _loadData();
  }

  Future<void> _openAddAdjustInfo() async {
    clearDockNotice();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddAdjustInfoScreen(
          vehiculeId: widget.vehiculeId,
          vehiculeImmat: _vehicule?.immat,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result != true || !mounted) return;
    showDockSuccess('Information envoyée');
    await _loadData();
  }

  Future<void> _uploadFile() async {
    clearDockNotice();
    final uploaded = await UploadVehiculeFileSheet.show(
      context,
      vehiculeId: widget.vehiculeId,
    );
    if (!uploaded || !mounted) return;
    // Le fichier apparaît dans la liste : pas de message.
    await _loadData();
  }

  Future<void> _openEntretiens() async {
    clearDockNotice();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VehiculeEntretiensScreen(vehiculeId: widget.vehiculeId),
      ),
    );
    if (!mounted) return;
    await _loadData();
  }

  void _openPhoto() {
    final vehicule = _vehicule;
    final url = vehicule?.pictureUrl;
    if (vehicule == null || url == null) return;
    VehiculeImageViewer.open(context, imageUrl: url, title: vehicule.immat);
  }

  /// Tap sur la photo : l'agrandir (chauffeur) ou choisir quoi faire
  /// (atelier : agrandir, reprendre une photo, choisir dans la galerie).
  Future<void> _onPhotoTap() async {
    final hasPhoto = _vehicule?.pictureUrl != null;
    if (!_canManageFleet) {
      if (hasPhoto) _openPhoto();
      return;
    }
    clearDockNotice();
    final action = await VehiculePhotoSheet.show(context, hasPhoto: hasPhoto);
    if (action == null || !mounted) return;
    switch (action) {
      case VehiculePhotoAction.view:
        _openPhoto();
      case VehiculePhotoAction.camera:
        await _changePhoto(ImageSource.camera);
      case VehiculePhotoAction.gallery:
        await _changePhoto(ImageSource.gallery);
    }
  }

  Future<void> _changePhoto(ImageSource source) async {
    final XFile? image;
    try {
      image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) {
        showDockError(
          'Impossible d\'ouvrir l\'appareil photo ou la galerie.',
        );
      }
      return;
    }
    if (image == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    final bytes = await image.readAsBytes();
    final name = image.name.toLowerCase();
    final mime = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    final result = await sl.vehiculeRepository.updateVehiculePhoto(
      widget.vehiculeId,
      'data:$mime;base64,${base64Encode(bytes)}',
    );
    if (!mounted) return;

    setState(() => _uploadingPhoto = false);
    result.fold(
      (failure) {
        HapticFeedback.heavyImpact();
        showDockError(failure.message);
      },
      (vehicule) {
        // La nouvelle photo s'affiche : pas de message.
        HapticFeedback.mediumImpact();
        setState(() => _vehicule = vehicule);
      },
    );
  }

  void _openFile(VehiculeFile file) {
    if (file.isImage) {
      VehiculeImageViewer.open(
        context,
        imageUrl: file.fileUrl,
        title: file.originalName,
      );
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
      if (!mounted) return;
      showDockError('Impossible d\'ouvrir le fichier');
    }
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final vehicule = _vehicule;

    return AppPage(
      title: 'Véhicule',
      body: vehicule == null ? _buildPlaceholder() : _buildContent(vehicule),
      dock: AppDock(
        skeleton: vehicule == null && _isLoading,
        actions: vehicule == null
            ? const []
            : [
                if (_tab == _DetailsTab.infos)
                  DockAction(
                    label: 'Mettre à jour le kilométrage',
                    icon: Icons.speed_rounded,
                    onPressed: _addKilometrage,
                  )
                else
                  DockAction(
                    label: 'Ajouter un fichier',
                    icon: Icons.upload_file_rounded,
                    onPressed: _uploadFile,
                  ),
              ],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
        absorbing: _uploadingPhoto,
      ),
    );
  }

  /// Premier chargement (squelette) ou échec (sous le titre).
  Widget _buildPlaceholder() {
    final error = _error;
    return AppScrollView(
      onRefresh: error != null ? _retry : null,
      children: [
        if (error != null && !_isLoading)
          AppErrorState(message: error, onRetry: _retry)
        else
          const VehiculeDetailsSkeleton(),
      ],
    );
  }

  Widget _buildContent(Vehicule vehicule) {
    return AppScrollView(
      onRefresh: _loadData,
      children: [
        VehiculeHeroCard(
          vehicule: vehicule,
          // Sans photo, l'emplacement « Ajouter une photo » n'est proposé
          // qu'à l'atelier.
          photo: vehicule.pictureUrl != null || _canManageFleet
              ? VehiculePhotoHeader(
                  url: vehicule.pictureUrl,
                  canEdit: _canManageFleet,
                  uploading: _uploadingPhoto,
                  onTap: _onPhotoTap,
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSegmented<_DetailsTab>(
          segments: [
            const AppSegment(
              value: _DetailsTab.infos,
              label: 'Infos',
              icon: Icons.info_outline_rounded,
            ),
            AppSegment(
              value: _DetailsTab.files,
              label: 'Fichiers',
              icon: Icons.folder_rounded,
              count: _files.length,
            ),
          ],
          selected: _tab,
          onChanged: (tab) => setState(() => _tab = tab),
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedSwitcher(
          duration: AppDuration.fast,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current],
          ),
          child: KeyedSubtree(
            key: ValueKey(_tab),
            child: _tab == _DetailsTab.infos
                ? VehiculeInfoTab(
                    vehicule: vehicule,
                    showEntretiens: _canManageFleet,
                    onOpenEntretiens: _openEntretiens,
                    onAddInfo: _openAddAdjustInfo,
                    now: DateTime.now(),
                  )
                : VehiculeFilesTab(
                    files: _files,
                    error: _filesError,
                    onRetry: _retry,
                    onOpen: _openFile,
                  ),
          ),
        ),
      ],
    );
  }
}

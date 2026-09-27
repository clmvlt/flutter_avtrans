import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/rapport_vehicule_model.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/widgets.dart';
import 'widgets/rapport_photos_card.dart';
import 'widgets/rapport_skeleton.dart';

/// Rapport véhicule : véhicule, photos (2 minimum : avant et arrière),
/// commentaire facultatif. « Envoyer le rapport » vit dans le dock, les
/// erreurs s'y affichent aussi.
class CreateRapportScreen extends StatefulWidget {
  const CreateRapportScreen({super.key});

  @override
  State<CreateRapportScreen> createState() => _CreateRapportScreenState();
}

class _CreateRapportScreenState extends State<CreateRapportScreen>
    with DockNoticeMixin {
  final _formKey = GlobalKey<FormState>();
  final _commentaireController = TextEditingController();
  final List<File> _images = [];
  final _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isLoadingVehicules = true;
  List<Vehicule> _vehicules = [];
  Vehicule? _selectedVehicule;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVehicules();
  }

  @override
  void dispose() {
    _commentaireController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicules() async {
    setState(() {
      _isLoadingVehicules = true;
      _errorMessage = null;
    });

    // Charger les véhicules et le dernier kilométrage en parallèle
    final (vehiculesResult, lastKmResult) = await (
      sl.vehiculeRepository.getAllVehicules(),
      sl.vehiculeRepository.getMyLastKilometrage(),
    ).wait;

    if (!mounted) return;

    vehiculesResult.fold(
      (failure) {
        setState(() {
          _isLoadingVehicules = false;
          _errorMessage = failure.message;
        });
      },
      (vehicules) {
        setState(() {
          _isLoadingVehicules = false;
          _vehicules = vehicules;

          // Essayer de sélectionner le dernier véhicule utilisé
          String? lastVehiculeId;
          lastKmResult.fold(
            (_) {}, // Ignorer l'erreur, on utilisera le premier véhicule
            (lastKmResponse) {
              if (lastKmResponse.lastKilometrage != null) {
                lastVehiculeId = lastKmResponse.lastKilometrage!.vehiculeId;
              }
            },
          );

          if (vehicules.isNotEmpty) {
            // Sélectionner le dernier véhicule utilisé s'il existe dans la liste
            if (lastVehiculeId != null) {
              _selectedVehicule = vehicules.firstWhere(
                (v) => v.id == lastVehiculeId,
                orElse: () => vehicules.first,
              );
            } else {
              _selectedVehicule = vehicules.first;
            }
          }
        });
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() => _images.add(File(image.path)));
      }
    } catch (e) {
      showDockError('Impossible d\'ajouter la photo');
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _addPhoto() async {
    clearDockNotice();
    final source = await PhotoSourceSheet.show(context);
    if (source == null || !mounted) return;
    await _pickImage(source);
  }

  Future<void> _submit() async {
    clearDockNotice();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedVehicule == null) {
      showDockError('Sélectionne un véhicule');
      return;
    }

    // Vérifier qu'il y a au moins 2 photos
    if (_images.length < kRapportMinPhotos) {
      showDockError(
        'Ajoute au moins 2 photos (avant et arrière du véhicule)',
      );
      return;
    }

    setState(() => _isLoading = true);

    // Convertir les images en base64
    List<String>? picturesB64;
    if (_images.isNotEmpty) {
      picturesB64 = [];
      for (final image in _images) {
        try {
          final bytes = await image.readAsBytes();
          final base64String = base64Encode(bytes);
          // Déterminer le type MIME
          final extension = image.path.split('.').last.toLowerCase();
          String mimeType = 'image/jpeg';
          if (extension == 'png') {
            mimeType = 'image/png';
          } else if (extension == 'jpg' || extension == 'jpeg') {
            mimeType = 'image/jpeg';
          }
          picturesB64.add('data:$mimeType;base64,$base64String');
        } catch (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          showDockError('Impossible de lire les photos. Réessaie.');
          return;
        }
      }
    }

    final request = CreateRapportRequest(
      vehiculeId: _selectedVehicule!.id,
      commentaire: _commentaireController.text.trim(),
      picturesB64: picturesB64,
    );

    final result = await sl.rapportRepository.createRapport(request);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isLoading = false);
        showDockError(failure.message);
      },
      (rapport) {
        // Confirmation brève dans le dock, puis retour (bouton toujours en
        // chargement : pas de double envoi).
        showDockSuccess('Rapport envoyé');
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) Navigator.pop(context, true);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showForm = !_isLoadingVehicules &&
        _errorMessage == null &&
        _vehicules.isNotEmpty;

    return AppPage(
      title: 'Rapport véhicule',
      body: _buildBody(),
      dock: AppDock(
        skeleton: _isLoadingVehicules,
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
        actions: [
          if (showForm)
            DockAction(
              label: 'Envoyer le rapport',
              icon: Icons.send_rounded,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _submit,
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingVehicules) {
      return const AppScrollView(children: [RapportSkeleton()]);
    }
    if (_errorMessage != null) {
      return AppScrollView(
        children: [
          AppErrorState(message: _errorMessage!, onRetry: _loadVehicules),
        ],
      );
    }
    if (_vehicules.isEmpty) {
      return const AppScrollView(
        children: [
          AppEmptyCard(
            icon: Icons.directions_car_outlined,
            message: 'Aucun véhicule disponible',
          ),
        ],
      );
    }

    return AppScrollView(
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSectionHeader(title: 'Véhicule'),
              AppCard(
                child: AppSearchableSelect<Vehicule>(
                  items: _vehicules,
                  selectedItem: _selectedVehicule,
                  onChanged: (value) {
                    setState(() => _selectedVehicule = value);
                  },
                  itemLabel: (v) => '${v.brand} ${v.model}',
                  itemSubtitle: (v) => v.immat,
                  prefixIcon: Icons.directions_car_outlined,
                  placeholder: 'Choisir un véhicule',
                  sheetTitle: 'Choisir un véhicule',
                  searchHint: 'Marque, modèle ou immatriculation…',
                  emptyMessage: 'Aucun véhicule trouvé',
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null) return 'Sélectionne un véhicule';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSectionHeader(
                title: 'Photos',
                summary: '${_images.length} / $kRapportMinPhotos minimum',
              ),
              RapportPhotosCard(
                images: _images,
                onAdd: _isLoading ? null : _addPhoto,
                onRemove: _isLoading ? null : _removeImage,
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppSectionHeader(title: 'Commentaire', summary: 'facultatif'),
              AppCard(
                child: AppTextField(
                  controller: _commentaireController,
                  hint: 'État du véhicule, remarques…',
                  maxLines: 5,
                  enabled: !_isLoading,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

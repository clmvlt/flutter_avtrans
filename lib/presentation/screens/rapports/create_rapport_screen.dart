import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/rapport_vehicule_model.dart';
import '../../../data/models/vehicule_model.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_searchable_select.dart';
import '../../widgets/app_text_field.dart';

/// Écran pour créer un rapport de véhicule
class CreateRapportScreen extends StatefulWidget {
  const CreateRapportScreen({super.key});

  @override
  State<CreateRapportScreen> createState() => _CreateRapportScreenState();
}

class _CreateRapportScreenState extends State<CreateRapportScreen> {
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
    final results = await Future.wait([
      sl.vehiculeRepository.getAllVehicules(),
      sl.vehiculeRepository.getMyLastKilometrage(),
    ]);

    if (!mounted) return;

    final vehiculesResult = results[0] as dynamic;
    final lastKmResult = results[1] as dynamic;

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
            final vehiculesList = vehicules as List<Vehicule>;
            // Sélectionner le dernier véhicule utilisé s'il existe dans la liste
            if (lastVehiculeId != null) {
              _selectedVehicule = vehiculesList.firstWhere(
                (v) => v.id == lastVehiculeId,
                orElse: () => vehiculesList.first,
              );
            } else {
              _selectedVehicule = vehiculesList.first;
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

      if (image != null) {
        setState(() {
          _images.add(File(image.path));
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de l\'image');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedVehicule == null) {
      _showError('Veuillez sélectionner un véhicule');
      return;
    }

    // Vérifier qu'il y a au moins 2 photos
    if (_images.length < 2) {
      _showError('Vous devez ajouter au moins 2 photos (avant et arrière du véhicule)');
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
          setState(() => _isLoading = false);
          _showError('Erreur lors de la lecture des images');
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

    setState(() => _isLoading = false);

    result.fold(
      (failure) => _showError(failure.message),
      (rapport) {
        final colors = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rapport créé avec succès'),
            backgroundColor: colors.success,
          ),
        );
        Navigator.pop(context, true);
      },
    );
  }

  void _showError(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors.destructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un rapport'),
      ),
      body: _isLoadingVehicules
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: colors.destructive),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.destructive),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadVehicules,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _vehicules.isEmpty
                  ? const Center(
                      child: Text('Aucun véhicule disponible'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Sélection du véhicule
                            const Text(
                              'Véhicule',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AppSearchableSelect<Vehicule>(
                              items: _vehicules,
                              selectedItem: _selectedVehicule,
                              onChanged: (value) {
                                setState(() {
                                  _selectedVehicule = value;
                                });
                              },
                              itemLabel: (v) => '${v.brand} ${v.model}',
                              itemSubtitle: (v) => v.immat,
                              prefixIcon: Icons.directions_car_outlined,
                              placeholder: 'Sélectionner un véhicule',
                              sheetTitle: 'Choisir un véhicule',
                              searchHint: 'Rechercher par marque, modèle ou immatriculation...',
                              emptyMessage: 'Aucun véhicule trouvé',
                              validator: (value) {
                                if (value == null) {
                                  return 'Veuillez sélectionner un véhicule';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Commentaire
                            const Text(
                              'Commentaire (optionnel)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AppTextField(
                              controller: _commentaireController,
                              hint: 'État du véhicule, remarques...',
                              maxLines: 5,
                            ),
                            const SizedBox(height: 24),

                            // Photos
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Photos *',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Minimum 2 photos (avant et arrière)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: _showImageSourceBottomSheet,
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: Text('Ajouter (${_images.length}/2)'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Message d'avertissement si moins de 2 photos
                            if (_images.length < 2)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: colors.warningMuted,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: colors.warning,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _images.isEmpty
                                            ? 'Ajoutez 2 photos (avant et arrière du véhicule)'
                                            : 'Ajoutez encore ${2 - _images.length} photo(s)',
                                        style: TextStyle(
                                          color: colors.warning,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Grille de photos
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1,
                              ),
                              itemCount: _images.length + 1, // +1 pour le bouton ajouter
                              itemBuilder: (context, index) {
                                // Dernier élément = bouton ajouter
                                if (index == _images.length) {
                                  return GestureDetector(
                                    onTap: _showImageSourceBottomSheet,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: colors.muted,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: colors.border,
                                          width: 2,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_outlined,
                                            size: 40,
                                            color: colors.mutedForeground,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Ajouter une photo',
                                            style: TextStyle(
                                              color: colors.mutedForeground,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                // Afficher les photos existantes
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.file(
                                          _images[index],
                                          fit: BoxFit.cover,
                                        ),
                                        // Bouton supprimer
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () => _removeImage(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: colors.destructive,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.3),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.delete_outline,
                                                color: colors.destructiveForeground,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Label photo (avant/arrière)
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  Colors.black.withValues(alpha: 0.7),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                            child: Text(
                                              index == 0 ? 'Photo avant' : index == 1 ? 'Photo arrière' : 'Photo ${index + 1}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 32),

                            // Bouton de soumission
                            AppButton(
                              text: 'Créer le rapport',
                              onPressed: _isLoading ? null : _submit,
                              isLoading: _isLoading,
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}

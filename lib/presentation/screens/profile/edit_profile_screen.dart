import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import 'widgets/password_sheet.dart';
import 'widgets/photo_source_sheet.dart';
import 'widgets/profile_address_fields.dart';
import 'widgets/profile_info_fields.dart';
import 'widgets/profile_photo_header.dart';
import 'widgets/profile_skeleton.dart';

/// Fonction pour encoder en base64 dans un isolate (ne bloque pas l'UI)
Future<String> _encodeImageToBase64(Uint8List bytes) async {
  return compute(_encodeInIsolate, bytes);
}

String _encodeInIsolate(Uint8List bytes) {
  return base64Encode(bytes);
}

/// Modification du profil : formulaire long en page pleine (photo, infos
/// personnelles, adresse), « Enregistrer le profil » dans le dock. Le
/// changement de mot de passe passe par sa propre feuille.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with DockNoticeMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _driverLicenseController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController();

  User? _user;
  bool _isLoading = true;
  String? _loadError;
  bool _isSaving = false;
  File? _selectedImage;
  String? _selectedImageBase64;

  @override
  void initState() {
    super.initState();
    // Le cache d'abord, pour un affichage instantané.
    final cachedUser = sl.authRepository.getCachedUser();
    if (cachedUser != null) {
      _fill(cachedUser);
      _isLoading = false;
    } else {
      _loadUser();
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _driverLicenseController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _fill(User user) {
    _user = user;
    _firstNameController.text = user.firstName;
    _lastNameController.text = user.lastName;
    _emailController.text = user.email;
    _driverLicenseController.text = user.driverLicenseNumber ?? '';
    _streetController.text = user.address?.street ?? '';
    _cityController.text = user.address?.city ?? '';
    _postalCodeController.text = user.address?.postalCode ?? '';
    _countryController.text = user.address?.country ?? '';
  }

  /// Pas de cache : chargement depuis l'API.
  Future<void> _loadUser() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    final result = await sl.authRepository.getCurrentUser();

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loadError = failure.message;
        _isLoading = false;
      }),
      (user) => setState(() {
        _fill(user);
        _isLoading = false;
      }),
    );
  }

  // ---- photo -------------------------------------------------------------

  Future<void> _pickImage() async {
    final action = await PhotoSourceSheet.show(
      context,
      canRemove: _selectedImage != null || _user?.pictureUrl != null,
    );
    if (action == null || !mounted) return;

    switch (action) {
      case PhotoAction.camera:
        await _getImage(ImageSource.camera);
      case PhotoAction.gallery:
        await _getImage(ImageSource.gallery);
      case PhotoAction.remove:
        setState(() {
          _selectedImage = null;
          _selectedImageBase64 = '';
        });
    }
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512, // Réduit pour un upload plus rapide
        maxHeight: 512,
        imageQuality: 70, // Compression plus agressive
      );

      if (pickedFile == null) return;

      // Lire les bytes de l'image (fonctionne sur toutes les plateformes)
      final bytes = await pickedFile.readAsBytes();

      if (!mounted) return;

      // Afficher immédiatement l'image sélectionnée (seulement sur mobile)
      if (!kIsWeb) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }

      // Encoder en base64 dans un isolate (en arrière-plan)
      final base64String = await _encodeImageToBase64(bytes);

      if (mounted) {
        setState(() {
          _selectedImageBase64 = base64String;
          // Sur le web, on ne peut pas utiliser File, donc on garde juste le base64
          if (kIsWeb) {
            _selectedImage = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        showDockError('Erreur lors de la sélection de l\'image : $e');
      }
    }
  }

  // ---- enregistrement ----------------------------------------------------

  Future<void> _saveProfile() async {
    clearDockNotice();
    if (!_formKey.currentState!.validate()) return;

    // Vérifier si des modifications ont été faites
    final newFirstName = _firstNameController.text.trim();
    final newLastName = _lastNameController.text.trim();
    final newEmail = _emailController.text.trim();
    final newDriverLicense = _driverLicenseController.text.trim();
    final newStreet = _streetController.text.trim();
    final newCity = _cityController.text.trim();
    final newPostalCode = _postalCodeController.text.trim();
    final newCountry = _countryController.text.trim();

    // Détecter si une photo a été ajoutée ou supprimée (chaîne vide = suppression)
    final hasImageChange = _selectedImageBase64 != null;

    final hasAddressChange = newStreet != (_user?.address?.street ?? '') ||
        newCity != (_user?.address?.city ?? '') ||
        newPostalCode != (_user?.address?.postalCode ?? '') ||
        newCountry != (_user?.address?.country ?? '');

    final hasChanges = newFirstName != _user?.firstName ||
        newLastName != _user?.lastName ||
        newEmail != _user?.email ||
        newDriverLicense != (_user?.driverLicenseNumber ?? '') ||
        hasAddressChange ||
        hasImageChange;

    if (!hasChanges) {
      showDockNotice(
        'Aucune modification à enregistrer',
        variant: AlertVariant.info,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Construire l'adresse si au moins un champ est renseigné
    Address? addressUpdate;
    if (hasAddressChange) {
      addressUpdate = Address(
        street: newStreet.isNotEmpty ? newStreet : null,
        city: newCity.isNotEmpty ? newCity : null,
        postalCode: newPostalCode.isNotEmpty ? newPostalCode : null,
        country: newCountry.isNotEmpty ? newCountry : null,
      );
    }

    // N'envoyer que les champs modifiés pour réduire la taille de la requête
    final request = UpdateProfileRequest(
      firstName: newFirstName != _user?.firstName ? newFirstName : null,
      lastName: newLastName != _user?.lastName ? newLastName : null,
      email: newEmail != _user?.email ? newEmail : null,
      picture: _selectedImageBase64,
      driverLicenseNumber: newDriverLicense != (_user?.driverLicenseNumber ?? '')
          ? newDriverLicense
          : null,
      address: addressUpdate,
    );

    final result = await sl.authRepository.updateProfile(request);

    if (!mounted) return;

    setState(() => _isSaving = false);

    result.fold(
      (failure) => showDockError(failure.message),
      (user) {
        setState(() {
          _user = user;
          _selectedImage = null;
          _selectedImageBase64 = null;
        });
        showDockSuccess('Profil mis à jour');
      },
    );
  }

  // ---- mot de passe ------------------------------------------------------

  Future<void> _openPasswordSheet() async {
    clearDockNotice();
    final changed = await PasswordSheet.show(context, onSubmit: _changePassword);
    if (!changed || !mounted) return;
    showDockSuccess('Mot de passe modifié');
  }

  /// Retourne le message d'erreur, ou `null` si le mot de passe est changé.
  Future<String?> _changePassword(
    String current,
    String next,
    String confirm,
  ) async {
    if (current.isEmpty || next.isEmpty) {
      return 'Remplis tous les champs';
    }
    if (next != confirm) {
      return 'Les mots de passe ne correspondent pas';
    }
    if (next.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères';
    }

    final result = await sl.authRepository.updatePassword(
      UpdatePasswordRequest(currentPassword: current, newPassword: next),
    );
    return result.fold((failure) => failure.message, (_) => null);
  }

  // ---- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ready = !_isLoading && _loadError == null;

    return AppPage(
      title: 'Modifier le profil',
      body: _buildBody(),
      dock: ready
          ? AppDock(
              actions: [
                DockAction(
                  label: 'Enregistrer le profil',
                  icon: Icons.check_rounded,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _saveProfile,
                ),
              ],
              notice: dockNotice,
              onDismissNotice: clearDockNotice,
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppScrollView(children: [ProfileSkeleton()]);
    }

    final loadError = _loadError;
    if (loadError != null) {
      return AppScrollView(
        children: [AppErrorState(message: loadError, onRetry: _loadUser)],
      );
    }

    final colors = context.colors;

    return Form(
      key: _formKey,
      child: AppScrollView(
        topPadding: AppSpacing.lg,
        children: [
          ProfilePhotoHeader(
            name: _user?.fullName ?? '',
            email: _user?.email ?? '',
            selectedFile: _selectedImage,
            selectedBase64: _selectedImageBase64,
            pictureUrl: _user?.pictureUrl,
            onEdit: _pickImage,
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppSectionHeader(title: 'Informations personnelles'),
          ProfileInfoFields(
            firstName: _firstNameController,
            lastName: _lastNameController,
            email: _emailController,
            driverLicense: _driverLicenseController,
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppSectionHeader(title: 'Adresse'),
          ProfileAddressFields(
            street: _streetController,
            postalCode: _postalCodeController,
            city: _cityController,
            country: _countryController,
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppSectionHeader(title: 'Mot de passe'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: AppListRow(
              icon: Icons.lock_rounded,
              iconColor: colors.domainVehicule,
              title: 'Changer le mot de passe',
              subtitle: 'Ton mot de passe actuel te sera demandé',
              onTap: _openPasswordSheet,
            ),
          ),
        ],
      ),
    );
  }
}

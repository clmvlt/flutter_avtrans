import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';

/// Fonction pour encoder en base64 dans un isolate (ne bloque pas l'UI)
Future<String> _encodeImageToBase64(Uint8List bytes) async {
  return compute(_encodeInIsolate, bytes);
}

String _encodeInIsolate(Uint8List bytes) {
  return base64Encode(bytes);
}

/// Page d'édition du profil utilisateur
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _driverLicenseController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  User? _user;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isChangingPassword = false;
  File? _selectedImage;
  String? _selectedImageBase64;
  bool _showPasswordSection = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
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
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    // Utiliser le cache d'abord pour un affichage instantané
    final cachedUser = sl.authRepository.getCachedUser();
    if (cachedUser != null) {
      setState(() {
        _user = cachedUser;
        _firstNameController.text = cachedUser.firstName;
        _lastNameController.text = cachedUser.lastName;
        _emailController.text = cachedUser.email;
        _driverLicenseController.text = cachedUser.driverLicenseNumber ?? '';
        _streetController.text = cachedUser.address?.street ?? '';
        _cityController.text = cachedUser.address?.city ?? '';
        _postalCodeController.text = cachedUser.address?.postalCode ?? '';
        _countryController.text = cachedUser.address?.country ?? '';
        _isLoading = false;
      });
      return;
    }

    // Si pas de cache, charger depuis l'API
    setState(() => _isLoading = true);

    final result = await sl.authRepository.getCurrentUser();

    if (!mounted) return;

    result.fold(
      (failure) {
        _showError(failure.message);
        setState(() => _isLoading = false);
      },
      (user) {
        setState(() {
          _user = user;
          _firstNameController.text = user.firstName;
          _lastNameController.text = user.lastName;
          _emailController.text = user.email;
          _driverLicenseController.text = user.driverLicenseNumber ?? '';
          _streetController.text = user.address?.street ?? '';
          _cityController.text = user.address?.city ?? '';
          _postalCodeController.text = user.address?.postalCode ?? '';
          _countryController.text = user.address?.country ?? '';
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        final colors = context.colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  'Choisir une photo',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.camera_alt, color: colors.primary),
                  ),
                  title: Text(
                    'Prendre une photo',
                    style: TextStyle(color: colors.foreground),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _getImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.photo_library, color: colors.secondary),
                  ),
                  title: Text(
                    'Choisir depuis la galerie',
                    style: TextStyle(color: colors.foreground),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _getImage(ImageSource.gallery);
                  },
                ),
                if (_selectedImage != null || _user?.pictureUrl != null)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.destructive.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(Icons.delete, color: colors.destructive),
                    ),
                    title: Text(
                      'Supprimer la photo',
                      style: TextStyle(color: colors.destructive),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedImage = null;
                        _selectedImageBase64 = '';
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,  // Réduit pour un upload plus rapide
        maxHeight: 512,
        imageQuality: 70,  // Compression plus agressive
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
        _showError('Erreur lors de la sélection de l\'image: $e');
      }
    }
  }

  Future<void> _saveProfile() async {
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
      _showSuccess('Aucune modification à enregistrer');
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
      (failure) => _showError(failure.message),
      (user) {
        setState(() {
          _user = user;
          _selectedImage = null;
          _selectedImageBase64 = null;
        });
        _showSuccess('Profil mis à jour avec succès');
      },
    );
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty) {
      _showError('Veuillez remplir tous les champs');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('Les mots de passe ne correspondent pas');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showError('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }

    setState(() => _isChangingPassword = true);

    final request = UpdatePasswordRequest(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    final result = await sl.authRepository.updatePassword(request);

    if (!mounted) return;

    setState(() => _isChangingPassword = false);

    result.fold(
      (failure) => _showError(failure.message),
      (_) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() => _showPasswordSection = false);
        _showSuccess('Mot de passe modifié avec succès');
      },
    );
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(color: colors.destructive),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: colors.success, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(color: colors.success),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Modifier le profil'),
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Chargement...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfilePicture(colors),
                    const SizedBox(height: AppSpacing.lg),
                    _buildInfoSection(colors),
                    const SizedBox(height: AppSpacing.base),
                    _buildAddressSection(colors),
                    const SizedBox(height: AppSpacing.base),
                    _buildPasswordSection(colors),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      text: 'Enregistrer les modifications',
                      icon: Icons.save,
                      onPressed: _saveProfile,
                      isLoading: _isSaving,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfilePicture(AppColors colors) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.card,
              border: Border.all(color: colors.border, width: 3),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: _buildProfileImage(colors),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.background, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: colors.primaryForeground,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(AppColors colors) {
    return Container(
      color: colors.muted,
      child: Icon(
        Icons.person,
        size: 60,
        color: colors.mutedForeground,
      ),
    );
  }

  Widget _buildProfileImage(AppColors colors) {
    // Si l'utilisateur a demandé la suppression de la photo (chaîne vide)
    if (_selectedImageBase64 == '') {
      return _buildDefaultAvatar(colors);
    }

    // Priorité 1: Image sélectionnée depuis un fichier (mobile uniquement)
    if (_selectedImage != null && !kIsWeb) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (_, __, ___) => _buildDefaultAvatar(colors),
      );
    }

    // Priorité 2: Image sélectionnée en base64 (web ou fallback)
    if (_selectedImageBase64 != null && _selectedImageBase64!.isNotEmpty) {
      return Image.memory(
        base64Decode(_selectedImageBase64!),
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (_, __, ___) => _buildDefaultAvatar(colors),
      );
    }

    // Priorité 3: Image du profil existante depuis l'URL
    if (_user?.pictureUrl != null) {
      return Image.network(
        _user!.pictureUrl!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (_, __, ___) => _buildDefaultAvatar(colors),
      );
    }

    // Défaut: Avatar par défaut
    return _buildDefaultAvatar(colors);
  }

  Widget _buildInfoSection(AppColors colors) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: colors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Informations personnelles',
                style: textTheme.titleMedium?.copyWith(
                  color: colors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          _buildTextField(
            controller: _firstNameController,
            label: 'Prénom',
            icon: Icons.badge_outlined,
            colors: colors,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Le prénom est requis';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            controller: _lastNameController,
            label: 'Nom',
            icon: Icons.badge_outlined,
            colors: colors,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Le nom est requis';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            colors: colors,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'L\'email est requis';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Email invalide';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            controller: _driverLicenseController,
            label: 'Numéro de permis de conduire',
            icon: Icons.credit_card,
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection(AppColors colors) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: colors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Adresse',
                style: textTheme.titleMedium?.copyWith(
                  color: colors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          _buildTextField(
            controller: _streetController,
            label: 'Rue et numéro',
            icon: Icons.home_outlined,
            colors: colors,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _postalCodeController,
                  label: 'Code postal',
                  icon: Icons.pin_drop_outlined,
                  keyboardType: TextInputType.number,
                  colors: colors,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 3,
                child: _buildTextField(
                  controller: _cityController,
                  label: 'Ville',
                  icon: Icons.location_city_outlined,
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            controller: _countryController,
            label: 'Pays',
            icon: Icons.flag_outlined,
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection(AppColors colors) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showPasswordSection = !_showPasswordSection),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: colors.secondary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Modifier le mot de passe',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  Icon(
                    _showPasswordSection
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: colors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
          if (_showPasswordSection) ...[
            Divider(color: colors.border, height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _currentPasswordController,
                    label: 'Mot de passe actuel',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    colors: colors,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildTextField(
                    controller: _newPasswordController,
                    label: 'Nouveau mot de passe',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    colors: colors,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirmer le mot de passe',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    colors: colors,
                  ),
                  const SizedBox(height: AppSpacing.base),
                  AppButton(
                    text: 'Modifier le mot de passe',
                    icon: Icons.security,
                    onPressed: _changePassword,
                    isLoading: _isChangingPassword,
                    backgroundColor: colors.secondary,
                    foregroundColor: colors.primaryForeground,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppColors colors,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(color: colors.foreground),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.mutedForeground),
        prefixIcon: Icon(icon, color: colors.mutedForeground, size: 20),
        filled: true,
        fillColor: colors.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colors.destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colors.destructive, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}

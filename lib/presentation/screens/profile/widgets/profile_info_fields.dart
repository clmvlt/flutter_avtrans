import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';

/// Groupe « Informations personnelles » du profil : prénom, nom, email,
/// numéro de permis. À placer dans le `Form` de la page (validation).
class ProfileInfoFields extends StatelessWidget {
  const ProfileInfoFields({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.driverLicense,
  });

  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController email;
  final TextEditingController driverLicense;

  static final _emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: firstName,
            label: 'Prénom',
            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Le prénom est requis';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: lastName,
            label: 'Nom',
            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Le nom est requis';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'L\'email est requis';
              }
              if (!_emailPattern.hasMatch(value)) {
                return 'Email invalide';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: driverLicense,
            label: 'Numéro de permis de conduire',
            prefixIcon: const Icon(Icons.credit_card_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

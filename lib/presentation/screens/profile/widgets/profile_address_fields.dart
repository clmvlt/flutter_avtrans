import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';

/// Groupe « Adresse » du profil : rue, code postal et ville côte à côte,
/// pays. Tous facultatifs.
class ProfileAddressFields extends StatelessWidget {
  const ProfileAddressFields({
    super.key,
    required this.street,
    required this.postalCode,
    required this.city,
    required this.country,
  });

  final TextEditingController street;
  final TextEditingController postalCode;
  final TextEditingController city;
  final TextEditingController country;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: street,
            label: 'Rue et numéro',
            prefixIcon: const Icon(Icons.home_outlined, size: 20),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: postalCode,
                  label: 'Code postal',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 3,
                child: AppTextField(
                  controller: city,
                  label: 'Ville',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: country,
            label: 'Pays',
            prefixIcon: const Icon(Icons.flag_outlined, size: 20),
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }
}

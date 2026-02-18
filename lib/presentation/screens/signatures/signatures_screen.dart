import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import 'sign_screen.dart';

/// Page de gestion des signatures
class SignaturesScreen extends StatefulWidget {
  const SignaturesScreen({super.key});

  @override
  State<SignaturesScreen> createState() => _SignaturesScreenState();
}

class _SignaturesScreenState extends State<SignaturesScreen> {
  List<Signature> _signatures = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  Future<void> _loadSignatures() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await sl.signatureRepository.getMySignatures();

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (signatures) {
        setState(() {
          _signatures = signatures;
          _isLoading = false;
        });
      },
    );
  }

  void _openSignScreen() async {
    // Vérifie d'abord si l'utilisateur peut signer
    final summaryResult = await sl.signatureRepository.getLastSignatureSummary();

    if (!mounted) return;

    summaryResult.fold(
      (failure) {
        _showError(failure.message);
      },
      (summary) async {
        if (!summary.needsToSign) {
          _showError('Vous avez déjà signé vos heures pour cette période');
          return;
        }

        // Ouvre l'écran de signature avec les heures du mois dernier
        final result = await Navigator.of(context).push<Signature>(
          MaterialPageRoute(
            builder: (_) => SignScreen(
              heuresLastMonth: summary.heuresLastMonth,
            ),
          ),
        );

        if (result != null) {
          setState(() => _signatures.insert(0, result));
        }
      },
    );
  }

  void _showError(String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.bgSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(color: colors.error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        title: const Text('Mes signatures'),
        backgroundColor: colors.bgSecondary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSignScreen,
        backgroundColor: colors.primary,
        icon: const Icon(Icons.draw, color: Colors.white),
        label: const Text(
          'Signer',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Chargement...');
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: AppSpacing.base),
            Text(
              _error!,
              style: TextStyle(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              text: 'Réessayer',
              onPressed: _loadSignatures,
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
            ),
          ],
        ),
      );
    }

    if (_signatures.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.draw_outlined,
              size: 64,
              color: colors.textMuted,
            ),
            const SizedBox(height: AppSpacing.base),
            Text(
              'Aucune signature',
              style: TextStyle(
                fontSize: 16,
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Appuyez sur "Signer" pour créer une signature',
              style: TextStyle(
                fontSize: 13,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSignatures,
      color: colors.primary,
      backgroundColor: colors.bgSecondary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.base),
        itemCount: _signatures.length,
        itemBuilder: (context, index) {
          final signature = _signatures[index];
          return _buildSignatureCard(signature, colors);
        },
      ),
    );
  }

  Widget _buildSignatureCard(Signature signature, AppColors colors) {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      color: colors.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec date et heures
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: colors.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    dateFormat.format(signature.date),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 14, color: colors.success),
                      const SizedBox(width: 4),
                      Text(
                        '${signature.heuresSignees.toStringAsFixed(1)}h',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            // Aperçu de la signature
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: colors.borderPrimary),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.memory(
                  base64Decode(signature.signatureBase64),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Date de création
            if (signature.createdAt != null)
              Row(
                children: [
                  Icon(Icons.access_time, size: 12, color: colors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Signé le ${dateFormat.format(signature.createdAt!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

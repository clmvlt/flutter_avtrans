import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/widgets.dart';
import 'sign_screen.dart';

/// Page de gestion des signatures - design shadcn/ui
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
      (failure) => setState(() {
        _error = failure.message;
        _isLoading = false;
      }),
      (signatures) => setState(() {
        _signatures = signatures;
        _isLoading = false;
      }),
    );
  }

  void _openSignScreen() async {
    final summaryResult = await sl.signatureRepository.getLastSignatureSummary();
    if (!mounted) return;

    summaryResult.fold(
      (failure) => _showError(failure.message),
      (summary) async {
        if (!summary.needsToSign) {
          _showError('Vous avez déjà signé vos heures pour cette période');
          return;
        }

        final result = await Navigator.of(context).push<Signature>(
          MaterialPageRoute(
            builder: (_) => SignScreen(heuresLastMonth: summary.heuresLastMonth),
          ),
        );

        if (result != null) {
          setState(() => _signatures.insert(0, result));
        }
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Mes signatures')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSignScreen,
        backgroundColor: colors.primary,
        icon: Icon(Icons.draw, color: colors.primaryForeground, size: 18),
        label: Text('Signer', style: TextStyle(color: colors.primaryForeground)),
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isLoading) return const LoadingIndicator(message: 'Chargement...');

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 40, color: colors.destructive),
            const SizedBox(height: AppSpacing.base),
            Text(_error!, style: TextStyle(color: colors.mutedForeground), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.base),
            AppButton(text: 'Réessayer', onPressed: _loadSignatures, fullWidth: false),
          ],
        ),
      );
    }

    if (_signatures.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.draw_outlined, size: 48, color: colors.mutedForeground),
            const SizedBox(height: AppSpacing.base),
            Text('Aucune signature', style: TextStyle(fontSize: 16, color: colors.foreground)),
            const SizedBox(height: AppSpacing.xs),
            Text('Appuyez sur "Signer" pour créer une signature', style: TextStyle(fontSize: 13, color: colors.mutedForeground)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSignatures,
      color: colors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.base),
        itemCount: _signatures.length,
        itemBuilder: (context, index) => _buildSignatureCard(_signatures[index], colors),
      ),
    );
  }

  Widget _buildSignatureCard(Signature signature, AppColors colors) {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
              Icon(Icons.calendar_today, size: 14, color: colors.mutedForeground),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  dateFormat.format(signature.date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.foreground,
                  ),
                ),
              ),
              AppBadge(
                text: '${signature.heuresSignees.toStringAsFixed(1)}h',
                variant: BadgeVariant.success,
                icon: Icons.schedule,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.memory(
                base64Decode(signature.signatureBase64),
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (signature.createdAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: colors.mutedForeground),
                const SizedBox(width: 4),
                Text(
                  'Signé le ${dateFormat.format(signature.createdAt!)}',
                  style: TextStyle(fontSize: 11, color: colors.mutedForeground),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

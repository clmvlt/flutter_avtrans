import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_theme.dart';

/// Écran affichant la carte UTA dans une WebView intégrée
class UtaMapScreen extends StatefulWidget {
  const UtaMapScreen({super.key});

  @override
  State<UtaMapScreen> createState() => _UtaMapScreenState();
}

class _UtaMapScreenState extends State<UtaMapScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  static const String _utaUrl =
      'https://www.uta.com/InternetExtensions/prod/spr/interExtRadiusSearch-flow?execution=e2s1';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur: ${error.description}')),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_utaUrl));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Carte UTA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => _controller.reload(),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(color: colors.primary),
            ),
        ],
      ),
    );
  }
}

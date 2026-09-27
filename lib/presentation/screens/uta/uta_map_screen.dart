import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// Écran affichant la carte UTA (stations de la carte carburant) dans une
/// WebView intégrée. Seul l'habillage suit le kit : la carte elle-même est
/// la page web d'UTA.
class UtaMapScreen extends StatefulWidget {
  const UtaMapScreen({super.key});

  @override
  State<UtaMapScreen> createState() => _UtaMapScreenState();
}

class _UtaMapScreenState extends State<UtaMapScreen> with DockNoticeMixin {
  late final WebViewController _controller;
  bool _isLoading = true;

  /// La première page n'a pas fini de charger : indicateur centré (comme
  /// avant) ; ensuite, une fine barre en haut suffit.
  bool _firstLoad = true;

  /// Échec de la page principale : la carte est remplacée par un état
  /// d'erreur avec « Réessayer ».
  String? _pageError;

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
            if (mounted) {
              setState(() {
                _isLoading = false;
                _firstLoad = false;
              });
            }
          },
          onWebResourceError: _onWebResourceError,
        ),
      )
      ..loadRequest(Uri.parse(_utaUrl));
  }

  void _onWebResourceError(WebResourceError error) {
    if (!mounted) return;
    if (error.isForMainFrame == true) {
      setState(() {
        _pageError = error.description;
        _isLoading = false;
      });
      return;
    }
    showDockError('Erreur : ${error.description}');
  }

  void _reload() {
    clearDockNotice();
    setState(() => _pageError = null);
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPage(
      title: 'Carte UTA',
      actions: [
        AppIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Actualiser',
          color: colors.foreground,
          onPressed: _reload,
        ),
      ],
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading && _firstLoad && _pageError == null)
            Center(child: CircularProgressIndicator(color: colors.primary))
          else if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: colors.primary,
                backgroundColor: colors.primary.withValues(alpha: 0.12),
              ),
            ),
          if (_pageError != null)
            Positioned.fill(
              child: ColoredBox(
                color: colors.background,
                child: AppScrollView(
                  children: [
                    AppErrorState(
                      title: 'Carte indisponible',
                      message: 'La carte UTA ne s\'est pas chargée. Vérifie ta '
                          'connexion puis réessaie.\n$_pageError',
                      onRetry: _reload,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      dock: AppDock(notice: dockNotice, onDismissNotice: clearDockNotice),
    );
  }
}

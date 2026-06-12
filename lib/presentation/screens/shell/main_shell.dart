import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../services/services_screen.dart';
import '../ypsium/ypsium_login_screen.dart';
import 'home_dashboard_screen.dart';
import 'moi_tab.dart';

/// Coquille principale de l'app — bottom navigation à 4 onglets.
///
/// Remplace l'ancienne navigation « tout en Navigator.push depuis une grille ».
///
/// Deux précautions importantes :
/// - **Chargement paresseux** : un onglet n'est instancié qu'à sa première
///   visite. Sans ça, l'`IndexedStack` construirait les 4 onglets au démarrage
///   et leurs `initState` se déclencheraient tous (Ypsium restaurerait sa
///   session et naviguerait, Pointage ouvrirait ses dialogs…). Une fois visité,
///   l'onglet reste monté → son état est préservé.
/// - **Navigator imbriqué pour Ypsium** : ses écrans font des
///   `pushReplacement` ; isolés dans un Navigator propre à l'onglet, ils ne
///   remplacent plus toute la coquille et la bottom bar reste visible.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;
  final Set<int> _initialized = {};
  final GlobalKey<NavigatorState> _ypsiumNavKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initialized.add(_index);
  }

  void _goTo(int index) {
    if (_index == index) {
      // Re-tap sur l'onglet actif Ypsium → revenir à sa racine.
      if (index == 2) {
        _ypsiumNavKey.currentState?.popUntil((r) => r.isFirst);
      }
      return;
    }
    setState(() {
      _index = index;
      _initialized.add(index);
    });
  }

  Widget _buildTab(int i) {
    switch (i) {
      case 0:
        return HomeDashboardScreen(
          onOpenPointage: () => _goTo(1),
          onOpenMoi: () => _goTo(3),
        );
      case 1:
        return const ServicesScreen();
      case 2:
        // Navigator dédié : la navigation interne Ypsium reste dans l'onglet.
        return Navigator(
          key: _ypsiumNavKey,
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const YpsiumLoginScreen(),
          ),
        );
      case 3:
        return const MoiTab();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      // Sur l'accueil, le retour système quitte l'app ; ailleurs on l'intercepte.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Onglet Ypsium : laisser son Navigator imbriqué consommer le retour.
        if (_index == 2 && (_ypsiumNavKey.currentState?.canPop() ?? false)) {
          _ypsiumNavKey.currentState!.pop();
          return;
        }
        // Autres onglets : revenir à l'accueil plutôt que quitter l'app.
        if (_index != 0) _goTo(0);
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: IndexedStack(
          index: _index,
          children: List.generate(
            4,
            (i) => _initialized.contains(i)
                ? _buildTab(i)
                : const SizedBox.shrink(),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: colors.card,
            boxShadow: colors.navShadow,
            border: colors.isDarkMode
                ? Border(top: BorderSide(color: colors.border))
                : null,
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _goTo,
            backgroundColor: Colors.transparent,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Accueil',
              ),
              NavigationDestination(
                icon: Icon(Icons.access_time_outlined),
                selectedIcon: Icon(Icons.access_time_filled_rounded),
                label: 'Pointage',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping_rounded),
                label: 'Ypsium',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Moi',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

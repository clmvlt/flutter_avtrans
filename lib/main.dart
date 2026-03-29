import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await ServiceLocator().init();
  await initializeDateFormatting('fr_FR', null);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Pointage AVTRANS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
      home: const SplashScreen(),
    );
  }
}

/// Ecran de demarrage — animation fade-in + navigation
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _hasNavigated = false;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _checkAuthAndUpdate();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkAuthAndUpdate() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    await _checkForUpdate();
    if (!mounted) return;

    final isLoggedIn = sl.authRepository.isLoggedIn();

    if (isLoggedIn) {
      final result = await sl.authRepository.getCurrentUser();
      if (!mounted) return;
      result.fold(
        (failure) => _navigateToLogin(),
        (user) => _navigateToHome(),
      );
    } else {
      _navigateToLogin();
    }
  }

  Future<void> _checkForUpdate() async {
    final updateResponse = await sl.updateCheckerService.checkForUpdate();
    if (!mounted) return;

    if (updateResponse != null && updateResponse.latestVersion != null) {
      final currentVersion = await sl.updateCheckerService.currentVersionName;
      if (!mounted) return;

      await UpdateDialog.show(
        context,
        version: updateResponse.latestVersion!,
        currentVersion: currentVersion,
        onSkip: () {
          sl.updateCheckerService.skipVersion(
            updateResponse.latestVersion!.versionCode,
          );
        },
      );
    }
  }

  void _navigateToLogin() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _navigateToHome() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo avec app icon
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Image.asset(
                  'lib/assets/icons/icon-512x512.png',
                  width: 88,
                  height: 88,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'AVTRANS',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: colors.foreground,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Gestion du temps de travail',
                style: TextStyle(
                  fontSize: 16,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

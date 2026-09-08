import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/google_auth_constants.dart';
import '../../core/errors/exceptions.dart';

/// Enveloppe du SDK natif Google Sign-In (`google_sign_in` 7.x).
///
/// Son seul rôle est d'obtenir un **ID token** Google dont l'audience est le
/// client OAuth *Web* (fiche d'intégration §1). Il ne parle jamais à l'API
/// AVTrans : c'est `AuthRepository` qui envoie ce token à `POST /auth/google`.
/// L'app ne fait aucun appel vers Google côté serveur.
class GoogleSignInService {
  final GoogleSignIn _googleSignIn;
  Future<void>? _initialization;

  GoogleSignInService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  /// Plateformes couvertes par le SDK. Sur Web, `google_sign_in` impose un
  /// bouton rendu par Google (`renderButton`) non pris en charge ici ; sur
  /// Windows / Linux le plugin n'est pas enregistré du tout.
  bool get isSupported =>
      !kIsWeb &&
      const {TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS}
          .contains(defaultTargetPlatform);

  /// Ouvre le sélecteur de compte Google et renvoie l'ID token (valable 1 h).
  ///
  /// Lève [OperationCancelledException] si l'utilisateur ferme le sélecteur,
  /// [AuthException] pour toute autre erreur (SDK, configuration, plateforme).
  Future<String> requestIdToken() async {
    if (!isSupported) {
      throw const AuthException(
        message: 'La connexion Google n\'est pas disponible sur cette plateforme.',
      );
    }

    final GoogleSignInAccount account;
    try {
      await _ensureInitialized();
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      throw _mapException(e);
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint('GoogleSignInService.requestIdToken: $e');
      throw const AuthException(
        message: 'Connexion Google impossible. Veuillez réessayer.',
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException(
        message:
            'Google n\'a pas fourni de jeton d\'identité. Vérifiez le client Web (serverClientId) de la configuration.',
      );
    }
    return idToken;
  }

  /// Efface l'état de connexion Google sur l'appareil : le prochain
  /// [requestIdToken] réaffiche le sélecteur de compte au lieu de reprendre
  /// silencieusement le dernier compte. Ne lève jamais (meilleur effort).
  Future<void> signOut() async {
    if (!isSupported) return;
    try {
      await _ensureInitialized();
      await _googleSignIn.signOut();
    } catch (e) {
      // La session locale est déjà purgée par le repository : rien à remonter.
      debugPrint('GoogleSignInService.signOut: $e');
    }
  }

  /// Initialise le SDK une seule fois (idempotent, réessayé après un échec).
  ///
  /// `serverClientId` = client **Web** (audience attendue par l'API),
  /// `clientId` = client iOS (ignoré sur Android).
  Future<void> _ensureInitialized() async {
    final pending = _initialization ??= _googleSignIn.initialize(
      clientId: GoogleAuthConstants.iosClientId,
      serverClientId: GoogleAuthConstants.webClientId,
    );
    try {
      await pending;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  AppException _mapException(GoogleSignInException e) {
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled => const OperationCancelledException(
          message: 'Connexion Google annulée.',
        ),
      GoogleSignInExceptionCode.interrupted ||
      GoogleSignInExceptionCode.uiUnavailable =>
        const AuthException(
          message: 'La connexion Google a été interrompue. Veuillez réessayer.',
        ),
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        const AuthException(
          message:
              'Connexion Google indisponible : configuration invalide (client OAuth, empreinte SHA-1 ou services Google Play).',
        ),
      _ => AuthException(
          message: (e.description?.trim().isNotEmpty ?? false)
              ? 'Connexion Google impossible : ${e.description!.trim()}'
              : 'Connexion Google impossible. Veuillez réessayer.',
        ),
    };
  }
}

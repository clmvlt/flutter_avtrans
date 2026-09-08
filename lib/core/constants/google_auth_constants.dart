import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Identifiants OAuth Google (fiche d'intégration « Sign in with Google », §1).
///
/// L'API AVTrans vérifie elle-même l'ID token (signature, expiration, émetteur)
/// et exige que son audience (`aud`) soit le client OAuth de type
/// *Web application*. Les clients Android / iOS servent uniquement au SDK
/// natif : ils ne sont **jamais** l'audience attendue. Aucun client secret
/// n'est nécessaire côté mobile — ne pas l'embarquer dans l'app.
abstract class GoogleAuthConstants {
  /// Client OAuth *Web* — passé en `serverClientId` au SDK, c'est lui qui
  /// fixe le champ `aud` du token à la valeur attendue par l'API.
  /// Surchargeable via `GOOGLE_WEB_CLIENT_ID` dans `.env`.
  static String get webClientId {
    final value = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
    return (value == null || value.isEmpty) ? _defaultWebClientId : value;
  }

  /// Client OAuth *iOS* (bundle ID) — requis par le SDK iOS / macOS uniquement,
  /// ignoré sur Android. Lu depuis `GOOGLE_IOS_CLIENT_ID` dans `.env` ; `null`
  /// si absent (le SDK se rabat alors sur `GIDClientID` dans `Info.plist`).
  static String? get iosClientId {
    final value = dotenv.env['GOOGLE_IOS_CLIENT_ID']?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Audience documentée dans la fiche d'intégration (identifiant public,
  /// pas un secret).
  static const String _defaultWebClientId =
      '703495171118-b36esibhshnu9ubakjai6v2a23q5acns.apps.googleusercontent.com';
}

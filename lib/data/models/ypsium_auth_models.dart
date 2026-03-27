import 'package:equatable/equatable.dart';

/// Réponse de l'étape 1 : GET /authentification/getConnexion/{cle}
class YpsiumConnexionResponse extends Equatable {
  final bool auth;
  final String cle;
  final String token;

  const YpsiumConnexionResponse({
    required this.auth,
    required this.cle,
    required this.token,
  });

  factory YpsiumConnexionResponse.fromJson(Map<String, dynamic> json) {
    return YpsiumConnexionResponse(
      auth: json['auth'] as bool? ?? false,
      cle: json['Cle'] as String? ?? '',
      token: json['token'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [auth, cle, token];
}

/// Requête de l'étape 2 : POST /authentification/logon/{session_id}
class YpsiumLogonRequest extends Equatable {
  final String login;
  final String password;

  const YpsiumLogonRequest({
    required this.login,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'login': login,
        'password': password,
      };

  @override
  List<Object?> get props => [login, password];
}

/// Réponse de l'étape 2 : POST /authentification/logon/{session_id}
/// En cas de succès, le serveur retourne le profil chauffeur complet
class YpsiumLogonResponse extends Equatable {
  final bool auth;
  final String id;
  final String nom;
  final String typeChauff;
  final String token;
  final bool droitChauff;
  final bool droitEntrepot;
  final bool droitManquant;
  final bool droitScanManuel;
  final bool droitScanManuelAvecPhoto;
  final bool droitSupOrdre;
  final bool droitAnnul;
  final bool droitCreatCompte;
  final bool droitCreatOrdre;
  final bool droitRegroupementPalette;
  final bool signatureChauffAuto;

  const YpsiumLogonResponse({
    required this.auth,
    this.id = '',
    this.nom = '',
    this.typeChauff = '',
    this.token = '',
    this.droitChauff = false,
    this.droitEntrepot = false,
    this.droitManquant = false,
    this.droitScanManuel = false,
    this.droitScanManuelAvecPhoto = false,
    this.droitSupOrdre = false,
    this.droitAnnul = false,
    this.droitCreatCompte = false,
    this.droitCreatOrdre = false,
    this.droitRegroupementPalette = false,
    this.signatureChauffAuto = false,
  });

  factory YpsiumLogonResponse.fromJson(Map<String, dynamic> json) {
    return YpsiumLogonResponse(
      auth: json['auth'] as bool? ?? false,
      id: (json['id'] ?? '').toString(),
      nom: (json['nom'] ?? '').toString(),
      typeChauff: (json['typeChauff'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      droitChauff: json['droitChauff'] as bool? ?? false,
      droitEntrepot: json['droitEntrepot'] as bool? ?? false,
      droitManquant: json['droitManquant'] as bool? ?? false,
      droitScanManuel: json['droitScanManuel'] as bool? ?? false,
      droitScanManuelAvecPhoto: json['droitScanManuelAvecPhoto'] as bool? ?? false,
      droitSupOrdre: json['droitSupOrdre'] as bool? ?? false,
      droitAnnul: json['droitAnnul'] as bool? ?? false,
      droitCreatCompte: json['droitCreatCompte'] as bool? ?? false,
      droitCreatOrdre: json['droitCreatOrdre'] as bool? ?? false,
      droitRegroupementPalette: json['droitRegroupementPalette'] as bool? ?? false,
      signatureChauffAuto: json['signatureChauffAuto'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [auth, id, token];
}


/// Session Ypsium active après login réussi
class YpsiumSession extends Equatable {
  final String token;
  final String login;
  final String idChauffeur;
  final String nom;
  final String typeChauff;
  final bool droitChauff;
  final bool droitEntrepot;
  final bool droitScanManuel;
  final bool droitSupOrdre;
  final bool droitCreatOrdre;
  final bool signatureChauffAuto;

  const YpsiumSession({
    required this.token,
    required this.login,
    required this.idChauffeur,
    this.nom = '',
    this.typeChauff = '',
    this.droitChauff = false,
    this.droitEntrepot = false,
    this.droitScanManuel = false,
    this.droitSupOrdre = false,
    this.droitCreatOrdre = false,
    this.signatureChauffAuto = false,
  });

  @override
  List<Object?> get props => [token, login, idChauffeur];
}

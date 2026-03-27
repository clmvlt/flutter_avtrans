import 'package:equatable/equatable.dart';

// ============================================================
// TRANSPORT
// ============================================================

/// Ordre de transport Ypsium
class YpsiumTransportOrder extends Equatable {
  // --- Enlèvement (E_) ---
  final String eNom;
  final String eAdresse1;
  final String eAdresse2;
  final String eAdresse3;
  final String eCodePostal;
  final String eVille;
  final String ePays;
  final String eContact;
  final String eTelephone1;
  final String eTelephone2;
  final String eEmail;
  final String eDateDebut;
  final String eHeureDebut;
  final String eDateFin;
  final String eHeureFin;
  final bool eCreneau;
  final String eCB;
  final bool eSignatureAuto;

  // --- Livraison (L_) ---
  final String lNom;
  final String lAdresse1;
  final String lAdresse2;
  final String lAdresse3;
  final String lCodePostal;
  final String lVille;
  final String lPays;
  final String lContact;
  final String lTelephone1;
  final String lTelephone2;
  final String lEmail;
  final String lDateDebut;
  final String lHeureDebut;
  final String lDateFin;
  final String lHeureFin;
  final bool lCreneau;
  final String lCB;
  final bool lSignatureAuto;

  // --- État de l'ordre ---
  final int idOrdre;
  final int idEtat;
  final String ediOrdre;
  final bool bEstEDIIKEA;
  final bool bEstUnService;
  final int idEtatSousOrdreSaisie;
  final int idEtatSousOrdreEnlevement;
  final int idEtatSousOrdreLivraison;
  final int idContrat;
  final String client;

  // --- Configuration photo ---
  final bool photoEnlDebut;
  final bool photoEnlFin;
  final bool photoLivDebut;
  final bool photoLivFin;
  final bool photoCBRT;
  final bool photoDocEnl;
  final bool photoDocLiv;
  final bool noscan;

  const YpsiumTransportOrder({
    required this.eNom,
    this.eAdresse1 = '',
    this.eAdresse2 = '',
    this.eAdresse3 = '',
    this.eCodePostal = '',
    this.eVille = '',
    this.ePays = '',
    this.eContact = '',
    this.eTelephone1 = '',
    this.eTelephone2 = '',
    this.eEmail = '',
    this.eDateDebut = '',
    this.eHeureDebut = '',
    this.eDateFin = '',
    this.eHeureFin = '',
    this.eCreneau = false,
    this.eCB = '',
    this.eSignatureAuto = false,
    required this.lNom,
    this.lAdresse1 = '',
    this.lAdresse2 = '',
    this.lAdresse3 = '',
    this.lCodePostal = '',
    this.lVille = '',
    this.lPays = '',
    this.lContact = '',
    this.lTelephone1 = '',
    this.lTelephone2 = '',
    this.lEmail = '',
    this.lDateDebut = '',
    this.lHeureDebut = '',
    this.lDateFin = '',
    this.lHeureFin = '',
    this.lCreneau = false,
    this.lCB = '',
    this.lSignatureAuto = false,
    required this.idOrdre,
    this.idEtat = 0,
    this.ediOrdre = '',
    this.bEstEDIIKEA = false,
    this.bEstUnService = false,
    this.idEtatSousOrdreSaisie = 0,
    this.idEtatSousOrdreEnlevement = 0,
    this.idEtatSousOrdreLivraison = 0,
    this.idContrat = 0,
    this.client = '',
    this.photoEnlDebut = false,
    this.photoEnlFin = false,
    this.photoLivDebut = false,
    this.photoLivFin = false,
    this.photoCBRT = false,
    this.photoDocEnl = false,
    this.photoDocLiv = false,
    this.noscan = false,
  });

  factory YpsiumTransportOrder.fromJson(Map<String, dynamic> json) {
    return YpsiumTransportOrder(
      eNom: json['E_Nom'] as String? ?? '',
      eAdresse1: json['E_Adresse1'] as String? ?? '',
      eAdresse2: json['E_Adresse2'] as String? ?? '',
      eAdresse3: json['E_Adresse3'] as String? ?? '',
      eCodePostal: json['E_CodePostal'] as String? ?? '',
      eVille: json['E_Ville'] as String? ?? '',
      ePays: json['E_Pays'] as String? ?? '',
      eContact: json['E_Contact'] as String? ?? '',
      eTelephone1: json['E_Telephone1'] as String? ?? '',
      eTelephone2: json['E_Telephone2'] as String? ?? '',
      eEmail: json['E_Email'] as String? ?? '',
      eDateDebut: json['E_Datedebut'] as String? ?? '',
      eHeureDebut: json['E_HeureDebut'] as String? ?? '',
      eDateFin: json['E_DateFin'] as String? ?? '',
      eHeureFin: json['E_HeureFin'] as String? ?? '',
      eCreneau: json['E_creneau'] as bool? ?? false,
      eCB: json['E_CB'] as String? ?? '',
      eSignatureAuto: json['E_bSignatureAuto'] as bool? ?? false,
      lNom: json['L_Nom'] as String? ?? '',
      lAdresse1: json['L_Adresse1'] as String? ?? '',
      lAdresse2: json['L_Adresse2'] as String? ?? '',
      lAdresse3: json['L_Adresse3'] as String? ?? '',
      lCodePostal: json['L_CodePostal'] as String? ?? '',
      lVille: json['L_Ville'] as String? ?? '',
      lPays: json['L_Pays'] as String? ?? '',
      lContact: json['L_Contact'] as String? ?? '',
      lTelephone1: json['L_Telephone1'] as String? ?? '',
      lTelephone2: json['L_Telephone2'] as String? ?? '',
      lEmail: json['L_Email'] as String? ?? '',
      lDateDebut: json['L_Datedebut'] as String? ?? '',
      lHeureDebut: json['L_HeureDebut'] as String? ?? '',
      lDateFin: json['L_DateFin'] as String? ?? '',
      lHeureFin: json['L_HeureFin'] as String? ?? '',
      lCreneau: json['L_creneau'] as bool? ?? false,
      lCB: json['L_CB'] as String? ?? '',
      lSignatureAuto: json['L_bSignatureAuto'] as bool? ?? false,
      idOrdre: json['idOrdre'] as int? ?? 0,
      idEtat: json['idEtat'] as int? ?? 0,
      ediOrdre: json['EDIOrdre'] as String? ?? '',
      bEstEDIIKEA: json['bEstEDIIKEA'] as bool? ?? false,
      bEstUnService: json['bEstUnService'] as bool? ?? false,
      idEtatSousOrdreSaisie: json['idEtatSousOrdreSaisie'] as int? ?? 0,
      idEtatSousOrdreEnlevement: json['idEtatSousOrdreEnlevement'] as int? ?? 0,
      idEtatSousOrdreLivraison: json['idEtatSousOrdreLivraison'] as int? ?? 0,
      idContrat: json['idContrat'] as int? ?? 0,
      client: json['client'] as String? ?? '',
      photoEnlDebut: json['photoEnlDebut'] as bool? ?? false,
      photoEnlFin: json['photoEnlFin'] as bool? ?? false,
      photoLivDebut: json['photoLivDebut'] as bool? ?? false,
      photoLivFin: json['photoLivFin'] as bool? ?? false,
      photoCBRT: json['photoCBRT'] as bool? ?? false,
      photoDocEnl: json['photoDocEnl'] as bool? ?? false,
      photoDocLiv: json['photoDocLiv'] as bool? ?? false,
      noscan: json['noscan'] as bool? ?? false,
    );
  }

  /// Adresse d'enlèvement formatée
  String get eAdresseComplete {
    return [eAdresse1, eAdresse2, eAdresse3, '$eCodePostal $eVille']
        .where((s) => s.trim().isNotEmpty)
        .join(', ');
  }

  /// Adresse de livraison formatée
  String get lAdresseComplete {
    return [lAdresse1, lAdresse2, lAdresse3, '$lCodePostal $lVille']
        .where((s) => s.trim().isNotEmpty)
        .join(', ');
  }

  /// Heure d'enlèvement formatée (HHmm → HH:mm)
  String get eHeureFormatted => _formatHeure(eHeureDebut);

  /// Heure de livraison formatée
  String get lHeureFormatted => _formatHeure(lHeureDebut);

  /// Libellé de l'état
  String get etatLabel {
    switch (idEtat) {
      case 0:
        return 'Nouveau';
      case 1:
        return 'Affecté';
      case 2:
        return 'En cours';
      case 3:
        return 'Planifié';
      case 4:
        return 'Enlevé';
      case 5:
        return 'Livré';
      case 6:
        return 'Terminé';
      default:
        return 'État $idEtat';
    }
  }

  /// À enlever : pas encore pris en charge
  bool get isAEnlever => idEtat <= 3;

  /// Enlevé, prêt pour la livraison
  bool get isEnleve => idEtat == 4;

  /// Livré
  bool get isLivre => idEtat >= 5;

  static String _formatHeure(String heure) {
    if (heure.length == 4) {
      return '${heure.substring(0, 2)}:${heure.substring(2)}';
    }
    return heure;
  }

  @override
  List<Object?> get props => [idOrdre];
}

// ============================================================
// VÉHICULES
// ============================================================

/// Véhicule Ypsium
class YpsiumVehicule extends Equatable {
  final int idVehicule;
  final String immatriculation;
  final int kilometrage;

  const YpsiumVehicule({
    required this.idVehicule,
    required this.immatriculation,
    this.kilometrage = 0,
  });

  factory YpsiumVehicule.fromJson(Map<String, dynamic> json) {
    return YpsiumVehicule(
      idVehicule: json['iDVehicule'] as int? ?? 0,
      immatriculation: json['Immatriculation'] as String? ?? '',
      kilometrage: json['Kilométrage'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [idVehicule];
}

/// Requête de choix véhicule
class YpsiumChoixVehiculeRequest {
  final String idChauffeur;
  final int kilometrage;
  final int idVehicule;
  final int noteEtat;
  final String commentaire;

  const YpsiumChoixVehiculeRequest({
    required this.idChauffeur,
    this.kilometrage = 0,
    required this.idVehicule,
    this.noteEtat = 3,
    this.commentaire = '',
  });

  Map<String, dynamic> toJson() => {
        'IdChauffeur': idChauffeur,
        'Kilometrage': kilometrage,
        'IDVehicule': idVehicule,
        'NoteEtat': noteEtat,
        'Commentaire': commentaire,
      };
}

// ============================================================
// RÉFÉRENTIELS
// ============================================================

/// Code anomalie Ypsium
class YpsiumAnomalie extends Equatable {
  final int id;
  final String code;
  final String designation;
  final String type;
  final String groupeAnomalie;
  final bool photo;
  final int idEDI;
  final bool degroupage;
  final bool regroup;

  const YpsiumAnomalie({
    required this.id,
    required this.code,
    required this.designation,
    required this.type,
    this.groupeAnomalie = '',
    this.photo = false,
    this.idEDI = 0,
    this.degroupage = false,
    this.regroup = false,
  });

  factory YpsiumAnomalie.fromJson(Map<String, dynamic> json) {
    return YpsiumAnomalie(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      designation: json['desi'] as String? ?? '',
      type: json['Type'] as String? ?? '',
      groupeAnomalie: json['groupeanomalie'] as String? ?? '',
      photo: json['photo'] as bool? ?? false,
      idEDI: json['idEDI'] as int? ?? 0,
      degroupage: json['degroupage'] as bool? ?? false,
      regroup: json['regroup'] as bool? ?? false,
    );
  }

  bool get isAcceptee => type == 'ACCEPTEE';
  bool get isRefusee => type == 'REFUSEE';

  @override
  List<Object?> get props => [id];
}

/// Client Ypsium
class YpsiumClient extends Equatable {
  final int id;
  final String nom;
  final String code;
  final int idEDI;

  const YpsiumClient({
    required this.id,
    required this.nom,
    this.code = '',
    this.idEDI = -1,
  });

  factory YpsiumClient.fromJson(Map<String, dynamic> json) {
    return YpsiumClient(
      id: json['id'] as int? ?? 0,
      nom: json['nom'] as String? ?? '',
      code: json['code'] as String? ?? '',
      idEDI: json['idEDI'] as int? ?? -1,
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Article du référentiel Ypsium
class YpsiumArticle extends Equatable {
  final int id;
  final String reference;
  final String designation;
  final int hauteur;
  final int largeur;
  final String longueur;
  final int poids;

  const YpsiumArticle({
    required this.id,
    required this.reference,
    required this.designation,
    this.hauteur = 0,
    this.largeur = 0,
    this.longueur = '0',
    this.poids = 0,
  });

  factory YpsiumArticle.fromJson(Map<String, dynamic> json) {
    return YpsiumArticle(
      id: json['id'] as int? ?? 0,
      reference: json['ref'] as String? ?? '',
      designation: json['des'] as String? ?? '',
      hauteur: json['haut'] as int? ?? 0,
      largeur: json['lar'] as int? ?? 0,
      longueur: (json['long'] ?? '0').toString(),
      poids: json['poids'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Lieu d'entreposage Ypsium
class YpsiumEntreposage extends Equatable {
  final int id;
  final String designation;
  final bool defaut;

  const YpsiumEntreposage({
    required this.id,
    this.designation = '',
    this.defaut = false,
  });

  factory YpsiumEntreposage.fromJson(Map<String, dynamic> json) {
    return YpsiumEntreposage(
      id: json['id'] as int? ?? 0,
      designation: json['desa'] as String? ?? '',
      defaut: json['defaut'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Emplacement de stockage Ypsium
class YpsiumEmplacement extends Equatable {
  final int id;
  final String code;
  final String codeBarre;
  final String nom;

  const YpsiumEmplacement({
    required this.id,
    this.code = '',
    this.codeBarre = '',
    this.nom = '',
  });

  factory YpsiumEmplacement.fromJson(Map<String, dynamic> json) {
    return YpsiumEmplacement(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      codeBarre: json['cb'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id];
}

/// EDI Ypsium
class YpsiumEDI extends Equatable {
  final int id;
  final String nom;

  const YpsiumEDI({required this.id, required this.nom});

  factory YpsiumEDI.fromJson(Map<String, dynamic> json) {
    return YpsiumEDI(
      id: json['id'] as int? ?? 0,
      nom: json['nom'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Type de règlement pour contre-remboursement
class YpsiumTypeReglement extends Equatable {
  final int id;
  final String type;

  const YpsiumTypeReglement({required this.id, required this.type});

  factory YpsiumTypeReglement.fromJson(Map<String, dynamic> json) {
    return YpsiumTypeReglement(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id];
}

// ============================================================
// OPÉRATIONS
// ============================================================

/// Requête d'ajout de colis au chargement
class YpsiumAddColisRequest {
  final String codeBarre;
  final String refArticle;
  final String designation;
  final int quantite;
  final String dhChargement;
  final String codeChauffeur;
  final int poids;
  final int hauteur;
  final int longueur;
  final int largeur;

  const YpsiumAddColisRequest({
    this.codeBarre = '',
    required this.refArticle,
    required this.designation,
    this.quantite = 1,
    required this.dhChargement,
    required this.codeChauffeur,
    this.poids = 0,
    this.hauteur = 0,
    this.longueur = 0,
    this.largeur = 0,
  });

  Map<String, dynamic> toJson() => {
        'codeBarre': codeBarre,
        'refArticle': refArticle,
        'designation': designation,
        'quantite': quantite,
        'dhChargement': dhChargement,
        'codeChauffeur': codeChauffeur,
        'poids': poids,
        'hauteur': hauteur,
        'longueur': longueur,
        'largeur': largeur,
      };
}

/// Requête de validation d'enlèvement
class YpsiumSetPointEnleveRequest {
  final String nomRemettant;
  final String heureArriveeSurSite;
  final String heureDepartSite;
  final String? signature;
  final List<dynamic> prestationSupp;

  const YpsiumSetPointEnleveRequest({
    required this.nomRemettant,
    required this.heureArriveeSurSite,
    required this.heureDepartSite,
    this.signature,
    this.prestationSupp = const [],
  });

  Map<String, dynamic> toJson() => {
        'prestationSupp': prestationSupp,
        'nomRemettant': nomRemettant,
        'heureArriveeSurSite': heureArriveeSurSite,
        'heureDepartSite': heureDepartSite,
        if (signature != null) 'Signature': signature,
      };
}

/// Requête de position GPS
class YpsiumGpsRequest {
  final int idOrdre;
  final String idChauffeur;
  final int idVehicule;
  final double altitude;
  final bool altitudeValide;
  final String dateMesure;
  final double direction;
  final bool directionValide;
  final double latitude;
  final double longitude;
  final bool positionValide;
  final double precision;
  final bool precisionValide;
  final double vitesse;
  final bool vitesseValide;

  const YpsiumGpsRequest({
    this.idOrdre = 0,
    required this.idChauffeur,
    this.idVehicule = 0,
    this.altitude = 0,
    this.altitudeValide = true,
    required this.dateMesure,
    this.direction = 0,
    this.directionValide = true,
    required this.latitude,
    required this.longitude,
    this.positionValide = true,
    this.precision = 0,
    this.precisionValide = true,
    this.vitesse = 0,
    this.vitesseValide = true,
  });

  Map<String, dynamic> toJson() => {
        'idOrdre': idOrdre,
        'idChauffeur': idChauffeur,
        'idVehicule': idVehicule,
        'Altitude': altitude,
        'AltitudeValide': altitudeValide,
        'DateMesure': dateMesure,
        'Direction': direction,
        'DirectionValide': directionValide,
        'Latitude': latitude,
        'Longitude': longitude,
        'PositionValide': positionValide,
        'Precision': precision,
        'PrecisionValide': precisionValide,
        'Vitesse': vitesse,
        'VitesseValide': vitesseValide,
      };
}

// ============================================================
// DONNÉES RÉFÉRENTIELLES AGRÉGÉES
// ============================================================

/// Ensemble des données de référence chargées après login
class YpsiumReferentielData {
  final List<YpsiumAnomalie> anomalies;
  final List<YpsiumClient> clients;
  final List<YpsiumArticle> articles;
  final List<YpsiumEntreposage> entreposages;
  final List<YpsiumEmplacement> emplacements;
  final List<YpsiumEDI> edis;
  final List<YpsiumTypeReglement> typesReglement;

  const YpsiumReferentielData({
    this.anomalies = const [],
    this.clients = const [],
    this.articles = const [],
    this.entreposages = const [],
    this.emplacements = const [],
    this.edis = const [],
    this.typesReglement = const [],
  });
}

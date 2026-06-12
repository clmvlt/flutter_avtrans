import 'dart:io';
import 'dart:ui' show Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Heuristiques d'extraction d'adresse à partir d'un texte reconnu par OCR.
///
/// Utilisé par le scanner d'adresses en temps réel : à chaque image analysée,
/// [extractAddress] reconstruit une requête d'adresse exploitable par le
/// geocoding (ligne « rue » + ligne « code postal + ville »).
abstract class AddressOcrService {
  /// La reconnaissance de texte ML Kit n'existe que sur Android et iOS.
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  static final RegExp _postcode = RegExp(r'\b\d{5}\b');
  static final RegExp _streetKeyword = RegExp(
    r'\b(rue|avenue|av|bd|boulevard|impasse|imp|chemin|che|route|rte|all[ée]e|'
    r'place|pl|quai|cours|lotissement|lot|residence|résidence|square|voie|'
    r'passage|sentier|hameau|lieu[- ]?dit|zone|za|zi|zac)\b',
    caseSensitive: false,
  );
  static final RegExp _startsWithNumber = RegExp(r'^\s*\d');

  /// Reconstruit la meilleure requête d'adresse à partir du texte reconnu.
  ///
  /// Si [accept] est fourni, seules les lignes dont la boîte englobante est
  /// acceptée par le prédicat sont prises en compte — cela permet à l'appelant
  /// de limiter le scan au viseur (le calcul de coordonnées dépend de la
  /// plateforme et de l'orientation, il reste donc côté presentation).
  ///
  /// Renvoie une chaîne vide si rien d'exploitable n'a été détecté.
  static String extractAddress(
    RecognizedText recognized, {
    bool Function(Rect box)? accept,
  }) {
    final lines = <String>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        if (accept != null && !accept(line.boundingBox)) continue;
        final text = line.text.trim();
        if (text.isNotEmpty) lines.add(text);
      }
    }
    if (lines.isEmpty) return '';

    // Ligne « code postal + ville ».
    final cityLine = lines.firstWhere(
      (l) => _postcode.hasMatch(l),
      orElse: () => '',
    );

    // Ligne « rue » : commence par un numéro ou contient un mot-clé de voie.
    final streetLine = lines.firstWhere(
      (l) =>
          l != cityLine &&
          (_startsWithNumber.hasMatch(l) || _streetKeyword.hasMatch(l)),
      orElse: () => '',
    );

    final parts = <String>[
      if (streetLine.isNotEmpty) streetLine,
      if (cityLine.isNotEmpty) cityLine,
    ];

    // On n'accepte un résultat que s'il contient au moins une structure
    // d'adresse claire (rue ET/OU code postal). Sinon, le texte ambiant
    // (panneaux, enseignes…) produirait des requêtes parasites.
    if (parts.isEmpty) return '';

    return parts.join(', ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

import 'package:dartz/dartz.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/errors/failures.dart';
import '../../../../data/models/entretien_model.dart';

/// Types et dossiers d'entretien, chargés ensemble et gardés en mémoire le
/// temps de la session : ils changent rarement et servent partout (sélecteur
/// du formulaire, filtres, suivis). [invalidate] après toute modification.
class EntretienCatalog {
  const EntretienCatalog({required this.types, required this.dossiers});

  final List<TypeEntretien> types;
  final List<DossierTypeEntretien> dossiers;

  static EntretienCatalog? _cache;

  /// Charge (ou relit le cache). Un échec des dossiers n'empêche pas
  /// d'utiliser les types : la liste des dossiers est alors vide.
  static Future<Either<Failure, EntretienCatalog>> load({
    bool force = false,
  }) async {
    if (!force && _cache != null) return Right(_cache!);

    final results = await Future.wait([
      sl.entretienRepository.getTypes(),
      sl.entretienRepository.getDossiers(),
    ]);
    final types = results[0] as Either<Failure, List<TypeEntretien>>;
    final dossiers = results[1] as Either<Failure, List<DossierTypeEntretien>>;

    return types.fold(Left.new, (t) {
      final catalog = EntretienCatalog(
        types: t,
        dossiers: dossiers.getOrElse(() => const []),
      );
      _cache = catalog;
      return Right(catalog);
    });
  }

  static void invalidate() => _cache = null;

  /// Types d'un dossier (`null` = non classés).
  List<TypeEntretien> typesIn(String? dossierId) =>
      types.where((t) => t.dossier?.id == dossierId).toList();

  int countIn(String? dossierId) =>
      types.where((t) => t.dossier?.id == dossierId).length;
}

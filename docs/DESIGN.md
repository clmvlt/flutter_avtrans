# Design de l'app : le modèle « page Pointage »

La page Pointage (`lib/presentation/screens/services/`) fixe le style de toute l'app. Toute page doit s'y lire comme une sœur : même calme, même hiérarchie, mêmes composants. L'app est utilisée par des chauffeurs et des mécaniciens sur téléphone, souvent d'une main : **simple, lisible, pratique**.

## Principes

1. **Un seul point focal par page** : une carte hero en haut qui dit l'état ou le chiffre qui compte (« En service », « 2 véhicules en retard », « 3 jours posés »). Pas de grille de tuiles, pas de tableau de bord chargé.
2. **L'action principale vit dans le dock**, en bas, dans la zone du pouce. Son libellé dit l'action (« Demander une absence », « Enregistrer l'entretien »), jamais « OK » ni « Valider » seul. Un ou deux boutons au maximum. Pas de FloatingActionButton.
3. **Le contraste avant la teinte** : le texte reste en `foreground` / `mutedForeground`. La couleur est portée par l'icône (boîte d'icône teintée, pastille). Un état = icône + mot, jamais la couleur seule. Pas de carte à fond teinté pour un état normal.
4. **Le silence est la récompense** : un bloc d'alerte (callout) n'apparaît que s'il y a quelque chose à faire.
5. **Pas de dialog au montage, pas de snackbar** : les erreurs d'action s'affichent dans le dock (`DockNoticeMixin`), un succès se voit au changement d'état de la page. Les confirmations et les détails passent par des **feuilles** (bottom sheets), pas des `AlertDialog`.
6. **Chaque écran gère ses états** : chargement (squelette à la géométrie du contenu), erreur (sous le titre, avec « Réessayer »), vide explicite, succès.
7. **Ton** : tutoiement, phrases courtes, casse de phrase (« Nouvel entretien », pas « Nouvel Entretien »). Accessibilité : cibles de 48 dp min, `Semantics` sur les éléments composites.

## Gabarit d'une page

```dart
class _XxxScreenState extends State<XxxScreen> with DockNoticeMixin {
  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Absences',                       // nom de la page, à gauche
      actions: [AppIconButton(icon: …, tooltip: …, color: context.colors.foreground, onPressed: …)],
      body: AppScrollView(                     // ou AppListView pour une longue liste
        onRefresh: _load,
        children: [
          AppHeroCard(…),                      // le point focal
          const SizedBox(height: AppSpacing.lg),
          const AppSectionHeader(title: 'À venir', summary: '2 demandes'),
          AppCard(padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs), child: Column(children: [AppListRow(…), …])),
        ],
      ),
      dock: AppDock(
        actions: [DockAction(label: 'Demander une absence', icon: Icons.add_rounded, onPressed: _create)],
        notice: dockNotice,
        onDismissNotice: clearDockNotice,
      ),
    );
  }
}
```

- Colonne de contenu : 480 dp max, centrée, marge d'écran 20 dp (`AppLayout`, `AppScrollView`, `AppListView`). Le bas réserve la hauteur du dock et de la tab bar (`MediaQuery.paddingOf(context).bottom`), déjà géré par ces corps.
- Espacements : 24 dp (`AppSpacing.lg`) entre blocs, 12 dp (`md`) entre un en-tête de section et son contenu (inclus dans `AppSectionHeader`), 12 dp entre cartes d'une liste.
- Onglets : `AppSegmented` (2 à 4 choix), placé dans le corps sous le hero, ou dans `AppPage.bottom` via `AppPageBar`. Pas de `TabBar` Material.
- Filtres et recherche : un champ de recherche en tête de liste, les filtres dans une feuille (`AppSheet`) ouverte par une action de la barre de titre (icône `tune_rounded`), avec un compteur de filtres actifs visible.
- Écran de formulaire long : page plein écran (`fullscreenDialog: true`), champs empilés, bouton d'enregistrement dans le dock. Formulaire court (1 à 3 champs) : feuille.

## Composants (lib/presentation/widgets, barrel `widgets.dart`)

| Besoin | Composant |
|---|---|
| Page | `AppPage` (Scaffold + barre de titre + dock), `AppScrollView`, `AppListView`, `AppPageBar` |
| Point focal | `AppHeroCard` (ligne d'état + contenu), `AppHeroFigure` (grand chiffre 52 sp), `AppMetric` / `AppMetricRow` |
| Action principale / erreurs d'action | `AppDock` + `DockAction` (`DockTone.primary/success/soft/danger/secondary`), `DockNoticeMixin` |
| Titre de section | `AppSectionHeader` (titre, résumé ou lien à droite) |
| Ligne de liste | `AppListRow` (56 dp, `AppIconBox` 40, titre, sous-ligne, accessoire, chevron) dans une `AppCard` |
| Groupe de réglages | `AppSection` + `AppTile` (titre en petites capitales) |
| Alerte « à faire » | `AppCalloutCard` (`info/warning/danger/success`) |
| État | `AppStatusChip` (icône teintée + mot), `AppBadge` pour un compteur |
| Confirmation | `AppConfirmSheet.show(...)` → `bool` ; récapitulatif : `AppRecapBox` / `AppRecapRow` |
| Détail / formulaire court | `AppSheet.show(...)` |
| Chargement | `AppHeroSkeleton`, `AppListSkeleton`, `AppSkeleton` |
| Erreur de chargement | `AppErrorState(message:, onRetry:)` sous le titre |
| Vide | `AppEmptyCard` (dans une page), `AppEmptyState` (page entière vide) |
| Champs | `AppTextField`, `AppPickerField`, `AppDateField`, `AppSearchableSelect`, `AppFieldLabel`, `showAppSelectSheet` |
| Boutons | `AppButton` (`ButtonSize.lg` = 56 dp dans le dock et les feuilles), `AppIconButton` |
| Formats | `DisplayFormat` (dates « 12 mars 2025 », `km`, `euros`, `fileSize`, `plural`), `TimeFormat` (durées) |

## Couleurs et typo

- Toujours `context.colors` (`AppColors`) et `Theme.of(context).textTheme`. Aucune couleur en dur (`Colors.red.shade700` interdit), aucune taille de police en dur sauf cas justifié.
- Accents par domaine : `domainPointage` (bleu), `domainHours` (vert), `domainAbsence` (ambre), `domainAcompte` (violet), `domainVehicule` (ardoise), `domainYpsium` (cyan). États : `success`, `warning`, `destructive`, `info`, et leurs fonds `…Muted`.
- Hiérarchie : `headlineSmall` (mot d'état du hero), `titleMedium` (en-tête de section), `titleSmall` (titre de ligne), `bodySmall` (sous-ligne, libellés), `displayLarge` (grand chiffre tabulaire).
- Rayons : cartes `AppRadius.lg`, hero et feuilles `AppRadius.xl`, champs et boîtes d'icône `AppRadius.md`.

## Rôles

Les rôles se comparent par UUID (`RoleIds`, `User.isAdmin`, `User.isMecanicien`, `User.canManageFleet`), jamais par nom. L'atelier (entretiens, types d'entretien, tâches) est réservé à l'Administrateur et au Mécanicien (`canManageFleet`), comme l'API.

## Vérifier un écran sans appareil

`test/visual/` rend de vrais écrans avec une API simulée (`FakeApi`, `sl.initForTesting`) et enregistre des PNG dans `build/visual/` :

```bash
VISUAL=1 flutter test test/visual
```

Sans `VISUAL=1`, ces tests sont ignorés (ils ne tournent pas avec la suite normale). Pour un nouvel écran : ajouter ses routes à `fake_app_data.dart` (les chemins non simulés sont listés dans la sortie), puis l'écran à `app_visual_test.dart`. Les ombres floues n'y sont pas rendues (bande grise sous les cartes) : c'est une limite du moteur de test, pas un défaut.

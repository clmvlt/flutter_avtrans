# AV Pointage

Application mobile de pointage et gestion du temps de travail pour **AVTRANS**.

## Fonctionnalités

- Pointage de services (prise/fin de service, pauses)
- Historique et suivi des heures travaillées
- Gestion des absences (demandes, suivi)
- Demandes d'acomptes
- Gestion de flotte véhicules (kilométrages, fichiers, ajustements)
- Rapports véhicules
- Signatures numériques
- Géolocalisation au pointage
- Mise à jour automatique de l'APK
- Mode sombre / clair

## Prérequis

- Flutter SDK (stable)
- Dart SDK ^3.9.0

## Installation

```bash
# 1. Cloner le projet
git clone <url-du-repo>
cd flutter_avtrans

# 2. Copier le fichier d'environnement et renseigner les valeurs
cp .env.example .env

# 3. Installer les dépendances
flutter pub get
```

## Configuration

Le fichier `.env` contient la configuration de l'application :

| Variable | Description |
|---|---|
| `API_DEBUG_BASE_URL` | URL de l'API en développement (ex: `http://localhost:8081`) |
| `API_PROD_BASE_URL` | URL de l'API en production |
| `API_UPLOAD_TOKEN` | Token d'authentification pour le script d'upload |
| `MAPBOX_TOKEN` | Token public Mapbox pour les tuiles de carte |
| `GOOGLE_WEB_CLIENT_ID` | Client OAuth *Web* Google : audience de l'ID token vérifiée par l'API |
| `GOOGLE_IOS_CLIENT_ID` | Client OAuth *iOS* Google (bundle `bzh.stack.avtrans`), iOS uniquement |

### Google Sign-In sur iOS

Le client OAuth *iOS* doit être connu du SDK natif (`GIDClientID` et schéma
URL de retour dans `ios/Runner/Info.plist`) et du code Dart (`.env`). Une
seule commande reporte la valeur partout :

```bash
./configure_google_ios.sh 703495171118-xxxxxxxx.apps.googleusercontent.com
# ou, depuis le fichier téléchargé sur Google Cloud :
./configure_google_ios.sh ~/Downloads/GoogleService-Info.plist
```

## Lancer l'application

```bash
flutter run                # Device par défaut
flutter run -d chrome      # Web
flutter run -d windows     # Windows
```

## Build

```bash
flutter build apk          # Android APK (release)
flutter build ios          # iOS
flutter build web          # Web
```

## Upload APK

Le script `upload.py` build et upload l'APK sur l'API :

```bash
python upload.py                        # Upload interactif
python upload.py "Correction de bugs"   # Avec changelog
```

## Architecture

```
lib/
├── main.dart                 # Point d'entrée
├── core/
│   ├── constants/            # Configuration API, endpoints
│   ├── di/                   # Injection de dépendances (ServiceLocator)
│   ├── errors/               # Exceptions et Failures
│   ├── services/             # Services transverses (localisation, updates)
│   └── theme/                # Thème et couleurs
├── data/
│   ├── models/               # Modèles de données
│   ├── repositories/         # Implémentation des repositories
│   └── services/             # HTTP, stockage tokens, téléchargements
└── presentation/
    ├── screens/              # Pages de l'application
    └── widgets/              # Composants réutilisables
```

## Stack technique

| Composant | Technologie |
|---|---|
| Framework | Flutter |
| State management | Provider |
| HTTP | `http` + `HttpService` custom |
| Auth | JWT (SharedPreferences) |
| Navigation | Navigator 1.0 |
| Env | `flutter_dotenv` |
| Functional | `dartz` (Either/Failure) |

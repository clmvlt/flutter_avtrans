#!/usr/bin/env bash
# Configure Google Sign-In côté iOS en une commande.
#
# Usage :
#   ./configure_google_ios.sh <IOS_CLIENT_ID>
#   ./configure_google_ios.sh <chemin/vers/GoogleService-Info.plist>
#
# <IOS_CLIENT_ID> est le client OAuth de type *iOS* créé dans Google Cloud
# (console.cloud.google.com → APIs & Services → Credentials) pour le bundle
# bzh.stack.avtrans. Forme : 703495171118-xxxxxxxx.apps.googleusercontent.com
#
# Le script reporte cette valeur aux trois endroits attendus :
#   1. ios/Runner/Info.plist  → GIDClientID            (lu par le SDK natif)
#   2. ios/Runner/Info.plist  → CFBundleURLSchemes[0]  (REVERSED_CLIENT_ID :
#      schéma de retour OAuth, sans lui le SDK refuse d'ouvrir la connexion)
#   3. .env                   → GOOGLE_IOS_CLIENT_ID    (lu côté Dart, passé
#      en `clientId` à GoogleSignIn.initialize)
#
# Le client *Web* (GOOGLE_WEB_CLIENT_ID / GIDServerClientID) est déjà en place :
# il fixe l'audience de l'ID token attendue par l'API et ne change pas.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST="$ROOT/ios/Runner/Info.plist"
ENV_FILE="$ROOT/.env"
PB=/usr/libexec/PlistBuddy

if [[ $# -ne 1 ]]; then
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi
if [[ ! -x "$PB" ]]; then
  echo "Erreur : PlistBuddy introuvable — ce script doit tourner sur macOS." >&2
  exit 1
fi

INPUT="$1"
if [[ -f "$INPUT" ]]; then
  CLIENT_ID="$($PB -c 'Print :CLIENT_ID' "$INPUT")"
  BUNDLE_IN_PLIST="$($PB -c 'Print :BUNDLE_ID' "$INPUT" 2>/dev/null || true)"
  if [[ -n "$BUNDLE_IN_PLIST" && "$BUNDLE_IN_PLIST" != "bzh.stack.avtrans" ]]; then
    echo "Attention : ce GoogleService-Info.plist vise le bundle '$BUNDLE_IN_PLIST', l'app utilise 'bzh.stack.avtrans'." >&2
  fi
else
  CLIENT_ID="$INPUT"
fi

if [[ ! "$CLIENT_ID" =~ ^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$ ]]; then
  echo "Erreur : '$CLIENT_ID' ne ressemble pas à un client OAuth Google (xxx-yyy.apps.googleusercontent.com)." >&2
  exit 1
fi

# REVERSED_CLIENT_ID = segments du client ID inversés (séparateur '.').
REVERSED="$(echo "$CLIENT_ID" | awk -F. '{ for (i = NF; i > 0; i--) printf "%s%s", $i, (i > 1 ? "." : "") }')"

# 1 + 2 : Info.plist
$PB -c "Set :GIDClientID $CLIENT_ID" "$PLIST" 2>/dev/null \
  || $PB -c "Add :GIDClientID string $CLIENT_ID" "$PLIST"
$PB -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $REVERSED" "$PLIST"
plutil -lint "$PLIST" >/dev/null

# 3 : .env (créé depuis .env.example s'il manque)
if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ROOT/.env.example" "$ENV_FILE"
fi
if grep -q '^GOOGLE_IOS_CLIENT_ID=' "$ENV_FILE"; then
  # sed -i portable macOS/BSD : suffixe de sauvegarde vide obligatoire.
  sed -i '' "s|^GOOGLE_IOS_CLIENT_ID=.*|GOOGLE_IOS_CLIENT_ID=$CLIENT_ID|" "$ENV_FILE"
else
  printf '\n# Client OAuth *iOS* (bundle bzh.stack.avtrans)\nGOOGLE_IOS_CLIENT_ID=%s\n' "$CLIENT_ID" >> "$ENV_FILE"
fi

cat <<MSG
Google Sign-In iOS configuré :
  GIDClientID (Info.plist)          $CLIENT_ID
  CFBundleURLSchemes (Info.plist)   $REVERSED
  GOOGLE_IOS_CLIENT_ID (.env)       $CLIENT_ID

Relancer l'app (flutter run) pour que le nouveau .env soit embarqué.
MSG

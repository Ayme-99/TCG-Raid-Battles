#!/usr/bin/env bash
# Instala Flutter (incluye Dart) en el Codespace y deja listas las dependencias.
# Se ejecuta una vez, al crear el Codespace.
set -euo pipefail

# Misma versión que el CI (.github/workflows/ci.yml): Flutter 3.50 hace fallar
# `flutter analyze`. Súbela aquí y en el CI a la vez.
FLUTTER_VERSION="3.47.9"
FLUTTER_DIR="$HOME/flutter"
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

# PATH para esta y las próximas terminales.
LINEA='export PATH="$HOME/flutter/bin:$HOME/flutter/bin/cache/dart-sdk/bin:$PATH"'
grep -qxF "$LINEA" "$HOME/.bashrc" || echo "$LINEA" >> "$HOME/.bashrc"
export PATH="$HOME/flutter/bin:$HOME/flutter/bin/cache/dart-sdk/bin:$PATH"

flutter config --no-analytics >/dev/null
flutter config --enable-web >/dev/null
flutter precache --web

for d in engine sim app; do
  (cd "$d" && if [ "$d" = app ]; then flutter pub get; else dart pub get; fi)
done
(cd server && npm ci --silent)
echo "Listo: ejecuta 'cd app && flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0'"

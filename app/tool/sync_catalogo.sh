#!/usr/bin/env sh
# Copia el catálogo de jefes (catalog/) a los assets de la app. Flutter solo
# empaqueta archivos de dentro de app/, así que hay una copia. El test
# app/test/catalogo_test.dart comprueba que no se desincroniza.
set -e
cd "$(dirname "$0")/.."
rm -rf assets/catalogo
mkdir -p assets/catalogo/bosses
cp ../catalog/catalogo.json assets/catalogo/
cp ../catalog/bosses/*.json assets/catalogo/bosses/
echo "Catálogo copiado a app/assets/catalogo"

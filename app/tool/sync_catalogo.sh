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

# Catálogo de campaña (D-20): Pokémon, zonas, jefes y regiones.
for carpeta in pokemon zonas jefes regiones; do
  mkdir -p assets/catalogo/campana/$carpeta
  cp ../catalog/campana/$carpeta/*.json assets/catalogo/campana/$carpeta/
done
echo "Catálogo de campaña copiado a app/assets/catalogo/campana"

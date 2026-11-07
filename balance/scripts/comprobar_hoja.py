#!/usr/bin/env python3
"""Comprueba que balance/hoja_balance.xlsx está al día.

Regenera la hoja en una carpeta temporal y compara, pestaña por pestaña, los
valores de las celdas con la hoja subida. Se comparan los datos y el texto de
las fórmulas, no los bytes ni el formato (varían entre versiones de la
librería). Sale con código 1 y explica cómo arreglarlo si no coinciden.
"""
import pathlib, subprocess, sys, tempfile
from openpyxl import load_workbook

RAIZ = pathlib.Path(__file__).resolve().parents[2]
SUBIDA = RAIZ / 'balance' / 'hoja_balance.xlsx'


def contenido(ruta):
    libro = load_workbook(ruta)  # fórmulas como texto, sin valores calculados
    datos = {}
    for hoja in libro.worksheets:
        for fila in hoja.iter_rows():
            for celda in fila:
                v = celda.value
                if v is None:
                    continue
                if isinstance(v, str) and v.startswith('='):
                    v = v.replace(' ', '').upper()
                elif isinstance(v, float) and v.is_integer():
                    v = int(v)
                datos[(hoja.title, celda.coordinate)] = v
    return datos


def main():
    with tempfile.TemporaryDirectory() as tmp:
        nueva = pathlib.Path(tmp) / 'hoja.xlsx'
        subprocess.run([sys.executable, str(RAIZ / 'balance' / 'scripts' / 'generar_hoja.py'), str(nueva)],
                       check=True, stdout=subprocess.DEVNULL)
        a, b = contenido(SUBIDA), contenido(nueva)
    distintas = sorted(k for k in set(a) | set(b) if a.get(k) != b.get(k))
    if not distintas:
        print('La hoja de balance está al día.')
        return 0
    print('balance/hoja_balance.xlsx NO está al día con catalog/ y balance/tablas/.')
    print('Regénerala con: python3 balance/scripts/generar_hoja.py')
    print('y recalcula las fórmulas (ver el docstring de generar_hoja.py).')
    print(f'Celdas distintas ({len(distintas)}), las primeras:')
    for hoja, coord in distintas[:10]:
        print(f'  {hoja}!{coord}: subida={a.get((hoja, coord))!r} esperada={b.get((hoja, coord))!r}')
    return 1


sys.exit(main())

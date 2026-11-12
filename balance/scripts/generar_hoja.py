#!/usr/bin/env python3
"""Genera balance/hoja_balance.xlsx desde catalog/ y balance/tablas/niveles.csv.

La hoja es de SOLO LECTURA: el JSON del catálogo manda. Para cambiar una cifra,
edita el JSON y vuelve a ejecutar este script:

    python3 balance/scripts/generar_hoja.py

Después recalcula las fórmulas (LibreOffice) para que la hoja traiga valores:

    soffice --headless --convert-to xlsx --outdir /tmp/hoja balance/hoja_balance.xlsx
"""
import csv, json, pathlib, sys
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.formatting.rule import FormulaRule
from openpyxl.utils import get_column_letter

RAIZ = pathlib.Path(__file__).resolve().parents[2]
SALIDA = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else RAIZ / 'balance' / 'hoja_balance.xlsx'
FUENTE = 'Arial'
CATEGORIAS = ['danio', 'tanque', 'cura', 'control', 'potenciador', 'debilitador']

indice = json.loads((RAIZ / 'catalog' / 'catalogo.json').read_text('utf-8'))
jefes = [json.loads((RAIZ / 'catalog' / 'bosses' / f'{i}.json').read_text('utf-8')) for i in indice['jefes']]
jefes.sort(key=lambda j: (j['nivel'], j['id']))
niveles = list(csv.DictReader((RAIZ / 'balance' / 'tablas' / 'niveles.csv').open(encoding='utf-8')))

NEGRITA = Font(name=FUENTE, bold=True, color='FFFFFF')
CABECERA = PatternFill('solid', fgColor='305496')
NORMAL = Font(name=FUENTE)
AZUL = Font(name=FUENTE, color='0000FF')  # dato de entrada (viene del JSON/CSV)
AMARILLO = PatternFill('solid', fgColor='FFFF00')

wb = Workbook()


def cabecera(ws, fila, titulos):
    for c, t in enumerate(titulos, 1):
        cel = ws.cell(row=fila, column=c, value=t)
        cel.font, cel.fill = NEGRITA, CABECERA
        cel.alignment = Alignment(horizontal='center', vertical='center', wrap_text=True)
    ws.freeze_panes = ws.cell(row=fila + 1, column=1)


def anchos(ws, valores):
    for i, w in enumerate(valores, 1):
        ws.column_dimensions[get_column_letter(i)].width = w


def estilo(ws):
    for fila in ws.iter_rows():
        for cel in fila:
            if cel.font == Font() or cel.font.name != FUENTE:
                cel.font = NORMAL


# --- Léeme -----------------------------------------------------------------
ws = wb.active
ws.title = 'Leeme'
texto = [
    ('Hoja de balance de los jefes (solo lectura)', True),
    ('Generada por balance/scripts/generar_hoja.py desde catalog/ y balance/tablas/niveles.csv.', False),
    ('El JSON del catálogo manda: para cambiar una cifra, edita el JSON y vuelve a generar la hoja.', False),
    (f'Versión del catálogo: {indice["version"]}', False),
    ('Texto azul = dato copiado del JSON o del CSV. Texto negro = fórmula.', False),
    ('', False),
    ('Tolerancia del poder frente al objetivo (±):', True),
]
for i, (t, b) in enumerate(texto, 1):
    ws.cell(row=i, column=1, value=t).font = Font(name=FUENTE, bold=b)
ws['B7'] = 0.25
ws['B7'].number_format = '0%'
ws['B7'].font, ws['B7'].fill = AZUL, AMARILLO
ws['A8'] = ('Supuesto mío, sin decisión previa: un jefe cuyo poder se desvía más de esta tolerancia del objetivo '
            '(1,5 × x_centro², balance/tablas/README.md) sale marcado «Revisar». Cámbialo aquí. La comparación del estado es contra el poder de referencia del nivel (calibrado con cartas reales, niveles.csv); el cociente contra 1,5 × x_centro² se muestra solo como dato, porque las referencias provisionales ya lo superan en torno a 1,5 veces.')
ws['A8'].alignment = Alignment(wrap_text=True, vertical='top')
ws.merge_cells('A8:H8')
ws.row_dimensions[8].height = 45
anchos(ws, [52, 12, 12, 12, 12, 12, 12, 12])

# --- Niveles (referencia) --------------------------------------------------
wn = wb.create_sheet('Niveles')
cabecera(wn, 1, ['Nivel', 'x_centro', 'HP de referencia', 'Ataque 1', 'Ataque 2', 'Ataque 3',
                 'Máx. ataques/turno (supuesto del simulador)', 'Amenaza esperada', 'Poder de referencia',
                 'Poder objetivo (1,5 × x_centro²)', 'Estado'])
for r, n in enumerate(niveles, 2):
    vals = [int(n['nivel']), int(n['x_centro']), int(n['hp']), int(n['ataque1']), int(n['ataque2']),
            int(n['ataque3']), int(n['max_ataques_turno']), int(n['amenaza_esperada']), None, None, n['estado']]
    for c, v in enumerate(vals, 1):
        cel = wn.cell(row=r, column=c, value=v)
        if v is not None:
            cel.font = AZUL
    wn.cell(row=r, column=9, value=f'=C{r}*H{r}').number_format = '#,##0'
    wn.cell(row=r, column=10, value=f'=1.5*B{r}^2').number_format = '#,##0'
    for c in (2, 3):
        wn.cell(row=r, column=c).number_format = '#,##0'
ultimo_nivel = len(niveles) + 1
anchos(wn, [8, 10, 14, 10, 10, 10, 22, 14, 18, 22, 52])
wn.row_dimensions[1].height = 48

# --- Jefes -----------------------------------------------------------------
wj = wb.create_sheet('Jefes')
cabecera(wj, 1, ['Jefe', 'Nombre', 'Nivel', 'HP', 'Ataque 1', 'Ataque 2', 'Ataque 3', 'Ataque medio',
                 'Llama aliados', 'Nº de carta', 'Llamadas de aliado (nivel + 1)', 'Amenaza esperada del nivel',
                 'Poder (HP × amenaza)', 'Poder objetivo del nivel (1,5 × x²)', 'Poder / objetivo', 'Poder de referencia del nivel', 'Poder / referencia', 'Estado'])
for r, j in enumerate(jefes, 2):
    inv = j.get('invocacion')
    vals = [j['id'], j['nombre'], j['nivel'], j['hp']] + [a['dano'] for a in j['ataques']]
    for c, v in enumerate(vals, 1):
        cel = wj.cell(row=r, column=c, value=v)
        cel.font = AZUL
    wj.cell(row=r, column=8, value=f'=AVERAGE(E{r}:G{r})').number_format = '0.0'
    # T-69: el jefe llama a un aliado por turnos, hasta nivel + 1 veces; el HP
    # ya no influye (`cadaHp` y `tirada` del JSON están obsoletos).
    wj.cell(row=r, column=9, value='sí' if inv else 'no').font = AZUL
    if j.get('numero') is not None:
        wj.cell(row=r, column=10, value=j['numero']).font = AZUL
    if inv:
        wj.cell(row=r, column=11, value=f'=C{r}+1')
    else:
        wj.cell(row=r, column=11, value=0).font = AZUL
    rng = f'Niveles!$A$2:$A${ultimo_nivel}'
    wj.cell(row=r, column=12, value=f'=INDEX(Niveles!$H$2:$H${ultimo_nivel},MATCH(C{r},{rng},0))')
    wj.cell(row=r, column=13, value=f'=D{r}*L{r}').number_format = '#,##0'
    wj.cell(row=r, column=14, value=f'=INDEX(Niveles!$J$2:$J${ultimo_nivel},MATCH(C{r},{rng},0))').number_format = '#,##0'
    wj.cell(row=r, column=15, value=f'=M{r}/N{r}').number_format = '0.00'
    wj.cell(row=r, column=16, value=f'=INDEX(Niveles!$I$2:$I${ultimo_nivel},MATCH(C{r},{rng},0))').number_format = '#,##0'
    wj.cell(row=r, column=17, value=f'=M{r}/P{r}').number_format = '0.00'
    wj.cell(row=r, column=18, value=f'=IF(ABS(Q{r}-1)<=Leeme!$B$7,"OK","Revisar")')
    wj.cell(row=r, column=4).number_format = '#,##0'
anchos(wj, [12, 14, 8, 10, 10, 10, 10, 12, 12, 14, 14, 16, 18, 20, 12, 18, 12, 12])
wj.row_dimensions[1].height = 48
fin = len(jefes) + 1
wj.conditional_formatting.add(f'R2:R{fin}', FormulaRule(formula=['R2="Revisar"'], fill=PatternFill('solid', bgColor='FFC7CE')))
wj.conditional_formatting.add(f'R2:R{fin}', FormulaRule(formula=['R2="OK"'], fill=PatternFill('solid', bgColor='C6EFCE')))

# --- Aliados ---------------------------------------------------------------
wa = wb.create_sheet('Aliados')
cabecera(wa, 1, ['Jefe', 'Categoría', 'Aliado', 'HP', 'HP aliado / HP jefe', 'Ataque', 'Daño', 'Efectos', 'Habilidad',
                 'Nº de carta', 'Efecto del ataque', 'Script'])
r = 2
for fila_jefe, j in enumerate(jefes, 2):
    inv = j.get('invocacion')
    if not inv:
        continue
    for cat in CATEGORIAS:
        if cat not in inv['aliados']:  # provisional (D-16): aún sin potenciador/debilitador
            continue
        a = inv['aliados'][cat]
        vals = [j['id'], cat, a['nombre'], a['hp'], None, a.get('ataque', {}).get('nombre'),
                a.get('ataque', {}).get('dano'), a.get('efectos', 'jugador'), a.get('habilidad'),
                a.get('numero'), a.get('ataque', {}).get('texto'), a.get('scriptId')]
        for c, v in enumerate(vals, 1):
            if v is not None:
                wa.cell(row=r, column=c, value=v).font = AZUL
        wa.cell(row=r, column=5, value=f'=D{r}/Jefes!D{fila_jefe}').number_format = '0.0%'
        wa.cell(row=r, column=9).alignment = Alignment(wrap_text=True, vertical='top')
        wa.cell(row=r, column=11).alignment = Alignment(wrap_text=True, vertical='top')
        r += 1
anchos(wa, [12, 10, 14, 8, 14, 18, 8, 10, 80, 8, 60, 18])
wa.row_dimensions[1].height = 32

for ws in wb.worksheets:
    estilo(ws)
wb.save(SALIDA)
print(f'Hoja generada: {SALIDA}')

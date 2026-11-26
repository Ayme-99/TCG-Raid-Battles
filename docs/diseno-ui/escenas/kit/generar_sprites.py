#!/usr/bin/env python3
"""Genera los sprites del kit de escenas (SVG sueltos + sprites.json).
Uso: python3 generar_sprites.py   (escribe en ./sprites y ./sprites.json)
Convención: cada sprite es un SVG autocontenido (colores planos, sin referencias externas). 'ancla' = punto de la base
centrada del objeto, que es donde se coloca en la escena. 'zonas' son rectángulos pulsables en píxeles del sprite."""
import json, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vec import *
PAD = 28
CAT = {}
def sprite(id, w, h, inner, zonas=None, nota=""):
    W, H = w + 2 * PAD, h + 2 * PAD + 18
    open(f"sprites/{id}.svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">{inner}</svg>')
    CAT[id] = {"svg": f"sprites/{id}.svg", "ancho": W, "alto": H, "ancla": [W / 2, PAD + h], "zonas": zonas or [], "nota": nota}
def casa(id, w, h, roof, roofd, nota, chim=True):
    p = PAD
    z = [{"id": "puerta", "tipo": "puerta", "rect": [p + w / 2 - w * .12, p + h * .42 + h * .58 * .26, w * .24, h * .58 * .72 - h * .58 * .16]}]
    sprite(id, w, h, house(p, p, w, h, roof, roofd, chim), z, nota)
def laboratorio(w=440, h=470):
    p = PAD; y = p + 70; hh = h - 70; wy = y + hh * .36; wh = hh * .64
    o = f'<ellipse cx="{p+w/2}" cy="{p+h+8}" rx="{w*.62}" ry="20" fill="#1b4d2a" opacity=".25"/>'
    o += f'<rect x="{p}" y="{wy}" width="{w}" height="{wh}" fill="#fff3d9" stroke="{INK}" stroke-width="5"/>'
    o += f'<rect x="{p}" y="{p+h-wh*.12}" width="{w}" height="{wh*.12}" fill="#bdb6a8" stroke="{INK}" stroke-width="4"/>'
    o += f'<path d="M{p-18} {wy+4} L{p+w*.17} {y} H{p+w*.83} L{p+w+18} {wy+4}z" fill="#34b5a0" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    o += f'<path d="M{p-18} {wy+4} L{p+w+18} {wy+4}" stroke="#25907f" stroke-width="12"/>'
    for i in range(1, 5): o += f'<path d="M{p+w*.17-i*7} {y+i*(wy-y)/5} H{p+w*.83+i*7}" stroke="#25907f" stroke-width="3" opacity=".7"/>'
    cx = p + w / 2
    o += f'<ellipse cx="{cx}" cy="{y+4}" rx="{w*.17}" ry="14" fill="#cfd8e3" stroke="{INK}" stroke-width="5"/>'
    o += f'<path d="M{cx-w*.14} {y+2} a{w*.14} {w*.14} 0 0 1 {w*.28} 0z" fill="#eef3f9" stroke="{INK}" stroke-width="5"/>'
    o += f'<path d="M{cx-w*.08} {y-30} a{w*.1} {w*.1} 0 0 1 {w*.1} -12" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" opacity=".8"/>'
    o += f'<rect x="{cx-4}" y="{y-w*.14-30}" width="8" height="30" fill="#8a97a8" stroke="{INK}" stroke-width="3"/><circle cx="{cx}" cy="{y-w*.14-34}" r="8" fill="#e5484d" stroke="{INK}" stroke-width="3"/>'
    o += f'<rect x="{cx-w*.1}" y="{wy-26}" width="{w*.2}" height="24" rx="5" fill="#c9895a" stroke="{INK}" stroke-width="4"/>'
    dw = w * .16; dy = wy + wh * .3; dh = wh * .7 - wh * .12
    o += f'<rect x="{cx-dw/2}" y="{dy}" width="{dw}" height="{dh}" rx="3" fill="#8a5a33" stroke="{INK}" stroke-width="5"/><path d="M{cx} {dy} v{dh}" stroke="{INK}" stroke-width="4"/><circle cx="{cx+10}" cy="{dy+dh*.55}" r="3" fill="#ffd96a"/>'
    o += f'<path d="M{cx-dw/2-12} {dy} H{cx+dw/2+12} l-6 -18 H{cx-dw/2-6}z" fill="#fff" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
    o += window(p + w * .1, wy + wh * .2, w * .22, wh * .3) + window(p + w * .68, wy + wh * .2, w * .22, wh * .3)
    z = [{"id": "puerta", "tipo": "puerta", "rect": [cx - dw / 2 - 12, dy - 18, dw + 24, dh + 18]}, {"id": "edificio", "tipo": "edificio", "rect": [p - 18, y - 60, w + 36, h + 60]}]
    sprite("laboratorio", w, h, o, z, "Laboratorio del Profesor: tejado verde azulado con cúpula y antena, placa sobre la puerta.")
def buzon():
    p = 20
    o = f'<ellipse cx="{p+18}" cy="{p+78}" rx="22" ry="6" fill="#1b4d2a" opacity=".28"/><rect x="{p+12}" y="{p+34}" width="10" height="44" fill="#8a5a33" stroke="{INK}" stroke-width="3"/>'
    o += f'<path d="M{p-2} {p+36} v-14 a20 20 0 0 1 40 0 v14z" fill="#ffd23f" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/><rect x="{p+6}" y="{p+20}" width="24" height="5" rx="2" fill="{INK}"/><rect x="{p+36}" y="{p+8}" width="5" height="22" fill="#e5484d" stroke="{INK}" stroke-width="2"/>'
    sprite("buzon", 40, 78, o, [], "Buzón amarillo de la casa del jugador.")
def farola():
    p = 24; h = 130
    o = f'<ellipse cx="{p+8}" cy="{p+h}" rx="22" ry="6" fill="#1b4d2a" opacity=".28"/><rect x="{p+3}" y="{p+26}" width="10" height="{h-26}" fill="#3b2f4d" stroke="{INK}" stroke-width="3"/>'
    o += f'<path d="M{p-12} {p+26} l8 -26 h24 l8 26z" fill="#ffd96a" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
    sprite("farola", 16, h, o, [], "Farola de calle: poste oscuro y lámpara amarilla.")
def arbol(id, r, nota):
    p = PAD; cx = p + r * 1.1; cy = p + r * 1.05
    o = tree(cx, cy, r)
    sprite(id, r * 2.2, r * 2.25, o, [], nota)
def arbusto():
    sprite("arbusto", 90, 58, bush(PAD + 45, PAD + 28, 28), [], "Arbusto bajo redondo.")
def matas():
    r = random.Random(5); o = ""
    for i in range(3):
        x = 18 + i * 14; o += f'<path d="M{x-8} 44 q4 -22 8 -34 q4 14 12 34z" fill="#3a9a4a" stroke="#1d5a2b" stroke-width="2"/>'
    sprite("mata-hierba", 50, 44, o, [], "Mata de hierba pequeña, de relleno.")
def hierba_alta_sprite(id, w, h, seed, nota):
    p = PAD; r = random.Random(seed)
    o = f'<rect x="{p}" y="{p+10}" width="{w}" height="{h-10}" rx="46" fill="#2a7a3a" stroke="{INK}" stroke-width="6"/>'
    cols = ["#2f9a4e", "#3aa85a", "#52c46a", "#278a45"]
    pts = sorted([(r.randint(p + 16, p + w - 16), r.randint(p + 40, p + h - 6)) for _ in range(int(w * h / 1300))], key=lambda q: q[1])
    for bx, by in pts:
        o += f'<path d="M{bx-9} {by} q8 -30 9 -44 q5 24 9 44z" fill="{r.choice(cols)}" stroke="#1d5a2b" stroke-width="1.5"/>'
    sprite(id, w, h, o, [{"id": "cuerpo", "tipo": "hierba-alta", "rect": [p, p + 10, w, h - 10]}], nota)
def valla():
    p = 20; o = ""
    o += f'<ellipse cx="{p+110}" cy="{p+74}" rx="120" ry="9" fill="#1b4d2a" opacity=".25"/>'
    for y in (22, 46): o += f'<rect x="{p}" y="{p+y}" width="220" height="10" rx="3" fill="#c9895a" stroke="{INK}" stroke-width="3"/>'
    for x in (6, 106, 206): o += f'<rect x="{p+x}" y="{p+8}" width="14" height="66" rx="3" fill="#a96f3f" stroke="{INK}" stroke-width="3"/>'
    sprite("valla", 240, 74, o, [], "Tramo de valla de madera (3 postes).")
def roca():
    p = 20
    o = f'<ellipse cx="{p+46}" cy="{p+52}" rx="58" ry="10" fill="#1b4d2a" opacity=".25"/><path d="M{p} {p+50} q-4 -30 22 -42 q26 -12 52 4 q24 14 16 38z" fill="#b8b6c2" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/><path d="M{p+16} {p+18} q16 -10 34 -2" fill="none" stroke="#e6e4ee" stroke-width="5" stroke-linecap="round"/><path d="M{p+50} {p+50} q10 -22 38 -26 q4 14 0 26z" fill="#9694a6"/>'
    sprite("roca", 92, 54, o, [], "Roca pequeña gris.")
def arbol2():
    p = PAD; s = 1.0
    o = pine(p + 40, p + 80, s)
    sprite("arbol-2", 80, 150, o, [], "Conífera (segundo tipo de árbol).")
os.makedirs("sprites", exist_ok=True)
laboratorio()
casa("casa-jugador", 250, 200, "#f08a3c", "#c96a22", "Casa del jugador: tejado naranja. Lleva el buzón aparte (sprite buzon).")
casa("casa-pequena-azul", 240, 195, "#3b72e0", "#2a56b3", "Casa pequeña de vecino, tejado azul.")
casa("casa-pequena-roja", 250, 205, "#c2405b", "#9b2f46", "Casa pequeña de vecino, tejado rojo.")
casa("casa-pequena-verde", 230, 170, "#2f9a4e", "#25803f", "Casa pequeña de Ciudad Verde, tejado verde (ya usada en la base de Ciudad Verde).")
buzon(); farola(); arbol("arbol-1", 56, "Árbol redondo grande, copa clara."); arbusto(); matas()
hierba_alta_sprite("hierba-alta-grande", 690, 820, 11, "Mancha grande de hierba alta (zona de combate de ruta).")
hierba_alta_sprite("hierba-alta-media", 400, 300, 12, "Mancha de hierba alta mediana.")
valla(); roca(); arbol2()
json.dump(CAT, open("sprites.json", "w"), ensure_ascii=False, indent=2)
print(len(CAT), "sprites")

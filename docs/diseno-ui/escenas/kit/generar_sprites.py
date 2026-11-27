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
def puente():
    p = PAD; w, h = 300, 250
    o = f'<rect x="{p+30}" y="{p+4}" width="{w-60}" height="{h-8}" fill="#e8dfcf" stroke="{INK}" stroke-width="5"/>'
    for y in range(p + 30, p + h - 20, 34): o += f'<path d="M{p+38} {y} H{p+w-38}" stroke="#c9bfa8" stroke-width="3"/>'
    for x in (p + 6, p + w - 46):
        o += f'<rect x="{x}" y="{p}" width="40" height="{h}" rx="12" fill="#cfc6b4" stroke="{INK}" stroke-width="5"/><rect x="{x+8}" y="{p+8}" width="10" height="{h-16}" rx="5" fill="#efe9dc"/>'
        for y in (p - 2, p + h - 26): o += f'<rect x="{x-4}" y="{y}" width="48" height="28" rx="8" fill="#b9b09c" stroke="{INK}" stroke-width="4"/>'
    sprite("puente", w, h, o, [], "Puente de piedra en vista cenital (el camino lo cruza en vertical). Cubre un río de ~170 px de ancho.")
def portico():
    p = PAD; w, h = 340, 170
    o = f'<ellipse cx="{p+w/2}" cy="{p+h-4}" rx="{w/2+10}" ry="12" fill="#1b4d2a" opacity=".25"/>'
    for x in (p + 4, p + w - 64):
        o += f'<rect x="{x}" y="{p+30}" width="60" height="{h-32}" rx="8" fill="#d6cdbb" stroke="{INK}" stroke-width="5"/><path d="M{x+14} {p+44} V{p+h-14}" stroke="#f1ebdd" stroke-width="8" stroke-linecap="round"/><rect x="{x-6}" y="{p+20}" width="72" height="26" rx="8" fill="#bdb4a0" stroke="{INK}" stroke-width="4"/>'
    o += f'<path d="M{p-6} {p+34} Q{p+w/2} {p-26} {p+w+6} {p+34} V{p+8} Q{p+w/2} {p-40} {p-6} {p+8}z" fill="#cfc6b4" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    sprite("portico", w, h, o, [{"id": "puerta", "tipo": "salida", "rect": [p + 64, p, w - 128, h]}], "Pórtico de piedra bajo (salida de ruta). El camino pasa por el hueco central.")
def mostrador(id, w, h, color, colord, nota, zona, tipo, extra=""):
    p = PAD
    o = f'<ellipse cx="{p+w/2}" cy="{p+h-2}" rx="{w/2+8}" ry="10" fill="#000" opacity=".15"/>'
    o += f'<rect x="{p}" y="{p+h*.38}" width="{w}" height="{h*.62}" rx="14" fill="{color}" stroke="{INK}" stroke-width="5"/>'
    o += f'<rect x="{p-6}" y="{p+h*.3}" width="{w+12}" height="{h*.14}" rx="8" fill="#f4efe6" stroke="{INK}" stroke-width="5"/>'
    o += f'<rect x="{p+14}" y="{p+h*.52}" width="{w-28}" height="{h*.34}" rx="8" fill="{colord}" opacity=".55"/>' + extra
    sprite(id, w, h, o, [{"id": zona, "tipo": tipo, "rect": [p - 6, p, w + 12, h]}], nota)
def curar():
    p = PAD; w = 420; m = ""
    m += f'<rect x="{p+120}" y="{p}" width="180" height="96" rx="16" fill="#ffffff" stroke="{INK}" stroke-width="5"/>'
    for i in range(6):
        x = p + 140 + (i % 3) * 52; y = p + 14 + (i // 3) * 36
        m += f'<circle cx="{x+14}" cy="{y+14}" r="14" fill="#f2f2f2" stroke="{INK}" stroke-width="3"/><path d="M{x} {y+14} H{x+28}" stroke="{INK}" stroke-width="3"/><path d="M{x} {y+14} a14 14 0 0 1 28 0z" fill="#e0453c"/><circle cx="{x+14}" cy="{y+14}" r="4" fill="#fff" stroke="{INK}" stroke-width="2"/>'
    m += f'<path d="M{p+40} {p+50} h24 v-14 h14 v14 h24 v14 h-24 v14 h-14 v-14 h-24z" fill="#e0453c" stroke="{INK}" stroke-width="3"/>'
    mostrador("mostrador-curar", w, 210, "#f6a9bc", "#e0788f", "Mostrador de la enfermera con la máquina de curar (zona curar).", "curar", "curar", m)
def tienda_mostrador():
    p = PAD; w = 380; m = ""
    cols = ["#f2c84b", "#58b0e8", "#e0453c", "#7bd36a"]
    for fila, y in enumerate((p + 4, p + 52)):
        m += f'<rect x="{p+10}" y="{y}" width="{w-20}" height="10" rx="3" fill="#c9895a" stroke="{INK}" stroke-width="3"/>'
        for i in range(6): m += f'<rect x="{p+24+i*58}" y="{y-34}" width="38" height="34" rx="6" fill="{cols[(i+fila)%4]}" stroke="{INK}" stroke-width="3"/>'
    mostrador("mostrador-tienda", w, 210, "#8fb8f0", "#5c8ad0", "Mostrador de la tienda con estantes (zona tienda).", "tienda", "tienda", m)
def pc():
    p = PAD; w, h = 150, 190
    o = f'<ellipse cx="{p+w/2}" cy="{p+h-2}" rx="{w/2}" ry="9" fill="#000" opacity=".15"/>'
    o += f'<rect x="{p+10}" y="{p+84}" width="{w-20}" height="{h-84}" rx="8" fill="#b9bfd0" stroke="{INK}" stroke-width="5"/>'
    o += f'<rect x="{p}" y="{p}" width="{w}" height="96" rx="12" fill="#d7dbe8" stroke="{INK}" stroke-width="5"/><rect x="{p+12}" y="{p+12}" width="{w-24}" height="62" rx="6" fill="#58b0e8" stroke="{INK}" stroke-width="4"/><path d="M{p+26} {p+34} h50 M{p+26} {p+50} h80" stroke="#e9f7ff" stroke-width="6" stroke-linecap="round"/>'
    o += f'<rect x="{p+20}" y="{p+110}" width="{w-40}" height="20" rx="5" fill="#f4efe6" stroke="{INK}" stroke-width="3"/>'
    sprite("pc", w, h, o, [{"id": "pc", "tipo": "pc", "rect": [p, p, w, h]}], "Terminal de PC de almacenamiento (zona pc).")
def planta():
    p = PAD
    o = f'<ellipse cx="{p+34}" cy="{p+108}" rx="40" ry="8" fill="#000" opacity=".15"/><path d="M{p+8} {p+70} h52 l-8 40 h-36z" fill="#c9895a" stroke="{INK}" stroke-width="4"/>'
    for a, c in ((-40, "#2f9a4e"), (0, "#3aa85a"), (40, "#278a45")): o += f'<path d="M{p+34} {p+72} q{a*1.2} -40 {a*.6} -66 q{30+a*.4} 30 {-a*.6+8} 66z" fill="{c}" stroke="{INK}" stroke-width="3"/>'
    sprite("planta", 68, 110, o, [], "Planta de interior en maceta.")
def sofa():
    p = PAD; w, h = 260, 90
    o = f'<ellipse cx="{p+w/2}" cy="{p+h}" rx="{w/2+6}" ry="8" fill="#000" opacity=".15"/><rect x="{p}" y="{p}" width="{w}" height="{h-14}" rx="18" fill="#e0788f" stroke="{INK}" stroke-width="5"/><rect x="{p+14}" y="{p+24}" width="{w-28}" height="{h-34}" rx="12" fill="#f6a9bc" stroke="{INK}" stroke-width="4"/>'
    sprite("sofa", w, h, o, [], "Sofá de la sala de espera.")
def alfombra():
    p = PAD; w, h = 260, 120
    o = f'<rect x="{p}" y="{p}" width="{w}" height="{h}" rx="16" fill="#e0453c" stroke="{INK}" stroke-width="5"/><rect x="{p+16}" y="{p+16}" width="{w-32}" height="{h-32}" rx="10" fill="none" stroke="#f9d0cb" stroke-width="5"/>'
    sprite("alfombra-puerta", w, h, o, [], "Alfombra de entrada.")
def cartel():
    p = PAD
    o = f'<ellipse cx="{p+30}" cy="{p+86}" rx="34" ry="7" fill="#1b4d2a" opacity=".25"/><rect x="{p+24}" y="{p+36}" width="12" height="52" fill="#a96f3f" stroke="{INK}" stroke-width="3"/><rect x="{p}" y="{p}" width="60" height="42" rx="6" fill="#d9a066" stroke="{INK}" stroke-width="4"/><path d="M{p+10} {p+14} h40 M{p+10} {p+26} h28" stroke="#a96f3f" stroke-width="4" stroke-linecap="round"/>'
    sprite("cartel", 60, 88, o, [], "Cartel de madera sin texto (ruta, bifurcación).")
def seto(w=300, id="seto"):
    p = PAD; o = f'<ellipse cx="{p+w/2}" cy="{p+66}" rx="{w/2+8}" ry="9" fill="#1b4d2a" opacity=".25"/>'
    n = int(w // 46)
    for i in range(n): o += f'<circle cx="{p+30+i*(w-60)/max(n-1,1)}" cy="{p+34}" r="34" fill="#2f9a4e" stroke="{INK}" stroke-width="4"/>'
    for i in range(n): o += f'<circle cx="{p+30+i*(w-60)/max(n-1,1)-4}" cy="{p+26}" r="18" fill="#52c46a" opacity=".6"/>'
    sprite(id, w, 70, o, [], "Seto denso (separa ramales).")
def arbol_oscuro():
    p = PAD; r = 50; cx = p + r * 1.1; cy = p + r * 1.05
    o = tree(cx, cy, r).replace("#3aa85a", "#1f6e3a").replace("#2a8a47", "#17562d").replace("#7fd77c", "#3f9a5a")
    sprite("arbol-oscuro", r * 2.2, r * 2.25, o, [], "Árbol de copa oscura (bosque).")
def tronco():
    p = PAD
    o = f'<ellipse cx="{p+80}" cy="{p+40}" rx="86" ry="9" fill="#1b4d2a" opacity=".25"/><rect x="{p}" y="{p+4}" width="160" height="38" rx="18" fill="#a96f3f" stroke="{INK}" stroke-width="4"/><ellipse cx="{p+148}" cy="{p+23}" rx="12" ry="17" fill="#e0b27a" stroke="{INK}" stroke-width="3"/><path d="M{p+20} {p+12} h90" stroke="#c9895a" stroke-width="4" stroke-linecap="round"/><path d="M{p+10} {p+4} q20 -14 40 0" fill="#5fb85a" stroke="{INK}" stroke-width="2"/>'
    sprite("tronco", 160, 44, o, [], "Tronco caído con musgo.")
def hongo():
    p = PAD
    o = f'<ellipse cx="{p+20}" cy="{p+40}" rx="22" ry="5" fill="#1b4d2a" opacity=".25"/><rect x="{p+14}" y="{p+20}" width="12" height="20" rx="4" fill="#f4efe6" stroke="{INK}" stroke-width="3"/><path d="M{p} {p+24} q20 -34 40 0z" fill="#e0453c" stroke="{INK}" stroke-width="3"/><circle cx="{p+13}" cy="{p+14}" r="3" fill="#fff"/><circle cx="{p+26}" cy="{p+10}" r="3" fill="#fff"/>'
    sprite("hongo", 40, 42, o, [], "Seta roja pequeña.")
def acantilado(w=520, id="acantilado"):
    p = PAD; h = 150
    o = f'<ellipse cx="{p+w/2}" cy="{p+h}" rx="{w/2}" ry="12" fill="#000" opacity=".15"/>'
    o += f'<path d="M{p} {p+h} V{p+50} L{p+w*.08} {p+20} L{p+w*.25} {p+36} L{p+w*.42} {p+8} L{p+w*.6} {p+30} L{p+w*.8} {p+6} L{p+w*.94} {p+34} L{p+w} {p+50} V{p+h}z" fill="#a8a29a" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    o += f'<path d="M{p+10} {p+h-44} H{p+w-10} M{p} {p+h-90} H{p+w}" stroke="#7d776f" stroke-width="4" opacity=".7"/><path d="M{p+w*.25} {p+36} v50 M{p+w*.6} {p+30} v60 M{p+w*.8} {p+6} v70" stroke="#7d776f" stroke-width="4"/><path d="M{p+w*.42} {p+8} l30 44 h-60z" fill="#c7c1b8" opacity=".6"/>'
    sprite(id, w, h, o, [], "Acantilado gris de roca con repisas (borde de colina).")
def roca_grande():
    p = PAD
    o = f'<ellipse cx="{p+80}" cy="{p+92}" rx="92" ry="14" fill="#000" opacity=".15"/><path d="M{p} {p+90} q-8 -56 40 -78 q50 -22 90 6 q36 26 28 72z" fill="#b8b6c2" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/><path d="M{p+30} {p+30} q30 -20 64 -4" fill="none" stroke="#e6e4ee" stroke-width="7" stroke-linecap="round"/><path d="M{p+90} {p+88} q16 -40 66 -48 q6 28 0 48z" fill="#9694a6"/>'
    sprite("roca-grande", 160, 94, o, [], "Peñasco grande gris.")
def gimnasio_exterior(id="gimnasio-exterior", pal=None, nota="Gimnasio de roca (exterior): tejado de pizarra y portón de madera. Zona puerta → ir al interior."):
    p = PAD; w, h = 480, 360
    o = f'<ellipse cx="{p+w/2}" cy="{p+h+6}" rx="{w*.58}" ry="20" fill="#000" opacity=".18"/>'
    o += f'<rect x="{p}" y="{p+h*.34}" width="{w}" height="{h*.66}" fill="#b8ada0" stroke="{INK}" stroke-width="5"/>'
    for r_ in range(5):
        for c_ in range(7 if r_ % 2 else 8): o += f'<rect x="{p+c_*60+(30 if r_%2 else 0)}" y="{p+h*.34+r_*44}" width="60" height="44" fill="none" stroke="#8d8276" stroke-width="3"/>'
    o += f'<path d="M{p-20} {p+h*.36} L{p+w*.12} {p} H{p+w*.88} L{p+w+20} {p+h*.36}z" fill="#5f6672" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    for i in range(1, 5): o += f'<path d="M{p+w*.12-i*8} {p+i*h*.36/5} H{p+w*.88+i*8}" stroke="#474d58" stroke-width="3"/>'
    cx = p + w / 2
    o += f'<circle cx="{cx}" cy="{p+h*.18}" r="34" fill="#d6cdbb" stroke="{INK}" stroke-width="5"/><path d="M{cx-18} {p+h*.18+14} l8 -20 l10 12 l10 -12 l8 20z" fill="#8d8276" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    dw = 130; dy = p + h * .52
    o += f'<rect x="{cx-dw/2-12}" y="{dy-12}" width="{dw+24}" height="{h*.48+12}" rx="10" fill="#8d8276" stroke="{INK}" stroke-width="5"/><rect x="{cx-dw/2}" y="{dy}" width="{dw}" height="{h*.48}" fill="#6b4a2f" stroke="{INK}" stroke-width="5"/><path d="M{cx} {dy} v{h*.48}" stroke="{INK}" stroke-width="4"/><circle cx="{cx-14}" cy="{dy+h*.26}" r="5" fill="#f2c84b"/><circle cx="{cx+14}" cy="{dy+h*.26}" r="5" fill="#f2c84b"/>'
    for x in (p + 40, p + w - 100): o += f'<rect x="{x}" y="{p+h*.52}" width="60" height="{h*.2}" rx="8" fill="#e6c27a" stroke="{INK}" stroke-width="4"/>'
    for a_, b_ in (pal or {}).items(): o = o.replace(a_, b_)
    sprite(id, w, h, o, [{"id": "puerta", "tipo": "puerta", "rect": [cx - dw / 2, dy, dw, h * .48]}, {"id": "edificio", "tipo": "edificio", "rect": [p, p, w, h]}], nota)
def centro_exterior():
    p = PAD; w, h = 400, 300
    cx = p + w / 2; dw = w * .26; wy = p + h * .38; wh = h * .62; dy = wy + wh * .3; dh = wh * .7 - wh * .14
    sprite("centro-pokemon-exterior", w, h, centro(p, p, w, h), [{"id": "puerta", "tipo": "puerta", "rect": [cx - dw / 2, dy, dw, dh]}, {"id": "edificio", "tipo": "edificio", "rect": [p, p, w, h]}], "Centro Pokémon (exterior): tejado rojo y cruz blanca. Zona puerta → ir al interior.")
def barril():
    p = PAD
    o = f'<ellipse cx="{p+22}" cy="{p+50}" rx="28" ry="6" fill="#000" opacity=".18"/><path d="M{p} {p+10} q-4 20 0 40 h44 q4 -20 0 -40z" fill="#c9895a" stroke="{INK}" stroke-width="3"/><ellipse cx="{p+22}" cy="{p+10}" rx="22" ry="6" fill="#e0b27a" stroke="{INK}" stroke-width="3"/><path d="M{p+1} {p+24} h42 M{p+1} {p+38} h42" stroke="#6b4a2f" stroke-width="3"/>'
    sprite("barril", 44, 50, o, [], "Barril de madera.")
def muro_piedra():
    p = PAD; w = 240
    o = f'<ellipse cx="{p+w/2}" cy="{p+44}" rx="{w/2+6}" ry="7" fill="#000" opacity=".15"/><rect x="{p}" y="{p}" width="{w}" height="42" rx="10" fill="#c9c1b3" stroke="{INK}" stroke-width="4"/>'
    for i in range(1, 5): o += f'<path d="M{p+i*48} {p+2} v38" stroke="#8d8276" stroke-width="3"/>'
    sprite("muro-piedra", w, 44, o, [], "Tramo de muro bajo de piedra.")
def arena_roca():
    p = PAD; w, h = 900, 520
    o = f'<ellipse cx="{p+w/2}" cy="{p+h/2}" rx="{w/2}" ry="{h/2}" fill="#7a7266" stroke="{INK}" stroke-width="6"/>'
    import math
    for i in range(30):
        a = i / 30 * 2 * math.pi; x = p + w / 2 + math.cos(a) * (w / 2 - 14); y = p + h / 2 + math.sin(a) * (h / 2 - 14)
        o += f'<rect x="{x-24}" y="{y-16}" width="48" height="32" rx="8" transform="rotate({a*57.3+90} {x} {y})" fill="#b0a898" stroke="{INK}" stroke-width="4"/>'
    o += f'<ellipse cx="{p+w/2}" cy="{p+h/2}" rx="{w/2-42}" ry="{h/2-42}" fill="#e3c98f" stroke="#b79a5f" stroke-width="5"/>'
    r = random.Random(3)
    for _ in range(60): o += f'<ellipse cx="{p+w/2+r.randint(-w//2+90,w//2-90)}" cy="{p+h/2+r.randint(-h//2+80,h//2-80)}" rx="{r.randint(6,14)}" ry="3" fill="#c9ad72"/>'
    o += f'<path d="M{p+w/2-120} {p+h/2} H{p+w/2+120}" stroke="#b79a5f" stroke-width="6" stroke-linecap="round"/><circle cx="{p+w/2}" cy="{p+h/2}" r="34" fill="none" stroke="#b79a5f" stroke-width="6"/>'
    sprite("arena-roca", w, h, o, [{"id": "cuerpo", "tipo": "arena", "rect": [p, p, w, h]}], "Arena oval de tierra apisonada rodeada de bloques de piedra (zona combate).")
def columna():
    p = PAD
    o = f'<ellipse cx="{p+36}" cy="{p+170}" rx="46" ry="10" fill="#000" opacity=".2"/><rect x="{p+6}" y="{p+20}" width="60" height="150" fill="#b0a898" stroke="{INK}" stroke-width="5"/><rect x="{p-4}" y="{p}" width="80" height="28" rx="8" fill="#8d8276" stroke="{INK}" stroke-width="5"/><rect x="{p-4}" y="{p+150}" width="80" height="26" rx="8" fill="#8d8276" stroke="{INK}" stroke-width="5"/><path d="M{p+22} {p+34} v120 M{p+50} {p+34} v120" stroke="#8d8276" stroke-width="4"/>'
    sprite("columna", 72, 176, o, [], "Columna de piedra.")
def antorcha():
    p = PAD
    o = f'<rect x="{p+8}" y="{p+36}" width="12" height="46" rx="3" fill="#6b4a2f" stroke="{INK}" stroke-width="3"/><path d="M{p-2} {p+38} h32 l-6 -14 h-20z" fill="#8d8276" stroke="{INK}" stroke-width="3"/><path d="M{p+14} {p+22} q-24 -22 0 -50 q8 18 18 8 q10 20 -18 42z" fill="#f2a43b" stroke="{INK}" stroke-width="3"/><path d="M{p+14} {p+18} q-10 -12 0 -26 q10 12 0 26z" fill="#ffe27a"/>'
    sprite("antorcha", 28, 82, o, [], "Antorcha de pared.")

def piscina():
    p = PAD; w, h = 1000, 560
    o = f'<rect x="{p}" y="{p}" width="{w}" height="{h}" rx="30" fill="#e7f1f8" stroke="{INK}" stroke-width="6"/><rect x="{p+34}" y="{p+34}" width="{w-68}" height="{h-68}" rx="20" fill="#5fb8f2" stroke="{INK}" stroke-width="5"/>'
    for i in range(7): o += f'<path d="M{p+70+i*130} {p+90} q40 -22 80 0 t80 0" fill="none" stroke="#c4f0ff" stroke-width="6" stroke-linecap="round" opacity=".8" transform="translate(0 {(i%3)*140})"/>'
    for x, y in ((p + 220, p + h / 2), (p + w / 2, p + h / 2), (p + w - 220, p + h / 2)):
        o += f'<ellipse cx="{x}" cy="{y+8}" rx="92" ry="48" fill="#000" opacity=".15"/><ellipse cx="{x}" cy="{y}" rx="90" ry="46" fill="#e7f1f8" stroke="{INK}" stroke-width="5"/><ellipse cx="{x}" cy="{y}" rx="60" ry="28" fill="#cfe3f0"/>'
    sprite("piscina-gimnasio", w, h, o, [{"id": "cuerpo", "tipo": "arena", "rect": [p, p, w, h]}], "Piscina de combate con tres plataformas (zona combate).")
def puente_largo():
    p = PAD; w, h = 300, 620
    o = f'<rect x="{p+30}" y="{p+4}" width="{w-60}" height="{h-8}" fill="#e8dfcf" stroke="{INK}" stroke-width="5"/>'
    for y in range(p + 30, p + h - 20, 34): o += f'<path d="M{p+38} {y} H{p+w-38}" stroke="#c9bfa8" stroke-width="3"/>'
    for x in (p + 6, p + w - 46):
        o += f'<rect x="{x}" y="{p}" width="40" height="{h}" rx="12" fill="#cfc6b4" stroke="{INK}" stroke-width="5"/><rect x="{x+8}" y="{p+8}" width="10" height="{h-16}" rx="5" fill="#efe9dc"/>'
        for y in range(p - 2, p + h - 20, 150): o += f'<rect x="{x-4}" y="{y}" width="48" height="28" rx="8" fill="#b9b09c" stroke="{INK}" stroke-width="4"/>'
        o += f'<rect x="{x-4}" y="{p+h-26}" width="48" height="28" rx="8" fill="#b9b09c" stroke="{INK}" stroke-width="4"/>'
    sprite("puente-largo", w, h, o, [], "Puente de piedra largo (vista cenital vertical) sobre un río ancho.")
def cueva_entrada():
    p = PAD; w, h = 560, 360
    o = f'<ellipse cx="{p+w/2}" cy="{p+h}" rx="{w/2}" ry="16" fill="#000" opacity=".18"/>'
    o += f'<path d="M{p} {p+h} V{p+150} Q{p+20} {p+30} {p+w*.3} {p+18} Q{p+w*.5} {p-8} {p+w*.7} {p+18} Q{p+w-20} {p+30} {p+w} {p+150} V{p+h}z" fill="#a8a29a" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>'
    o += f'<path d="M{p+w*.3} {p+h} V{p+h*.5} Q{p+w*.3} {p+h*.2} {p+w*.5} {p+h*.2} Q{p+w*.7} {p+h*.2} {p+w*.7} {p+h*.5} V{p+h}z" fill="#2a1d3a" stroke="{INK}" stroke-width="6"/>'
    o += f'<path d="M{p+w*.34} {p+h} V{p+h*.52} Q{p+w*.34} {p+h*.28} {p+w*.5} {p+h*.28} Q{p+w*.66} {p+h*.28} {p+w*.66} {p+h*.52} V{p+h}z" fill="#3d2f55"/>'
    for x in (p + w * .3, p + w * .7 - 14): o += f'<rect x="{x-4}" y="{p+h*.38}" width="18" height="{h*.62}" fill="#a96f3f" stroke="{INK}" stroke-width="4"/>'
    o += f'<rect x="{p+w*.28}" y="{p+h*.3}" width="{w*.44}" height="20" rx="6" fill="#c9895a" stroke="{INK}" stroke-width="4"/>'
    for x, y, r_ in ((.12, .5, 26), (.86, .55, 30), (.2, .78, 20), (.8, .82, 22)): o += f'<circle cx="{p+w*x}" cy="{p+h*y}" r="{r_}" fill="#c7c1b8" stroke="{INK}" stroke-width="4"/>'
    sprite("cueva-entrada", w, h, o, [{"id": "puerta", "tipo": "puerta", "rect": [p + w * .3, p + h * .2, w * .4, h * .8]}], "Entrada de cueva (Monte Moon): montículo de roca con boca oscura y vigas de madera. Zona puerta → ir a la galería.")
def estalagmita(id="estalagmita", h=140, nota="Estalagmita de cueva."):
    p = PAD; w = 70
    o = f'<ellipse cx="{p+w/2}" cy="{p+h}" rx="{w*.62}" ry="9" fill="#000" opacity=".25"/><path d="M{p} {p+h} L{p+w*.3} {p+h*.25} L{p+w*.5} {p} L{p+w*.7} {p+h*.3} L{p+w} {p+h}z" fill="#8a8499" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/><path d="M{p+w*.5} {p} L{p+w*.4} {p+h*.7}" stroke="#b6b1c4" stroke-width="6" stroke-linecap="round"/>'
    sprite(id, w, h, o, [], nota)
def estalactita():
    p = PAD; w, h = 80, 120
    o = f'<path d="M{p} {p} L{p+w} {p} L{p+w*.58} {p+h*.7} L{p+w*.5} {p+h} L{p+w*.42} {p+h*.7}z" fill="#8a8499" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/><path d="M{p+w*.3} {p+6} L{p+w*.45} {p+h*.7}" stroke="#b6b1c4" stroke-width="5" stroke-linecap="round"/>'
    sprite("estalactita", w, h, o, [], "Estalactita colgante (se coloca con el ancla en la punta de arriba del techo; aquí el ancla es la base del sprite).")
def setas_grandes():
    p = PAD; w, h = 420, 260
    o = f'<ellipse cx="{p+w/2}" cy="{p+h*.55}" rx="{w/2}" ry="{h*.5}" fill="#5a4a6e" stroke="{INK}" stroke-width="6"/><ellipse cx="{p+w/2}" cy="{p+h*.55}" rx="{w/2-24}" ry="{h*.5-22}" fill="#6c5a83"/>'
    r = random.Random(21)
    for i in range(16):
        x = p + 60 + r.random() * (w - 120); y = p + 60 + r.random() * (h * .8 - 60); k = r.uniform(.8, 1.4)
        c = r.choice(["#e0453c", "#e8a23b", "#c9d36b"])
        o += f'<rect x="{x-5*k}" y="{y}" width="{10*k}" height="{22*k}" rx="3" fill="#f4efe6" stroke="{INK}" stroke-width="3"/><path d="M{x-22*k} {y+4} q{22*k} {-34*k} {44*k} 0z" fill="{c}" stroke="{INK}" stroke-width="3"/><circle cx="{x-6*k}" cy="{y-6*k}" r="{3*k}" fill="#fff"/><circle cx="{x+8*k}" cy="{y-10*k}" r="{3*k}" fill="#fff"/>'
    sprite("setas-grandes", w, h, o, [{"id": "cuerpo", "tipo": "combate", "rect": [p, p, w, h]}], "Alfombra de setas (zona de combate salvaje: Paras).")
os.makedirs("sprites", exist_ok=True)
laboratorio()
casa("casa-jugador", 250, 200, "#f08a3c", "#c96a22", "Casa del jugador: tejado naranja. Lleva el buzón aparte (sprite buzon).")
casa("casa-pequena-azul", 240, 195, "#3b72e0", "#2a56b3", "Casa pequeña de vecino, tejado azul.")
casa("casa-pequena-roja", 250, 205, "#c2405b", "#9b2f46", "Casa pequeña de vecino, tejado rojo.")
casa("casa-pequena-verde", 230, 170, "#2f9a4e", "#25803f", "Casa pequeña de Ciudad Verde, tejado verde (ya usada en la base de Ciudad Verde).")
buzon(); farola(); arbol("arbol-1", 56, "Árbol redondo grande, copa clara."); arbusto(); matas()
hierba_alta_sprite("hierba-alta-grande", 690, 820, 11, "Mancha grande de hierba alta (zona de combate de ruta).")
hierba_alta_sprite("hierba-alta-media", 400, 300, 12, "Mancha de hierba alta mediana.")
valla(); roca(); arbol2(); puente(); portico(); curar(); tienda_mostrador(); pc(); planta(); sofa(); alfombra()
cartel(); seto(300,"seto"); arbol_oscuro(); tronco(); hongo()
acantilado(520,"acantilado"); roca_grande()
gimnasio_exterior(); centro_exterior(); barril(); muro_piedra()
arena_roca(); columna(); antorcha()
gimnasio_exterior("gimnasio-agua-exterior", {"#5f6672":"#3f7fd0","#474d58":"#2f62a8","#b8ada0":"#dcebf7","#8d8276":"#8fb4d8","#6b4a2f":"#2f62a8","#d6cdbb":"#bfe3f7","#e6c27a":"#a9d8f2"}, "Gimnasio de agua (exterior): tejado azul y paredes claras. Zona puerta → ir al interior.")
piscina()
puente_largo()
cueva_entrada()
estalagmita("estalagmita", 140); estalagmita("estalagmita-baja", 90, "Estalagmita baja de cueva."); estalactita(); setas_grandes()
json.dump(CAT, open("sprites.json", "w"), ensure_ascii=False, indent=2)
print(len(CAT), "sprites")

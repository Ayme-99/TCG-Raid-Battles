#!/usr/bin/env python3
"""Compone una escena del kit: lee escenas/<id>.escena.json y escribe render/<id>.svg, .png y .zonas.json (1920x1088).
Uso: python3 componer.py escenas/pueblo-paleta.escena.json
Escena: {"escena","caminos":[{"material","ancho","d"}],"objetos":[{"sprite","x","y","escala","flip","id","z","acciones":{<zona>:{"accion","destino"}}}],
"zonas_extra":[{"id","tipo","accion","destino","rect"}]}. (x,y) = ancla del sprite (base centrada)."""
import json, os, re, subprocess, sys
from vec import INK, defs
MAT = {"tierra": ("#efd79b", INK), "piedra": ("#e8dfcf", INK), "hierba": ("#a6e07a", "#4e9a3a"), "agua": ("#7fd6f5", INK)}
W, H = 1920, 1088
def main(ruta):
    esc = json.load(open(ruta)); cat = json.load(open("sprites.json"))
    nombre = esc["escena"]; body = ""
    for c in esc.get("caminos", []):
        f, e = MAT[c["material"]]
        body += f'<path d="{c["d"]}" fill="none" stroke="{e}" stroke-width="{c["ancho"]+12}" stroke-linecap="round" stroke-linejoin="round"/>'
    for r in esc.get("rellenos", []):
        f, e = MAT[r["material"]]
        body += f'<ellipse cx="{r["x"]}" cy="{r["y"]}" rx="{r["rx"]}" ry="{r["ry"]}" fill="{e}" stroke="{e}" stroke-width="12"/>'
    for r in esc.get("rellenos", []):
        f, e = MAT[r["material"]]
        body += f'<ellipse cx="{r["x"]}" cy="{r["y"]}" rx="{r["rx"]}" ry="{r["ry"]}" fill="{f}"/>'
    for c in esc.get("caminos", []):
        f, e = MAT[c["material"]]
        body += f'<path d="{c["d"]}" fill="none" stroke="{f}" stroke-width="{c["ancho"]}" stroke-linecap="round" stroke-linejoin="round"/>'
    for c in esc.get("caminos", []):
        if c["material"] == "agua":
            for dy in (-c["ancho"] * .22, c["ancho"] * .22):
                body += f'<path d="{c["d"]}" transform="translate(0 {dy})" fill="none" stroke="#c4f0ff" stroke-width="6" stroke-linecap="round" stroke-dasharray="46 90"/>'
    zonas = []
    objs = sorted(esc["objetos"], key=lambda o: (o.get("z", 0), o["y"]))
    for o in objs:
        s = cat[o["sprite"]]; k = o.get("escala", 1.0); fl = -1 if o.get("flip") else 1
        ax, ay = s["ancla"]
        inner = re.sub(r"^<svg[^>]*>|</svg>$", "", open(s["svg"]).read().strip())
        tx = o["x"] - ax * k * fl; ty = o["y"] - ay * k
        body += f'<g transform="translate({tx} {ty}) scale({k*fl} {k})">{inner}</g>'
        for z in s["zonas"]:
            x, y, w, h = z["rect"]
            if fl == -1: x = s["ancho"] - x - w
            r = [round(o["x"] + (x - ax) * k), round(o["y"] + (y - ay) * k), round(w * k), round(h * k)]
            q = {"id": (o.get("id", o["sprite"]) if z["id"] == "cuerpo" else f'{o.get("id", o["sprite"])}-{z["id"]}'), "tipo": z["tipo"], "accion": None, "rect": r}
            q.update(o.get("acciones", {}).get(z["id"], {}))
            zonas.append(q)
    zonas += esc.get("zonas_extra", [])
    for q in zonas: q["rel"] = [round(q["rect"][0] / W, 4), round(q["rect"][1] / H, 4), round(q["rect"][2] / W, 4), round(q["rect"][3] / H, 4)]
    fondo = esc.get("fondo", "cesped")
    if fondo == "suelo-centro":
        sue = '<pattern id="losas" width="96" height="96" patternUnits="userSpaceOnUse"><rect width="96" height="96" fill="#fbf3e6"/><rect width="48" height="48" fill="#f3e3cf"/><rect x="48" y="48" width="48" height="48" fill="#f3e3cf"/></pattern>'
        pared = f'<rect y="0" width="{W}" height="330" fill="#fde3ea"/><rect y="250" width="{W}" height="80" fill="#f6a9bc"/><path d="M0 330 H{W}" stroke="{INK}" stroke-width="8"/>'
        for x in (330, 760, 1160, 1590): pared += f'<rect x="{x}" y="70" width="170" height="120" rx="10" fill="#b4e1f7" stroke="{INK}" stroke-width="6"/><path d="M{x+85} 70 v120 M{x} 130 h170" stroke="{INK}" stroke-width="4"/>'
        body = f'<rect y="330" width="{W}" height="{H-330}" fill="url(#losas)"/>' + pared + body
        defs_x = sue
    else: defs_x = ""
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">{defs()}{defs_x}<rect width="{W}" height="{H}" fill="url(#{fondo if fondo != "suelo-centro" else "cesped"})"/>{body}</svg>'
    os.makedirs("render", exist_ok=True)
    open(f"render/{nombre}.svg", "w").write(svg)
    subprocess.run(["rsvg-convert", "-w", str(W), f"render/{nombre}.svg", "-o", f"render/{nombre}.png"], check=True)
    json.dump({"escena": nombre, "formato": "16:9", "tamano": [W, H], "nota": esc.get("nota", ""), "zonas": zonas}, open(f"render/{nombre}.zonas.json", "w"), ensure_ascii=False, indent=2)
    print(nombre, len(objs), "objetos", len(zonas), "zonas")
if __name__ == "__main__": main(sys.argv[1])

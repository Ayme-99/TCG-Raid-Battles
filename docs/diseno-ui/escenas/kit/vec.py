# Primitivas SVG para las escenas base de la campaña (1920x1088). Estilo: contorno #2a1d3a, colores planos y limpios.
import random, json
INK="#2a1d3a"
def defs():
    return '''<defs>
<linearGradient id="cesped" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8fd567"/><stop offset="1" stop-color="#74c44f"/></linearGradient>
<linearGradient id="cristal" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#cdefff"/><stop offset="1" stop-color="#7cc4ee"/></linearGradient>
<linearGradient id="agua" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7fd6f5"/><stop offset="1" stop-color="#3b9fe0"/></linearGradient>
</defs>'''
def tree(cx,cy,r=56):
    return (f'<g><ellipse cx="{cx+r*.3}" cy="{cy+r*1.15}" rx="{r*1.05}" ry="{r*.3}" fill="#1b4d2a" opacity=".28"/>'
      f'<path d="M{cx-r*.17} {cy+r*.7} q{-r*.04} {r*.5} {-r*.2} {r*.55} h{r*.74} q{-r*.16} {-r*.05} {-r*.2} {-r*.55}z" fill="#8a5a33" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
      f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#3aa85a" stroke="{INK}" stroke-width="5"/>'
      f'<circle cx="{cx+r*.28}" cy="{cy+r*.22}" r="{r*.68}" fill="#2a8a47"/>'
      f'<circle cx="{cx-r*.3}" cy="{cy-r*.35}" r="{r*.42}" fill="#7fd77c" opacity=".55"/>'
      f'<circle cx="{cx-r*.38}" cy="{cy-r*.43}" r="{r*.16}" fill="#fff" opacity=".35"/></g>')
def pine(cx,cy,s=1.0):
    w=70*s;h=150*s
    return (f'<g><ellipse cx="{cx+10*s}" cy="{cy+h*.5}" rx="{w*.8}" ry="{12*s}" fill="#1b4d2a" opacity=".28"/>'
      f'<rect x="{cx-7*s}" y="{cy+h*.28}" width="{14*s}" height="{h*.22}" fill="#8a5a33" stroke="{INK}" stroke-width="4"/>'
      +''.join(f'<path d="M{cx} {cy-h*.5+i*h*.22} l{w*(.45+i*.12)} {h*.3} h{-w*(.9+i*.24)}z" fill="{["#2a8a47","#2f9a4e","#3aa85a"][i]}" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>' for i in range(3))
      +'</g>')
def bush(cx,cy,r=30):
    return (f'<g><ellipse cx="{cx+4}" cy="{cy+r*.85}" rx="{r*1.3}" ry="{r*.3}" fill="#1b4d2a" opacity=".25"/>'
      f'<circle cx="{cx-r*.55}" cy="{cy+r*.2}" r="{r*.7}" fill="#3aa85a" stroke="{INK}" stroke-width="4"/>'
      f'<circle cx="{cx+r*.55}" cy="{cy+r*.2}" r="{r*.7}" fill="#3aa85a" stroke="{INK}" stroke-width="4"/>'
      f'<circle cx="{cx}" cy="{cy-r*.15}" r="{r*.85}" fill="#3aa85a" stroke="{INK}" stroke-width="4"/>'
      f'<circle cx="{cx-r*.25}" cy="{cy-r*.35}" r="{r*.3}" fill="#7fd77c" opacity=".6"/></g>')
def flowers(x,y,n=6,seed=1):
    r=random.Random(seed);o=''
    for _ in range(n):
        fx=x+r.randint(-26,26);fy=y+r.randint(-10,10);c=r.choice(["#ff7aa8","#ffd23f","#fff","#b28cff"])
        o+=f'<circle cx="{fx}" cy="{fy}" r="5" fill="{c}" stroke="{INK}" stroke-width="2"/>'
    return o
def lamp(x,y,h=130):
    return (f'<g><ellipse cx="{x+8}" cy="{y}" rx="22" ry="6" fill="#1b4d2a" opacity=".28"/>'
      f'<rect x="{x-5}" y="{y-h}" width="10" height="{h}" fill="#3b2f4d" stroke="{INK}" stroke-width="3"/>'
      f'<path d="M{x-20} {y-h} l8 -26 h24 l8 26z" fill="#ffd96a" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/></g>')
def window(x,y,w,h,flor=True):
    o=(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="#b4e1f7" stroke="{INK}" stroke-width="4"/>'
       f'<path d="M{x+w/2} {y} v{h} M{x} {y+h/2} h{w}" stroke="{INK}" stroke-width="3"/>')
    if flor: o+=f'<rect x="{x-4}" y="{y+h}" width="{w+8}" height="10" fill="#c26b4a" stroke="{INK}" stroke-width="3"/>'+flowers(x+w/2,y+h-2,4,int(x))
    return o
def door(x,y,w,h):
    return (f'<path d="M{x} {y+h} v{-h+w/2} a{w/2} {w/2} 0 0 1 {w} 0 v{h-w/2}z" fill="#8a5a33" stroke="{INK}" stroke-width="4"/>'
            f'<circle cx="{x+w*.78}" cy="{y+h*.6}" r="3" fill="#ffd96a"/>')
def house(x,y,w,h,roof="#2f9a4e",roofd="#25803f",chim=True):
    wy=y+h*.42; wh=h*.58
    o=f'<ellipse cx="{x+w*.55}" cy="{y+h+8}" rx="{w*.62}" ry="16" fill="#1b4d2a" opacity=".25"/>'
    if chim: o+=f'<rect x="{x+w*.72}" y="{y-6}" width="34" height="{h*.3}" fill="#b5654a" stroke="{INK}" stroke-width="4"/>'
    o+=f'<rect x="{x}" y="{wy}" width="{w}" height="{wh}" fill="#fff3d9" stroke="{INK}" stroke-width="5"/>'
    o+=f'<rect x="{x}" y="{y+h-wh*.16}" width="{w}" height="{wh*.16}" fill="#bdb6a8" stroke="{INK}" stroke-width="4"/>'
    o+=f'<path d="M{x-12} {wy+4} L{x+w*.2} {y} H{x+w*.8} L{x+w+12} {wy+4}z" fill="{roof}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    o+=f'<path d="M{x-12} {wy+4} L{x+w+12} {wy+4}" stroke="{roofd}" stroke-width="10"/>'
    for i in range(1,4): o+=f'<path d="M{x+w*.2-i*6} {y+i*(wy-y)/4} H{x+w*.8+i*6}" stroke="{roofd}" stroke-width="3" opacity=".7"/>'
    dw=w*.2;o+=door(x+w/2-dw/2,wy+wh*.28,dw,wh*.72-wh*.16)
    o+=window(x+w*.12,wy+wh*.2,w*.22,wh*.3)+window(x+w*.66,wy+wh*.2,w*.22,wh*.3)
    return o
def centro(x,y,w,h):
    wy=y+h*.38;wh=h*.62
    o=f'<ellipse cx="{x+w*.5}" cy="{y+h+10}" rx="{w*.6}" ry="20" fill="#1b4d2a" opacity=".25"/>'
    o+=f'<rect x="{x}" y="{wy}" width="{w}" height="{wh}" fill="#ffffff" stroke="{INK}" stroke-width="5"/>'
    o+=f'<rect x="{x}" y="{y+h-wh*.14}" width="{w}" height="{wh*.14}" fill="#bdb6a8" stroke="{INK}" stroke-width="4"/>'
    o+=f'<path d="M{x-16} {wy+4} L{x+w*.14} {y} H{x+w*.86} L{x+w+16} {wy+4}z" fill="#e5484d" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    o+=f'<path d="M{x-16} {wy+4} L{x+w+16} {wy+4}" stroke="#b9323a" stroke-width="12"/>'
    for i in range(1,4): o+=f'<path d="M{x+w*.14-i*8} {y+i*(wy-y)/4} H{x+w*.86+i*8}" stroke="#b9323a" stroke-width="3" opacity=".7"/>'
    cx=x+w/2;cy=y+(wy-y)*.5
    o+=f'<circle cx="{cx}" cy="{cy}" r="{(wy-y)*.34}" fill="#fff" stroke="{INK}" stroke-width="5"/><path d="M{cx-9} {cy-26} h18 v17 h17 v18 h-17 v17 h-18 v-17 h-17 v-18 h17z" fill="#e5484d" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    dw=w*.26;dy=wy+wh*.3;dh=wh*.7-wh*.14
    o+=f'<rect x="{cx-dw/2}" y="{dy}" width="{dw}" height="{dh}" fill="#b4e1f7" stroke="{INK}" stroke-width="5"/><path d="M{cx} {dy} v{dh}" stroke="{INK}" stroke-width="4"/>'
    o+=f'<path d="M{cx-dw/2-14} {dy} H{cx+dw/2+14} l-8 -22 H{cx-dw/2-6}z" fill="#fff" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
    o+=window(x+w*.07,wy+wh*.22,w*.24,wh*.34)+window(x+w*.69,wy+wh*.22,w*.24,wh*.34)
    return o
def pathstroke(d,wd,fill="#efd79b",edge=INK):
    return f'<path d="{d}" fill="none" stroke="{edge}" stroke-width="{wd+12}" stroke-linecap="round" stroke-linejoin="round"/>', f'<path d="{d}" fill="none" stroke="{fill}" stroke-width="{wd}" stroke-linecap="round" stroke-linejoin="round"/>'
def paths(items):
    a=''.join(pathstroke(d,w,f)[0] for d,w,f in items); b=''.join(pathstroke(d,w,f)[1] for d,w,f in items)
    return '<g id="caminos">'+a+b+'</g>'
def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1088" width="1920" height="1088">{defs()}<rect width="1920" height="1088" fill="url(#cesped)"/>{body}</svg>'
def hierba_alta(x,y,w,h,seed=1,col="#2f7d3c"):
    r=random.Random(seed);o=f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="40" fill="#2a7a3a" stroke="{INK}" stroke-width="5"/>'
    for _ in range(int(w*h/1500)):
        bx=x+r.randint(14,w-14);by=y+r.randint(24,h-8)
        o+=f'<path d="M{bx-8} {by} q8 -28 8 -40 q4 22 8 40z" fill="{r.choice(["#3aa85a","#2f9a4e","#52c46a"])}" stroke="#1d5a2b" stroke-width="1.5"/>'
    return o
def save(name,body,zonas,nota):
    open(f'{name}.svg','w').write(svg(body))
    json.dump({"escena":name,"formato":"16:9","tamano":[1920,1088],"nota":nota,"zonas":[dict(z,rel=[round(z["rect"][0]/1920,4),round(z["rect"][1]/1088,4),round(z["rect"][2]/1920,4),round(z["rect"][3]/1088,4)]) for z in zonas]},open(f'{name}.zonas.json','w'),ensure_ascii=False,indent=2)

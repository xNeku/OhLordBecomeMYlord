#!/usr/bin/env python3
"""Genera los atlas PNG a partir de art/sprites.json (+ estructuras dibujadas aqui).
Uso:  python3 tools/build_atlas.py   (las tropas las entrega arte: ver docs/CONTRATO_ARTE.md)
Salida: assets/atlas/projectiles.png (+manifest, celdas 8x8)
        assets/atlas/structures.png (celdas 32x32, 2 fotogramas por fila)
Filas unidades: 0 goblin, 1 orc, 2 dwarf, 3 elf. Columnas: 0-1 fotogramas, 2 proyectil.
Filas estructuras: 0 tienda, 1 ayuntamiento, 2 casa, 3 cuartel, 4 torre, 5 arbol, 6 mineral, 7 fortaleza,
        8 base enemiga, 9 torre enemiga, 10 centro de madera, 11 centro de mineros.
Estructuras y entorno: solo blanco y negro puro, formas simples (regla de arte del diseñador)."""
import json, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spr = json.load(open(os.path.join(ROOT, "art/sprites.json")))["sprites"]
def hexc(h): h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4)) + (255,)
os.makedirs(os.path.join(ROOT, "assets/atlas"), exist_ok=True)
# Las TROPAS vienen del director artístico (assets/atlas/units_foot.png, units_mounted.png, beasts.png
# + art_manifest.json). Aquí solo se generan los PROYECTILES provisionales y las estructuras.

# Proyectiles: celdas 8x8, 2 fotogramas, en blanco (el motor los tiñe con el color de la raza)
PC = 8
PROJ = ["proj_stone", "proj_arrow", "proj_magic", "proj_bolt"]
pj = Image.new("RGBA", (PC * 2, PC * len(PROJ)), (0, 0, 0, 0))
WH = (255, 255, 255, 255)
def pp(f, r, x, y):
    pj.putpixel((f * PC + x, r * PC + y), WH)
for f in range(2):
    for x, y in ((3, 3), (4, 3), (3, 4), (4, 4), (3 + f, 2), (2, 3 + f)):  # piedra que gira
        pp(f, 0, x, y)
    for x in range(1, 7):  # flecha
        pp(f, 1, x, 4)
    pp(f, 1, 6, 3); pp(f, 1, 6, 5); pp(f, 1, 1, 3 + f)
    for x, y in ((3, 2), (4, 2), (2, 3), (5, 3), (2, 4), (5, 4), (3, 5), (4, 5)):  # orbe mágico que late
        pp(f, 2, x, y)
    if f: pp(f, 2, 3, 3); pp(f, 2, 4, 4)
    else: pp(f, 2, 4, 3); pp(f, 2, 3, 4)
    for x in range(2, 7):  # virote de ballesta
        pp(f, 3, x, 4); pp(f, 3, x, 3)
    pp(f, 3, 7 - f, 4)
pj.save(os.path.join(ROOT, "assets/atlas/projectiles.png"))
json.dump({"_nota": "Generado por tools/build_atlas.py (provisional hasta que arte entregue los suyos). celda 8x8, 2 fotogramas.",
           "celda": [PC, PC], "grid": [2, len(PROJ)], "filas": {k: i for i, k in enumerate(PROJ)}},
          open(os.path.join(ROOT, "assets/atlas/projectiles_manifest.json"), "w"), indent=1)

SC = 32
ROWS = 13
st = Image.new("RGBA", (SC * 2, SC * ROWS), (0, 0, 0, 0))
# Regla de arte (Neku): estructuras y entorno SOLO en blanco y negro, formas simples.
# El color queda reservado para tropas, proyectiles y habilidades.
W, K = (255, 255, 255, 255), (0, 0, 0, 255)
def rect(f, row, x0, y0, x1, y1, c):  # inclusive
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < SC and 0 <= y < SC: st.putpixel((f * SC + x, row * SC + y), c)
def tri(f, row, cx, top, base, half, c):  # triangulo isosceles relleno
    for y in range(top, base + 1):
        w = int(half * (y - top) / max(1, base - top))
        rect(f, row, cx - w, y, cx + w, y, c)
def battlements(f, row, x0, x1, y, step=4):
    for x in range(x0, x1 + 1, step): rect(f, row, x, y, min(x + 1, x1), y + 2, W)

for f in range(2):
    flag = f  # fotograma 2: la bandera ondea 1px
    # 0 tienda: triangulo blanco con puerta negra
    tri(f, 0, 16, 8, 27, 11, W); tri(f, 0, 16, 18, 27, 4, K)
    rect(f, 0, 16, 4, 16, 8, W); rect(f, 0, 17, 4 + flag, 19, 5 + flag, W)
    # 1 ayuntamiento: bloque + tejado separado por linea negra
    tri(f, 1, 16, 4, 12, 13, W); rect(f, 1, 5, 14, 26, 27, W)
    rect(f, 1, 14, 20, 17, 27, K); rect(f, 1, 8, 17, 9, 19, K); rect(f, 1, 22, 17, 23, 19, K)
    rect(f, 1, 16, 0, 16, 4, W); rect(f, 1, 17, flag, 20, 1 + flag, W)
    # 2 casa
    tri(f, 2, 16, 9, 15, 9, W); rect(f, 2, 9, 17, 22, 27, W); rect(f, 2, 15, 22, 17, 27, K)
    # 3 cuartel: bloque almenado con puerta grande
    battlements(f, 3, 4, 27, 10); rect(f, 3, 4, 13, 27, 27, W); rect(f, 3, 13, 19, 18, 27, K)
    rect(f, 3, 7, 17, 8, 18, K); rect(f, 3, 23, 17, 24, 18, K)
    # 4 torre: alta y almenada, aspillera negra
    battlements(f, 4, 10, 21, 4, 4); rect(f, 4, 10, 7, 21, 27, W)
    rect(f, 4, 15, 11, 16, 15, K); rect(f, 4, 14, 22, 17, 27, K)
    # 6 mineral: roca blanca con grietas negras
    tri(f, 6, 16, 12, 27, 11, W); tri(f, 6, 11, 16, 27, 6, W)
    for y in range(18, 25): st.putpixel((f * SC + 14 + (y - 18) // 3, 6 * SC + y), K)
    rect(f, 6, 19, 20, 21, 20, K)
    # 7 fortaleza: gran muro almenado, puerta y ventanas negras
    battlements(f, 7, 1, 30, 8); rect(f, 7, 1, 11, 30, 28, W)
    rect(f, 7, 12, 17, 19, 28, K); rect(f, 7, 5, 15, 7, 17, K); rect(f, 7, 24, 15, 26, 17, K)
    rect(f, 7, 15, 0, 15, 8, W); rect(f, 7, 16, flag, 21, 2 + flag, W)

def skull(f, row, cx, y):  # emblema enemigo: calavera (blanco con huecos negros)
    rect(f, row, cx - 3, y, cx + 3, y + 4, W); rect(f, row, cx - 2, y + 5, cx + 2, y + 6, W)
    rect(f, row, cx - 2, y + 1, cx - 1, y + 2, K); rect(f, row, cx + 1, y + 1, cx + 2, y + 2, K)
    rect(f, row, cx - 1, y + 6, cx - 1, y + 6, K); rect(f, row, cx + 1, y + 6, cx + 1, y + 6, K)
def spikes(f, row, x0, x1, y, h=3, step=3):  # fila de pinchos hacia arriba
    for x in range(x0, x1 + 1, step):
        for k in range(h): rect(f, row, x, y - k, x, y - k, W)
        rect(f, row, x - 1, y, x + 1, y, W)

for f in range(2):
    # 7 fortaleza (solo enemiga): se le añaden pinchos y calavera
    spikes(f, 7, 2, 29, 7, 3, 4); skull(f, 7, 16, 18 - 3); rect(f, 7, 12, 23, 19, 28, K)
    # 8 base enemiga: bloque con cuernos, tejado de pinchos y calavera
    rect(f, 8, 5, 12, 26, 27, W); spikes(f, 8, 6, 25, 11, 4, 3)
    for k in range(5):  # cuernos curvados a los lados
        rect(f, 8, 3 - k // 2, 11 - k, 4 - k // 2, 11 - k, W); rect(f, 8, 27 + k // 2, 11 - k, 28 + k // 2, 11 - k, W)
    skull(f, 8, 16, 14); rect(f, 8, 8, 22, 8, 27, K); rect(f, 8, 23, 22, 23, 27, K)
    rect(f, 8, 13, 23, 18, 27, K)
    # 9 torre enemiga: torre con pinchos y un "ojo" que parpadea
    rect(f, 9, 10, 8, 21, 27, W); spikes(f, 9, 10, 21, 7, 4, 3)
    rect(f, 9, 13, 12, 18, 15, K); rect(f, 9, 15 + f, 13, 16 + f, 14, W)
    rect(f, 9, 14, 22, 17, 27, K); rect(f, 9, 8, 26, 9, 27, W); rect(f, 9, 22, 26, 23, 27, W)
    # 10 centro de madera: troncos apilados + sierra circular
    for k, y in enumerate((20, 24)):
        rect(f, 10, 4 + k * 2, y, 22 - k * 2, y + 3, W); rect(f, 10, 5 + k * 2, y + 1, 5 + k * 2, y + 2, K)
    for y in range(8, 19):
        for x in range(17, 30):
            d = ((x - 23) ** 2 + (y - 13) ** 2) ** 0.5
            if d <= 5.2: st.putpixel((f * SC + x, 10 * SC + y), W)
    rect(f, 10, 22, 12, 24, 14, K)
    for a in range(4):  # dientes de la sierra (giran)
        import math
        ang = a * math.pi / 2 + f * math.pi / 4
        rect(f, 10, int(23 + 6.4 * math.cos(ang)), int(13 + 6.4 * math.sin(ang)), int(23 + 6.4 * math.cos(ang)), int(13 + 6.4 * math.sin(ang)), W)
    rect(f, 10, 4, 27, 27, 27, W)
    # 11 centro de mineros: entrada de mina en roca + vagoneta
    tri(f, 11, 16, 5, 24, 13, W); rect(f, 11, 11, 15, 20, 24, K); rect(f, 11, 11, 15, 11, 24, W); rect(f, 11, 20, 15, 20, 24, W)
    rect(f, 11, 10, 14, 21, 14, W); rect(f, 11, 22 + f, 21, 29 + f, 25, W); rect(f, 11, 23 + f, 26, 24 + f, 27, W); rect(f, 11, 27 + f, 26, 28 + f, 27, W)
    rect(f, 11, 2, 27, 29, 27, W)

for f in range(2):
    # 12 centro de bestias: establo con cabeza de bestia asomando
    rect(f, 12, 4, 14, 27, 27, W); tri(f, 12, 16, 6, 14, 13, W); rect(f, 12, 4, 14, 27, 14, K)
    rect(f, 12, 11, 18, 20, 27, K); rect(f, 12, 13 + f, 19, 18 + f, 23, W); rect(f, 12, 14 + f, 20, 14 + f, 20, K)
    rect(f, 12, 13 + f, 17, 13 + f, 18, W); rect(f, 12, 18 + f, 17, 18 + f, 18, W)

# 5 arbol muerto con cara (de reference/arbol_y_otros.html): silueta blanca, ojos huecos negros
C = {'r': '#000000', 'R': '#000000', 'b': '#ffffff', 'n': '#ffffff', 'A': '#ffffff', 'K': '#ffffff'}
def tree(f):
    Wd, H = 24, 26; g = [['.'] * Wd for _ in range(H)]
    def p(x, y, c):
        x = int(round(x)); y = int(round(y))
        if 0 <= x < Wd and 0 <= y < H: g[y][x] = c
    def line(x0, y0, x1, y1, t, c):
        n = max(abs(x1 - x0), abs(y1 - y0)) or 1
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n; y = y0 + (y1 - y0) * i / n
            for a in range(t):
                for b in range(t): p(x + a, y + b, c)
    sw = 1 if f else 0
    line(12,22,5,24,2,'n'); line(5,24,2,25,1,'n'); line(14,22,19,24,2,'n'); line(19,24,22,25,1,'n'); line(11,23,8,25,1,'n'); line(15,23,16,25,1,'n')
    for y in range(12, 23):
        w = 3 + (y - 12) // 3; x0 = 12 - w // 2
        for x in range(w): p(x0 + x, y, 'A' if x == 0 else ('K' if x >= w - 1 else 'n'))
    line(11,12,6,6,2,'n'); line(6,6,3+sw,1,1,'n'); line(6,6,2,5,1,'n'); line(2,5,1+sw,3,1,'n')
    line(12,12,13,5,2,'n'); line(13,5,10+sw,0,1,'n'); line(13,5,17+sw,2,1,'n')
    line(13,12,18,7,2,'n'); line(18,7,22+sw,6,1,'n'); line(18,7,21+sw,2,1,'n')
    line(10,13,4,11,1,'n'); line(4,11,2,15,1,'n')
    for x in (10, 11, 13, 14): p(x, 15, 'R' if f else 'r')
    p(11,16,'K'); p(13,16,'K')
    for x in range(10, 15): p(x, 19, '.'); p(x, 20, '.')
    p(11,18,'b'); p(13,18,'b'); p(12,21,'b')
    return g
for f in range(2):
    g = tree(f); ox = f * SC + (SC - 24) // 2; oy = 5 * SC + (SC - 26) - 1
    for y, line in enumerate(g):
        for x, ch in enumerate(line):
            if ch in C: st.putpixel((ox + x, oy + y), hexc(C[ch]))
# seguridad: cualquier pixel queda en blanco o negro puro
px_ = st.load()
for y in range(st.height):
    for x in range(st.width):
        r, g, b, a = px_[x, y]
        if a:
            px_[x, y] = W if (r + g + b) > 60 else K
st.save(os.path.join(ROOT, "assets/atlas/structures.png"))
print("atlas ok: proyectiles", pj.size, "estructuras", st.size)

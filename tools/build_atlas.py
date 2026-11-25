#!/usr/bin/env python3
"""Genera los atlas PNG a partir de art/sprites.json (+ estructuras dibujadas aqui).
Uso:  python3 tools/build_atlas.py
Salida: assets/atlas/units.png (celdas 16x16, 2 fotogramas por fila)
        assets/atlas/structures.png (celdas 32x32, 2 fotogramas por fila)
Filas unidades: 0 goblin, 1 orc, 2 dwarf, 3 elf. Columnas: 0-1 fotogramas, 2 proyectil.
Filas estructuras: 0 tienda, 1 ayuntamiento, 2 casa, 3 cuartel, 4 torre, 5 arbol, 6 mineral, 7 fortaleza.
Todas las estructuras y el entorno salen en blanco/grises (regla de arte del diseñador)."""
import json, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spr = json.load(open(os.path.join(ROOT, "art/sprites.json")))["sprites"]
order = ["goblin", "orc", "dwarf", "elf"]
UC = 16
img = Image.new("RGBA", (UC * 3, UC * len(order)), (0, 0, 0, 0))  # col 0-1 fotogramas, col 2 proyectil
def hexc(h): h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4)) + (255,)
for row, name in enumerate(order):
    s = spr[name]; pal = {k: hexc(v) for k, v in s["palette"].items()}
    w, h = s["width"], s["height"]
    for frame in range(2):
        ox = frame * UC + (UC - w) // 2
        oy = row * UC + (UC - h - 1) + frame  # fotograma 2: 1px más abajo (balanceo)
        for y, line in enumerate(s["rows"]):
            for x, ch in enumerate(line):
                if ch in pal: img.putpixel((ox + x, oy + y), pal[ch])
    # proyectil: bloque 4x4 del color de la raza con centro claro (se dibuja en la columna 2)
    for y in range(6, 10):
        for x in range(6, 10):
            img.putpixel((2 * UC + x, row * UC + y), pal["l"] if (x in (7, 8) and y in (7, 8)) else pal["m"])
os.makedirs(os.path.join(ROOT, "assets/atlas"), exist_ok=True)
img.save(os.path.join(ROOT, "assets/atlas/units.png"))

SC = 32
st = Image.new("RGBA", (SC * 2, SC * 8), (0, 0, 0, 0))
W, G, D, K = (255, 255, 255, 255), (200, 200, 200, 255), (130, 130, 130, 255), (0, 0, 0, 255)
def rect(f, row, x0, y0, x1, y1, c):  # inclusive
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < SC and 0 <= y < SC: st.putpixel((f * SC + x, row * SC + y), c)
def tri(f, row, cx, top, base, half, c):  # triangulo isosceles relleno
    for y in range(top, base + 1):
        w = int(half * (y - top) / max(1, base - top))
        rect(f, row, cx - w, y, cx + w, y, c)
def px(f, row, x, y, c): rect(f, row, x, y, x, y, c)

for f in range(2):
    # 0 tienda de campaña
    tri(f, 0, 16, 8 + f * 0, 27, 12, W); tri(f, 0, 16, 14, 27, 6, G)
    rect(f, 0, 14, 20, 18, 27, K); px(f, 0, 16, 5 + f, D); rect(f, 0, 16, 6 + f, 16, 8, D)
    # 1 ayuntamiento
    rect(f, 1, 4, 14, 27, 27, W); rect(f, 1, 4, 22, 27, 27, G)
    tri(f, 1, 16, 4, 14, 14, D); rect(f, 1, 13, 18, 18, 27, K)
    rect(f, 1, 7, 17, 10, 20, K); rect(f, 1, 21, 17, 24, 20, K)
    rect(f, 1, 15, 2, 15, 4 + f, W); rect(f, 1, 16, 2 + f, 19, 4 + f, G)
    # 2 casa
    rect(f, 2, 8, 16, 23, 27, W); tri(f, 2, 16, 8, 16, 10, D)
    rect(f, 2, 14, 21, 17, 27, K); rect(f, 2, 10, 18, 12, 20, K)
    # 3 cuartel
    rect(f, 3, 3, 12, 28, 27, W); rect(f, 3, 3, 12, 28, 15, D); rect(f, 3, 3, 24, 28, 27, G)
    for x in (4, 10, 16, 22): rect(f, 3, x, 9, x + 2, 11, W)
    rect(f, 3, 13, 18, 18, 27, K); px(f, 3, 8, 19, K); px(f, 3, 23, 19, K)
    # 4 torre
    rect(f, 4, 11, 8, 21, 27, W); rect(f, 4, 11, 8, 12, 27, G); rect(f, 4, 20, 8, 21, 27, D)
    for x in (9, 13, 17, 21): rect(f, 4, x, 4, x + 2, 8, W)
    rect(f, 4, 14, 12, 18, 15, K); rect(f, 4, 14, 22, 18, 27, K)
    rect(f, 4, 15, 1 + f, 15, 4, D); rect(f, 4, 16, 1 + f, 18, 2 + f, (255, 51, 38, 255))
    # 6 mineral
    tri(f, 6, 16, 12, 27, 11, (137, 147, 162, 255)); tri(f, 6, 12, 8, 20, 5, (210, 220, 235, 255))
    rect(f, 6, 18, 18, 22, 21, (255, 214, 90, 255)); px(f, 6, 14, 22, (255, 214, 90, 255))
    # 7 fortaleza
    rect(f, 7, 1, 12, 30, 28, W); rect(f, 7, 1, 22, 30, 28, G)
    for x in (1, 7, 13, 19, 25): rect(f, 7, x, 7, x + 4, 12, W)
    rect(f, 7, 12, 16, 19, 28, K); rect(f, 7, 5, 16, 8, 19, K); rect(f, 7, 23, 16, 26, 19, K)
    rect(f, 7, 15, 0, 15, 6, D); rect(f, 7, 16, f, 21, 3 + f, (255, 51, 38, 255))

# 5 arbol muerto con cara (portado de reference/arbol_y_otros.html)
C = {'r': '#000000', 'R': '#000000', 'b': '#f3ead2', 'n': '#7a7062', 'A': '#b8ae98', 'K': '#3d372f'}
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
# Regla de arte: estructuras y entorno en blanco/grises (solo las tropas y proyectiles llevan color)
px_ = st.load()
for y in range(st.height):
    for x in range(st.width):
        r, g, b, a = px_[x, y]
        if a == 0:
            continue
        v = int(0.3 * r + 0.59 * g + 0.11 * b)
        v = 0 if v < 8 else min(255, int(70 + v * 0.75))  # negro puro se queda negro (huecos)
        px_[x, y] = (v, v, v, a)
st.save(os.path.join(ROOT, "assets/atlas/structures.png"))
print("atlas ok:", img.size, st.size)

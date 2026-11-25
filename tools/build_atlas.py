#!/usr/bin/env python3
"""Genera los atlas PNG a partir de art/sprites.json (+ estructuras dibujadas aqui).
Uso:  python3 tools/build_atlas.py
Salida: assets/atlas/units.png (celdas 16x16, 2 fotogramas por fila)
        assets/atlas/structures.png (celdas 32x32, 2 fotogramas por fila)
Filas unidades: 0 goblin, 1 orc, 2 dwarf, 3 elf. Columnas: 0-1 fotogramas, 2 proyectil.
Filas estructuras: 0 tienda, 1 ayuntamiento, 2 casa, 3 cuartel, 4 torre, 5 arbol, 6 mineral, 7 fortaleza.
Estructuras y entorno: solo blanco y negro puro, formas simples (regla de arte del diseñador)."""
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
print("atlas ok:", img.size, st.size)

# Orcos vs. Alianza (título provisional)

RTS con capa roguelike. Godot **4.7.2**, GDScript. El diseño está en `GDD.md` (el apartado 0 recoge los últimos cambios del diseñador). El estado de cada hito está en `docs/PROGRESO.md`.

## Abrir y jugar
1. Abre Godot 4.7.2, pulsa *Importar* y elige `project.godot`.
2. Pulsa F5. Arranca el menú principal (`scenes/main/Main.tscn`).
   - **Campaña Goblins · Mapa 1**: el mapa se genera con la semilla que pongas; la misma semilla da siempre el mismo mapa.
   - **Hito 0 · Benchmark**: dos ejércitos peleando para medir el rendimiento.

## Controles
| Acción | Teclado y ratón | Mando |
|---|---|---|
| Mover el héroe | WASD | Stick izquierdo |
| Modo lanzar (dial) | Mantener Q | Mantener LB |
| Cambiar tipo en el dial | Rueda, E / R | D-pad izquierda/derecha o stick derecho |
| Lanzar tropas | Clic izquierdo (mantener = ráfaga) | Gatillo derecho (apunta hacia donde caminas) |
| Salir del modo lanzar | Soltar Q o clic derecho | Soltar LB o B |
| Elegir qué tropas llevas | Tab | Back / Select |
| Reparar puente / abrir paso | F (al lado de la barrera) | A |
| Panel de depuración | F3 | — |
| Volver al menú | Esc | — |

## Estructura
```
data/            números del juego (JSON): units, hero, world, buildings
scenes/          escenas .tscn reales (main, world, battle, hero, ui, benchmark)
src/sim/         simulación pura (sin nodos): UnitDB, SpatialGrid, BattleSim + nodo Battle
src/render/      dibujado por instancias: SpriteBatch (MultiMesh), SimRenderer
src/world/       MapGenerator, MapData, WorldView, WaveDirector, World
src/hero/        Hero, TroopStore, TroopLauncher
src/ui/          menú, HUD, dial, menú de tropas, panel de depuración
assets/atlas/    atlas PNG generados desde art/sprites.json (tools/build_atlas.py)
tools/           pruebas y medidas sin ventana
```

## Herramientas (opcional, desde la carpeta del proyecto)
```
godot --headless --path . --import                                       # 1ª vez: registra las clases
godot --headless --path . -s tools/bench_headless.gd -- 1000 400          # ms por paso con 2x1000 unidades
godot --headless --path . -s tools/test_world.gd -- 300                   # 300 semillas: determinismo + caminos
godot --headless --path . --fixed-fps 60 -s tools/smoke_world.gd -- 123  # partida automática de prueba
python3 tools/build_atlas.py                                              # regenerar atlas tras tocar sprites
```

# Contrato de assets entre arte y código

Este documento explica cómo usa el motor los assets, para que el arte encaje sin tocar código.
Lo leo por **manifests**, así que añadir o reordenar filas no rompe nada.

> Las decisiones de estilo las toma Neku. Este contrato vale tanto para estructuras en blanco y negro como para estructuras con color: el color lo pone el tinte de cada tipo en `data/units.json`.

## 1. Unidades: `assets/atlas/units.png` + `units_manifest.json` {id_sprite: fila}
- Celda de **16x16**. Columnas **0 y 1** = dos fotogramas. Columna **2** = proyectil de esa fila (opcional; los proyectiles también pueden ir en filas propias, indicándolo en el manifest).
- El sprite va centrado en horizontal y apoyado abajo, dejando 1 px libre debajo.
- **Color**: el shader multiplica el color del atlas por el tinte de cada instancia. Lo ideal son sprites en **blanco #FFFFFF** con los huecos en **negro #000000**; el color de cada tropa va en `"tint"` en `data/units.json`.
- Montadas: celda de 16x16 si caben. Si no, un atlas aparte `mounted.png` con celda de 24x16.
- El héroe usa también una fila de este atlas.
- Ids sugeridos: `goblin_warrior`, `goblin_archer`, `goblin_mage`, `goblin_brute`, `goblin_warrior_warg`… Proyectiles: `proj_arrow`, `proj_stone`, `proj_magic`, `proj_bolt`.

## 2. Estructuras: `assets/atlas/structures.png` + `structures_manifest.json`
- Celda de **32x32**, con 2 columnas para los fotogramas. Los sprites más pequeños van centrados y con la base hacia y≈28. Una sola medida de celda por atlas.
- Los golpes se muestran invirtiendo blanco↔negro. Si las estructuras pasan a tener color, se cambia a un destello.
- Ids en uso: `camp_tent`, `townhall`, `house`, `barracks`, `enemy_hall`, `enemy_tower`, `fortress`, `lumber_center`, `miners_center`, `tree_landmark`, `ore`.
- Próximos: `beast_center`, `engineering_center`, `wall`, `tower_archer`, `tower_cannon`, `mortar`, `ritual_lvl1`, `ritual_lvl2`, `scaffold`.

## 3. Terreno: `assets/atlas/terrain.png` + `terrain_manifest.json` {nombre: [x,y,w,h]}
- El suelo se hornea con celdas de 16 px y se trocea en texturas de 512 px. Las piezas de 10x10 centradas en 16x16 valen.
- Clases:
  - `ground_inicio`, `ground_centro`, `ground_final`, con 3 o 4 variantes cada una.
  - `water`, que encaje en mosaico. La costa la dibuja el código, salvo que llegue `water_edge_*`.
  - `road`, con 2 variantes.
  - `mountain`: sello de 16x20 que puede sobresalir hacia arriba.
  - `forest_tree`: sello de unos 8x10.
  - `void_star`, con 4 a 6 variantes.

## 0. Estado actual (integrado en el juego)
- `assets/atlas/units_foot.png` (16x16, blanco + tinte), `units_mounted.png` (20x20, ya coloreado, tinte blanco), `beasts.png` (16x16, blanco + tinte) y `art_manifest.json`. Copiados de la rama de arte (`assets/concepto_2/`).
- En `data/units.json`, `"sprite"` es el id del manifest y `"atlas"` vale foot, mounted, beast o structure. La rejilla de cada atlas se lee del manifest, así que se pueden añadir filas sin tocar escenas.
- Para actualizar, se copian los PNG y el manifest nuevos a `assets/atlas/`. Si cambian los ids, se ajusta `data/units.json`.
- Los proyectiles (`assets/atlas/projectiles.png` + `projectiles_manifest.json`, celdas de 8x8) son provisionales, generados con `tools/build_atlas.py`.

## 4. Arquetipos (decidido por Neku)
- Ids internos: `base`, `brute`, `ranged`, `special`. El dial tiene 4 casillas.
- Mapeo: base → sprite `base`, brute → `guerrero`, ranged → `arquero`, special → `mago`. El mago sustituye al bombardero.
- Montadas: tipos `<raza>_<arquetipo>_mounted` en `units.json`. No se eligen: salen por probabilidad al lanzar, y esa probabilidad la da el Centro de bestias. Las bestias son tipos `beast_*`.

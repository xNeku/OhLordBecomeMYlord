# Progreso — 25 nov 2026

## Hecho en esta tanda

### Hito 0 · Rendimiento ✅ (falta que lo midas en tu Mac y en la tablet)
- Una unidad no es un nodo: vive en arrays empaquetados dentro de `BattleSim` (`src/sim/battle_sim.gd`), que no conoce escenas y se ejecuta sin ventana.
- Paso fijo a 20 Hz con interpolación al dibujar. La rejilla espacial es propia (sin físicas). Los objetivos se reevalúan de forma escalonada.
- Se dibuja todo con 4 MultiMesh: estructuras, unidades, partículas de muerte y proyectiles. Son unas 14 llamadas de dibujo, haya las unidades que haya.
- Escena `scenes/benchmark/Benchmark.tscn`: con +/-500 cambias el tamaño de los ejércitos y F3 muestra FPS, ms por paso y unidades.

**Medidas en el servidor de pruebas** (Linux, sin GPU, 1 hilo, solo simulación):

| Unidades | ms/paso media | p95 | Presupuesto (20 Hz) |
|---|---|---|---|
| 2.000 | 20 | 33 | 50 |
| 5.000 | 51 | 76 | 50 |
| 10.000 | 98 | 146 | 50 |

Cómo leerlo: con 2.000 unidades la simulación cabe de sobra en su presupuesto. Pero el paso corre en el hilo principal y se come unos 20 ms una vez de cada tres frames, así que pueden aparecer tirones a 60 FPS. **El siguiente paso de rendimiento** es mover `BattleSim.step()` a un hilo (`WorkerThreadPool`). Ya está preparado porque la simulación no toca nodos. Para 10.000 unidades hará falta eso más GDExtension.
**Te toca:** abre el Benchmark en el Mac y en la tablet y apunta FPS y "ms/paso" con 2.000, 5.000 y 10.000.

### Hito 1 · Mundo mínimo ✅
- `MapGenerator` + `MapData`: 3 zonas (islas irregulares) unidas por 2 barreras (puente roto y mar), punto de aparición, ayuntamiento y casas, campamentos neutrales por nivel, avanzada enemiga con torres, fortaleza final, árboles y mineral. Las cantidades y composiciones están en `data/world.json`.
- Comprobado con 300 semillas: misma semilla → mismo mapa, y todo es alcanzable desde el inicio abriendo las barreras.
- El héroe se mueve por el suelo, con cámara a zoom x2 y límites del mapa.

### Hito 2 · Tropas ✅ (versión prototipo)
- Dial de 4 arquetipos (escenas `TroopDial` + `DialSlot`) con el modo lanzar: radio alrededor del héroe y el punto se pega a suelo válido.
- Las tropas lanzadas luchan solas: atacan lo más cercano y, si no hay nada cerca, van a la estructura hostil más cercana de su zona.
- Los campamentos neutrales defienden y dan recompensa al destruir la tienda.
- Ataque cuerpo a cuerpo, a distancia (con proyectil de color) y kamikaze con daño en área.

### Ya con tus cambios de hoy
- **Tropas gratis**: el menú Tab (`LoadoutPanel`) reparte la capacidad del héroe entre los tipos. El cuartel repone gratis hasta lo elegido. La capacidad, los tipos desbloqueados y la velocidad de reposición están en `data/hero.json`, listos para que las mejoras los suban.
- **Recursos** solo para construir y mejorar. Ahora mismo se usan para reparar el puente y abrir el mar.
- **Arte**: fondo negro; islas, barreras, estructuras, árboles y mineral en blanco; tropas y proyectiles de color.
- Catálogo de estructuras en `data/buildings.json` (centros de mineros, madera, bestias e ingeniería; murallas, torres, morteros; rituales con los conceptos 1 y 2). Todavía no se pueden construir: es el Hito 3.

### Adelantado del Hito 4 (versión mínima)
- Oleadas enemigas crecientes (`WaveDirector`, datos en `world.json > waves`) que entran por el borde de tu zona y atacan tu base.
- Victoria al destruir la fortaleza y derrota si cae el ayuntamiento, con pantalla final para reintentar o volver al menú.

## Pruebas realizadas (todas sin ventana, en el servidor)
- `tools/test_world.gd`: 300 semillas sin problemas.
- `tools/smoke_world.gd`: partida automática con 14 comprobaciones, todas OK. Cubre: lanzar tropas, límite del reparto, reposición gratis, cobro de la recompensa de un campamento, apertura de barrera (para el héroe y para la simulación), cruce a la zona 2 y llegada de una oleada.
- Capturas renderizadas del benchmark y del mundo con OpenGL por software.
- **Sin probar:** mando físico, Mac, Android y el rendimiento con GPU real.

## Simplificaciones y cosas que decidí yo (cámbialas si quieres)
- El dial se elige con rueda, E/R o stick derecho, **no moviendo el ratón**, porque el ratón ya apunta dónde caen las tropas.
- Con mando se lanza en la dirección en la que caminas, a unos 80 px del héroe.
- Las tropas no saltan entre zonas; las oleadas aparecen ya en tu zona, en el lado de la primera barrera.
- El héroe es invulnerable por ahora.
- Los neutrales persiguen a quien entra en su radio y no vuelven a su sitio.
- No hay orden de dibujo por profundidad (Y-sort) dentro de la masa de unidades.
- Faltan los números de daño agrupados y la niebla de guerra.

## Preguntas para Neku
1. ¿Las tropas se reponen solas con el tiempo, solo al volver a la base o de otra forma?
2. ¿La capacidad del héroe sube por tipo o es un total que repartes? He hecho un total que repartes.
3. ¿Las estructuras enemigas van también en blanco (como ahora) o con un detalle de color de su bando para leerlas mejor?
4. ¿Qué estructura va primero en el Hito 3? Propongo: ayuntamiento con reparto, cuartel (desbloquear y mejorar tropas) y centros de mineros y madera.

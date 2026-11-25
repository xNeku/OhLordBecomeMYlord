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

### Arte del mundo (segunda pasada, según tus referencias)
- Mundo continuo: 3 regiones de tierra rodeadas de mar, con estrellas fuera del mapa. El puente y el paso de barco cruzan el mar.
- Cada terreno se reconoce por su trama, sin color:
  - Agua: rayado diagonal con olas.
  - Cordilleras: picos con una cara maciza y otra rayada.
  - Bosques: arbolitos.
  - Caminos: punteado.
  - Costa: línea blanca continua.
- Cada región tiene su textura de suelo: matojos (inicio), dunas (centro) y ceniza (base final).
- Las montañas y los lagos bloquean el paso, y los caminos (A*) unen tu base, los puentes, la avanzada y la fortaleza. Siempre hay camino; comprobado con 200 semillas.
- Las estructuras están redibujadas más simples, solo en blanco y negro puro. Al recibir un golpe invierten blanco↔negro, porque un destello blanco no se vería.
- El suelo se hornea una vez al cargar (unos 160 ms) en texturas de 512 px, para que valga en móvil.
- Los números del relieve (cuánta montaña, lago y bosque) están en `data/world.json > terrain`.
- Pendiente: las tropas aún no rodean montañas, van en línea recta. Toca añadir mapas de flujo, como prevé el GDD.

### Hito 3 · Base (con tus respuestas) ✅ versión prototipo
- **Tab abre el menú de base**, con 3 pestañas (todas son escenas en `scenes/base/`):
  - **Ayuntamiento**: tres barras de construir, madera y minería que siempre suman 100 %. Ves los trabajadores y lo que produces por segundo, y construyes casas (+3 trabajadores), cuartel, centro de madera (+75 % madera) y centro de mineros (+75 % mineral). Las obras se levantan solas alrededor del ayuntamiento, con andamio y barra de progreso; cuanta más gente en "construir", más rápido.
  - **Cuartel**: desbloquear bruto, distancia y especial; mejorar la vida y el daño de cada tipo (+15 % por nivel, hasta 5); ampliar la capacidad del héroe (+30 huecos por nivel). Todo requiere el cuartel construido.
  - **Tropas**: cuántas llevas de cada tipo. Cada una ocupa sus huecos: base 1, distancia 2, especial 3, bruto 4.
- **Reposición**: solo en tu base (cerca del ayuntamiento), tras 2 s de descanso y gratis. El HUD avisa con "vuelve a la base para reponer" y "reponiendo...".
- Empiezas solo con goblins base, 60 huecos y 90 de madera y 40 de mineral para levantar el cuartel enseguida.
- **Estructuras enemigas** en blanco con detalles muy reconocibles: la base tiene cuernos, pinchos y calavera; la torre, pinchos y un ojo que parpadea; la fortaleza, pinchos y calavera.
- Todos los números están en `data/economy.json`, `data/buildings.json` (`construibles` y `mejoras_cuartel`), `data/hero.json` (`troops`) y `slots` en `data/units.json`.

### Integración del arte del director artístico ✅
- Las tropas usan los sprites del Concepto 2 (`assets/atlas/units_foot.png`, `units_mounted.png`, `beasts.png`) con los colores de raza nuevos: enano naranja, elfo azul, goblin verde y orco rojo.
- **Mago** en las 4 razas: ataque a distancia con daño en área y proyectil mágico. Sustituye al bombardero.
- **Centro de bestias** (construible): +15 % por cada uno de que guerreros, arqueros y magos salgan **montados**. Los montados tienen más vida, velocidad y daño.
- **Bestias** como unidades propias. Ya aparecen como defensores en los campamentos neutrales: warg en los de nivel 2; oso y dientes de sable en los de nivel 3.
- Proyectiles de color según la raza: piedra goblin, flecha elfa y orca, virote enano, orbe mágico.
- Terreno con **color apagado sobre negro**: verde en el inicio, arena en el centro, ceniza en la final, agua azul y montañas grises. Las tropas siguen destacando. Es provisional hasta que llegue el terreno del director de arte; los colores están en `data/world.json > ground.colors`.
- **Tanda 2 del director de arte integrada**:
  - Estructuras coloreadas: las tuyas en gris y madera; las enemigas en carmesí y hueso; el campamento tostado con banderín magenta.
  - Proyectiles nuevos.
  - Terreno completo del atlas de arte: suelos por región, agua, caminos, montañas, árboles y estrellas.
  - Las bestias llevan sus colores de dos tonos.
  - El golpe en estructuras vuelve a ser un destello blanco.

### Tanda 3 del director de arte + reglas de mapa de Neku ✅
- **Mapa nuevo** (`src/world/map_generator.gd`), con tus reglas:
  - Las regiones de inicio y centro forman un continente separado por una **cordillera** de costa a costa. Hay además **crestas** interiores. Las montañas solo se cruzan por los **pasos** que abren los caminos.
  - Un **río** nace en la cordillera y baja hasta el mar. Su **puente roto** es la primera barrera; se repara con F.
  - La región final es una isla al otro lado del estrecho (muelle y barco).
  - **Bosques en masas** densas, con árboles sueltos en el borde.
  - **Caminos** que unen tu base, los campamentos, la avanzada y la fortaleza: esquivan bosque y montaña, y abren pasos y puentes.
  - **Filones** de mineral en los muros de montaña que dan al llano.
  - Comprobado con 200 semillas: siempre hay camino.
- **Terreno con piezas que se ajustan a sus vecinos** (autotiles): muro, río y camino. Más puentes, bosque, suelo por región y estrellas.
- **Estructuras por raza**: tú usas las goblin y el enemigo del mapa 1 las enanas.
- **Recursos que no se agotan**: el centro de madera se construye pegado a un bosque y el de mineros pegado a un muro. Se ven **leñadores y mineros** yendo y trabajando; su número sigue al reparto de trabajadores.
- **Tropas que rodean obstáculos**: cuando van hacia una estructura lejana siguen un **mapa de flujo** (la distancia andando, calculada una vez por objetivo), así que rodean muros y ríos. Las oleadas enemigas también.
- **Filtros de visión** (CRT, LCD, ámbar y Game Boy), probados en Godot y funcionando. Se cambian desde el **menú de pausa (Esc)** o desde el menú principal, y la elección se guarda.

## Pruebas realizadas (todas sin ventana, en el servidor)
- `tools/test_world.gd`: 300 semillas sin problemas.
- `tools/smoke_world.gd`: partida automática con 30 comprobaciones, todas OK en las semillas 123, 7, 55 y 9. Además de lo de antes, cubre: no reponer lejos de la base, reponer descansando en ella, producción de madera, construir el cuartel, desbloquear, mejorar stats y ampliar capacidad. Cubre: lanzar tropas, límite del reparto, reposición gratis, cobro de la recompensa de un campamento, apertura de barrera (para el héroe y para la simulación), cruce a la zona 2 y llegada de una oleada.
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
1. Lo que cuesta cada cosa (edificios, mejoras, desbloqueos) es una primera estimación. Pruébalo y dime si va lento o rápido; se cambia en los JSON sin tocar código.
2. ¿Las obras se colocan solas alrededor del ayuntamiento (como ahora) o prefieres elegir tú el sitio?
3. Siguiente paso: ¿tropas que rodean montañas y simulación en otro hilo (rendimiento), o defensas y rituales?

# GDD — Orcos vs. Alianza (título provisional)

Autor: Neku (diseñador). Nov 2026.
Para: sesión de Claude Code que implementa el juego. Neku diseña, tú programas.

Leyenda: **[Decidido]** lo ha fijado el diseñador · **[Propuesta]** idea de Claude pendiente de validar · **[Abierto]** sin resolver.

---

## 1. Visión y pilares

RTS libre con capa roguelike. Controlas solo a tu héroe, lanzas ejércitos que luchan solos y ves masas enormes de unidades chocando, con feedback constante ("dopamina de la buena").

**Pitch [Decidido]**
- Género: RTS libre estilo Warcraft 3 / Age of Empires, con base, mapa generado y un objetivo final por campaña.
- Facciones: goblins, orcos, enanos y elfos. Cada campaña se juega con una. La primera es la de **Goblins**.
- Todas las facciones atacan y defienden. Se diferencian por estilo de juego, no por rol.
- Ritmo rápido y explosivo, espíritu roguelike.
- Escala: cientos o miles de unidades legibles en pantalla. Los 50.000 de las primeras charlas eran una exageración; quedan como techo de optimización futura.

**Pilares**
1. Masa y espectáculo: ver el ejército entero en acción y que se sienta bien.
2. Un solo héroe, cero microgestión: no se controlan tropas ni trabajadores.
3. Decisiones de base simples: repartir porcentajes, no gestionar colas.
4. Rejugable: mapas generados y capa roguelike.
5. Mando y teclado/ratón con el mismo nivel de comodidad.

**Plataformas [Decidido]:** Linux, macOS y Windows como mínimo. Deseable: handhelds retro (Android y Linux) y Switch. Motor: **Godot 4.7.2 con GDScript**. Se optimiza después.

**Referencias:** Warcraft 3, Age of Empires y Clash of Clans (el spawn de tropas). Ambiente: «Sir, We Have an Orc Problem».

## 2. Propiedad intelectual y lore propio

El juego nace inspirado en El Señor de los Anillos, pero para venderlo debe tener mundo, nombres y lore propios. [Propuesta]

- No usar nombres, lugares, personajes ni criaturas propias de Tolkien (Mordor, Gondor, Nazgûl, Gandalf, hobbits, Uruk-hai, Ents, Balrogs y similares).
- No usar "Horda" ni "Alianza" como bandos: son términos de Warcraft (Blizzard).
- Orcos, goblins, enanos y elfos genéricos sí son utilizables (folclore). Lo que hay que inventar es el mundo, los nombres de facciones y la historia.
- Para el prototipo se usan nombres internos provisionales.
- No es asesoramiento legal: antes de lanzar, revisión legal del nombre y el lore.

## 3. Bucle de juego

Cada campaña es una partida larga en un mapa grande: montas economía, generas tropas, abres zonas y derrotas la base final. La capa roguelike hace que las siguientes campañas avancen más rápido. [Decidido]

**Dentro de una campaña [Decidido]**
1. Empiezas en tu punto de aparición con el ayuntamiento, unas casas y tu héroe.
2. Repartes a los trabajadores entre construir, madera y minería, y levantas edificios.
3. Los edificios militares generan tropas, que quedan guardadas dentro del héroe.
4. Exploras con el héroe. Con una tecla abres el dial y lanzas tropas en el mapa para atacar campamentos neutrales y bases enemigas, o para defender tu base.
5. Cada zona del mapa está separada. Cumplir una condición fija de la campaña (cruzar en barco, atravesar un puente) abre la siguiente.
6. Derrotas la base final y la campaña termina.

**Entre campañas**
- Una campaña por facción. Se empieza por Goblins; después orcos, enanos y elfos. [Decidido]
- Los mapas se generan solos: cada partida es distinta. [Decidido]
- Campaña larga, se avanza a gusto del jugador. Cuanto más avanzas, más rápido recorres la historia completa. [Decidido en intención]
- Qué se conserva entre campañas (reliquias, mejoras, desbloqueos, arranque más avanzado): [Abierto]
- Condición de derrota: ver Decisiones abiertas.

## 4. Controles

El jugador solo mueve a su héroe y lanza tropas; todo lo demás funciona solo. Debe ser cómodo con mando y con teclado y ratón. [Decidido]

La asignación de botones es una propuesta y se puede cambiar.

| Acción | Teclado y ratón | Mando |
|---|---|---|
| Mover el héroe | WASD | Stick izquierdo |
| Abrir el dial de tropas | Tecla Q (mantener) | Botón de hombro izquierdo |
| Elegir tipo en el dial | Rueda o mover el ratón | Stick derecho |
| Lanzar tropas en el mapa | Clic izquierdo | Gatillo derecho |
| Salir del modo lanzar | Soltar la tecla o clic derecho | Soltar el botón o B |
| Habilidades del héroe | 1, 2, 3 | Botones de la cara |
| Menú de base (ayuntamiento y edificios) | Clic sobre el edificio o tecla Tab | Botón de acción junto al edificio |

**Modo lanzar tropas [Decidido]:** al abrir el dial entras en un modo en el que cada clic lanza una tropa del tipo elegido, como en Clash of Clans. Las tropas lanzadas luchan solas; el jugador no les da órdenes.

**Reglas de diseño [Propuesta]**
- Ninguna acción exige precisión de píxel: con mando el cursor de lanzar se mueve con el stick y se pega a zonas válidas.
- Todos los menús se navegan con cursor de mando (d-pad y botones), sin depender del ratón.
- Los atajos de teclado son un extra: todo debe poder hacerse también con el cursor.

## 5. Héroe

Es el único personaje que controla el jugador y el que lleva las tropas dentro. Es simbólico: no es el centro del juego, pero da identidad y estilo. [Decidido]

- Se mueve libremente por el mapa y explora zonas.
- Guarda las tropas generadas hasta un límite de capacidad. [Propuesta]
- Tiene 2 o 3 habilidades activas con enfriamiento, pensadas para los momentos álgidos de una batalla (por ejemplo un grito de guerra que enfurece a las tropas cercanas). [Propuesta]
- Cada facción tiene un héroe con estilo propio, que da "estilos de juego" sin multiplicar los tipos de tropa. [Propuesta]
- Si muere, reaparece en el ayuntamiento tras una espera. [Propuesta, ver Decisiones abiertas]
- Mejora entre campañas mediante reliquias o desbloqueos. [Abierto]

## 6. Sistema de tropas

Las tropas se generan en la base, se guardan dentro del héroe y el jugador las lanza con un dial; una vez en el mapa luchan solas y no reciben órdenes. [Decidido]

**Flujo**
1. **Generación.** Los edificios militares producen tropas a cambio de recursos y tiempo. [Propuesta, en el detalle]
2. **Almacén.** Las tropas generadas quedan dentro del héroe, hasta un límite. [Propuesta]
3. **Dial.** Una tecla abre un dial radial con los tipos de tropa y cuántas hay de cada uno. Al abrirlo se entra en el modo lanzar.
4. **Lanzar.** Cada clic coloca tropas en ese punto del mapa. Desde ahí actúan solas.
5. **Comportamiento.** Avanzan hacia el enemigo o la estructura enemiga más cercana y la atacan. Sin órdenes, sin selección. [Propuesta, en el detalle]

**Dónde se puede lanzar [Abierto].** Propuesta: dentro de un radio alrededor del héroe, nunca sobre edificios enemigos. Así el héroe tiene que acercarse al combate y hay riesgo y decisión de posicionamiento.

**Variedad simplificada [Propuesta].** Cada facción tiene solo 4 arquetipos, cada uno con su propia versión en cada raza. El estilo de juego sale de la composición del ejército, el héroe y las reliquias, no de tener muchas unidades distintas.

| Arquetipo | Papel | Coste relativo |
|---|---|---|
| Base | Masa barata que cae rápido | Bajo |
| Bruto | Aguanta daño y abre paso | Alto |
| Distancia | Hace daño desde atrás | Medio |
| Especial | Rasgo propio de la facción (kamikaze, jinete, curandero) | Medio o alto |

Las mejoras son globales por arquetipo (por ejemplo "todas las tropas Base +10 % de vida"), no por unidad. Evita árboles de tecnología grandes y encaja con el ritmo rápido.

## 7. Base y economía

Los trabajadores no se controlan: el jugador solo reparte, desde el ayuntamiento, un 100 % de mano de obra entre tareas. [Decidido]

**Reparto de tareas [Decidido]**
- Cada casa añade trabajadores.
- En el ayuntamiento se abre un menú con una barra por tarea. Los porcentajes suman 100 %.
- Ejemplo del diseñador: 15 % construir, 40 % madera, 50 % minería (suma 105, solo ejemplo; el juego fuerza el total a 100 %).
- Solo hay dos recursos: **madera** y **minería**. No habrá más.

| Tarea | Qué produce |
|---|---|
| Construir | Velocidad a la que se levantan los edificios |
| Madera | Madera por segundo |
| Minería | Mineral por segundo |

**Propuestas (sin validar)**
- Los trabajadores son un número, no unidades individuales con IA. Simplifica y ahorra mucho rendimiento. Se pueden mostrar sprites ambientales como decoración.
- Al cambiar el reparto el efecto es inmediato o casi, para que sea fácil de probar y se sienta rápido.
- Edificios de la primera versión: ayuntamiento, casa y cuartel (genera tropas). Defensas como torres quedan como pregunta abierta.
- Los edificios cuestan madera y mineral; las tropas, sobre todo mineral. La proporción exacta se ajusta en las pruebas.
- Los cuarteles deben poder construirse y producir muy rápido al principio de la campaña para mantener el ritmo explosivo.

## 8. Mapa procedural y zonas

Cada campaña se juega en un mapa generado automáticamente y dividido en zonas separadas; se accede a la siguiente al superar una condición fija de esa campaña. [Decidido]

**Contenido del mapa [Decidido]**
- Punto de aparición del jugador.
- Bases enemigas, incluida la base final.
- Campamentos neutrales.
- Recursos: madera y mineral.

**Zonas y barreras [Decidido]**
- Las zonas están separadas y no se puede pasar de una a otra sin cumplir una condición.
- Las condiciones son por campaña. Ejemplos del diseñador: cruzar en barco, atravesar un puente. La lista exacta de cada campaña se fija a mano.

**Propuestas (sin validar)**
- El mapa se genera a partir de una semilla, para repetir un mapa y depurar errores.
- El generador siempre debe dejar un camino posible desde el punto de aparición hasta la base final, pasando por las barreras.
- La dificultad de campamentos y bases crece con la distancia al punto de aparición.
- Niebla de guerra simple: lo no explorado se ve en negro. Encaja con el fondo negro del estilo visual.
- Las zonas se dibujan como islas de color sobre el vacío negro y las barreras como huecos que hay que salvar.

## 9. IA enemiga

El diseñador dejó esta sección sin definir. Lo que sigue es una propuesta mínima para tener algo jugable. [Propuesta]

- **Bases enemigas:** cada una genera tropas con el mismo sistema de arquetipos que el jugador y las envía en oleadas hacia el punto más cercano del jugador.
- **Agresividad creciente:** el tamaño y la frecuencia de las oleadas suben con el tiempo de partida, para que nadie se quede construyendo sin presión.
- **Campamentos neutrales:** no se mueven. Tienen un grupo fijo de defensores y una recompensa (recursos o una mejora) al ser destruidos.
- **Base final:** la más fuerte del mapa. Destruirla termina la campaña.
- **Comportamiento de las tropas enemigas:** el mismo que el de las del jugador: avanzan hacia lo más cercano y atacan.

En el primer prototipo basta con un temporizador que lance oleadas crecientes desde una base enemiga. La IA con expansión propia se deja para más adelante. [Abierto]

## 10. Campaña 1: Goblins, mapa 1

La primera campaña jugable es la de los Goblins y lo primero que se construye es su primer mapa. [Decidido]

**Estilo de la facción [Propuesta].** Enjambre barato y explosivo: muchas tropas débiles que ganan por número y por kamikazes, con un héroe de jefe goblin.

| Arquetipo | Tropa goblin (provisional) |
|---|---|
| Base | Goblin con garrote |
| Bruto | Goblin con escudo grande |
| Distancia | Goblin lanzador de piedras |
| Especial | Goblin bombardero (kamikaze) |

**Mapa 1 [Propuesta, para ajustar]**
- Tres zonas: inicio, centro y base final.
- Primera barrera: un puente roto que se repara gastando madera.
- Segunda barrera: un río o mar que se cruza construyendo un muelle y un barco.
- Zona de inicio con un par de campamentos neutrales fáciles, para enseñar el lanzar tropas.
- Zona central con campamentos más fuertes y una base enemiga que lanza oleadas.
- Zona final con la base final.
- Enemigo del mapa 1 (enanos, elfos u orcos): [Abierto]. Sugerencia: enanos, porque sus defensas contrastan con el enjambre goblin.

**Meta del primer prototipo jugable [Decidido]:** antes de pulir nada hay que tener un mapa generado y el sistema de tropas funcionando. Los detalles de campaña (historia, diálogos, el enano en oso que da el aviso) vienen después.

## 11. Estética y arte

Pixel art muy simple sobre fondo negro, sin contornos, con colores planos y saturados que contrastan fuerte con el negro; formato OLED moderno. El diseñador valoró primero un estilo "agresivo/grotesco", lo descartó por demasiado complejo y pidió unidades **simples, graciosas y llamativas**, pensando en que habrá montones apilados. [Decidido]

**Dirección de arte**
- Fondo negro puro (#000000) siempre. Sin contornos: la forma la dan los bloques de color. [Decidido]
- Siluetas gordas, cabeza grande, ojos como huecos negros. Se leen aunque estén apiladas. [Decidido]
- **Un color dominante por raza** para distinguir bandos en masa. [Decidido]
- Cada raza tiene silueta propia: goblin pequeño y orejón, orco grande con colmillos, enano bajo y barbudo, elfo alto y flaco. [Decidido]
- El árbol muerto con cara gustó mucho: se mantiene como pieza de referencia para el entorno (ver `reference/arbol_y_otros.html`). [Decidido]
- Los sprites actuales son provisionales y el diseñador los pulirá. Cambiar el estilo no debe afectar a la lógica. [Abierto]

**Paletas por raza (provisional)** — `m` principal, `l` luz, `d` sombra, `a` accesorio, `w` blanco.

| Raza | m | l | d | a | w |
|---|---|---|---|---|---|
| Goblin | #A6FF2E | #D6FF7A | #5BB800 | #FF9F1C | #FFFFFF |
| Orco | #FF5B3A | #FF9A7A | #B3200C | #B8C0D4 | #FFFFFF |
| Enano | #FF9E1F | #FFD7A0 | #C25E00 | #9AA3B5 | #FFFFFF |
| Elfo | #2CE8E0 | #D8FFF8 | #0AA0A8 | #FFE066 | #FFFFFF |

Nota: el orco es rojo anaranjado y no verde para que no se confunda con el goblin en masa. Si el diseñador lo quiere verde, cambiar el color del goblin.

**Sprites.** Están en el paquete: `art/sprites.json` (rejillas de píxeles + paletas), `art/sprites.png` (hoja de referencia) y `reference/tropas_oled.html` (página de muestra con animación y prueba de montón). Cada tropa mide unos 10–12 px de ancho por 12–14 de alto, con 2 fotogramas de animación (balanceo de 1 px).

**Reglas técnicas [Propuesta]**
- Sprites de unos 12–16 px de lado; árboles y edificios hasta unos 26.
- Escala siempre entera, filtro "nearest", sin antialiasing.
- Animaciones mínimas por unidad: quieto/mover, atacar, herido, muerte. 2 fotogramas en cada una bastan.
- Los números de daño se agrupan: con muchas tropas peleando, un número por golpe es ilegible.
- Importar las rejillas de `sprites.json` y generar texturas por código o exportar PNGs desde ellas; no redibujar a mano.

## 12. Arquitectura técnica y rendimiento

Godot 4.7.2 con GDScript, optimizando después; por eso la arquitectura debe permitir optimizar sin reescribir. [Decidido]

**Objetivos [Propuesta]**
- Primero: 2.000 unidades a la vez a 60 FPS en el Mac del diseñador y en su tablet Android.
- Segundo: 10.000 unidades.
- Techo futuro: 50.000, solo si la simulación pasa a código nativo (GDExtension en Rust o C++) o a GPU. No es requisito del prototipo.

**Reglas de arquitectura [Propuesta, obligatorias]**
1. Una unidad no es un nodo. Sus datos viven en arrays (`PackedFloat32Array`, `PackedInt32Array`) dentro de una clase de simulación.
2. La simulación está separada del dibujado. No conoce nodos ni escenas y se puede ejecutar sin ventana para medirla.
3. Paso de simulación fijo (por ejemplo 20 por segundo) con interpolación al dibujar.
4. Dibujado por instancias (`MultiMeshInstance2D` o `RenderingServer`) para unidades, proyectiles y números. Nunca un `Sprite2D` por unidad.
5. Vecinos y colisiones con una cuadrícula espacial propia. Sin `Area2D` ni cuerpos físicos por unidad.
6. Cada unidad reevalúa su objetivo cada pocos pasos, escalonado, no en todos.
7. Movimiento: ir hacia el objetivo más una separación simple. Para caminos largos, mapas de flujo compartidos.
8. Estadísticas de unidades, costes y datos de mapa en archivos de datos (`.tres` o JSON), no en el código, para que el diseñador los ajuste sin programar.
9. Pantalla de depuración con FPS, milisegundos de simulación por paso y número de unidades, y un modo de prueba que lance N unidades.

**Dato de referencia.** En un servidor de 2 núcleos, un prototipo en Rust (sin gráficos) simuló 50.000 unidades con cuadrícula espacial en unos 71 ms por paso con 1 hilo y 40 ms con 2. GDScript será bastante más lento y no está medido. Es una medición suelta de Claude, no parte del proyecto.

**Plataformas [Decidido]**
- Exportar a Linux, macOS, Windows y Android. El diseñador usa el editor de Godot 4.7.2 en una tablet Android, donde GDScript funciona y C# no.
- Switch: Godot no la exporta directamente; hay que pasar por un tercero con licencia de Nintendo. Por verificar cuando llegue el momento.
- Handhelds: modo de calidad baja con menos unidades. [Propuesta]
- Todas las acciones del jugador se definen en el `InputMap`, no como teclas fijas, para que teclado y mando compartan lógica.

## 13. Hitos y criterios de aceptación

Se trabaja por hitos pequeños, cada uno jugable y medible; el diseñador lo prueba y da feedback antes de pasar al siguiente. [Propuesta]

1. **Hito 0: prueba de rendimiento.** Una escena con dos bandos de unidades luchando, con la arquitectura del apartado 12 y con formas de color. Criterio: 2.000 unidades a 60 FPS en Mac y tablet, más un informe de cuánto aguanta cada una.
2. **Hito 1: mundo mínimo.** Mapa generado con semilla, con zonas, punto de aparición, bases enemigas, campamentos neutrales y recursos, y el héroe moviéndose por él. Criterio: la misma semilla da el mismo mapa y siempre existe un camino hasta la base final.
3. **Hito 2: tropas.** Generación, dial, modo lanzar y combate automático contra campamentos neutrales. Criterio: se pueden lanzar cientos de tropas seguidas sin bajar de 30 FPS.
4. **Hito 3: base.** Ayuntamiento con reparto de porcentajes, casas y un cuartel que genera tropas con recursos. Criterio: cambiar el reparto cambia la producción de forma visible.
5. **Hito 4: primera campaña jugable.** Goblins, mapa 1 completo, con barreras entre zonas, oleadas enemigas y base final. Criterio: se puede ganar y perder de principio a fin con teclado y ratón y con mando.
6. **Hito 5: pulido.** Estética definitiva, habilidades del héroe, capa roguelike y las demás facciones.

**Cómo trabajar cada hito**
- Cada hito termina con algo ejecutable y una lista corta de qué se probó y qué no.
- Los números de balance (vida, daño, costes, tiempos) viven en archivos de datos y se ajustan sin tocar código.
- Si el Hito 0 no llega al objetivo, se replantea el rendimiento antes de construir encima.

## 14. Decisiones abiertas

Cada una trae una propuesta por defecto para no bloquear el trabajo; el diseñador puede cambiarlas.

- [ ] **Derrota.** Propuesta: pierdes si destruyen el ayuntamiento; si muere el héroe, reaparece en el ayuntamiento tras una espera.
- [ ] **Dónde se lanzan las tropas.** Propuesta: en un radio alrededor del héroe, nunca sobre edificios enemigos.
- [ ] **Capacidad del héroe.** Límite de tropas guardadas: número total o por tipo.
- [ ] **Qué se conserva entre campañas.** Reliquias, mejoras, desbloqueos o un arranque más avanzado, para que la historia completa se recorra más rápido con el tiempo.
- [ ] **Defensas.** Si habrá torres u otras defensas en la base. En las primeras charlas hubo interés en un toque de tower defense.
- [ ] **Enemigo del mapa 1.** Propuesta: enanos.
- [ ] **Duración de una campaña.** Se quiere extensa, pero falta fijar un orden de magnitud.
- [ ] **IA enemiga.** Solo hay una propuesta mínima; falta decidir cuánto debe expandirse y adaptarse.
- [ ] **Estilo visual definitivo.** El estilo OLED actual es provisional; se pule después.
- [ ] **Cómo se cuenta la historia.** Por ejemplo, el enano en oso que avisa de una base orca: pantallas de diálogo, texto breve u otra cosa.
- [ ] **Nombre del juego y del mundo,** sin usar términos de Tolkien ni de Warcraft.

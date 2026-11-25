class_name MapData
extends RefCounted
## Resultado del generador: rejillas de zonas/barreras y la lista de entidades a colocar.
## Es solo datos: no conoce nodos ni escenas.

const VOID := 255

## Terreno por celda
const T_VOID := 0      ## fuera del mundo (estrellas)
const T_WATER := 1     ## mar / río entre zonas (bloquea; las barreras van encima)
const T_PLAIN := 2
const T_FOREST := 3    ## se puede pisar
const T_MOUNTAIN := 4  ## bloquea
const T_ROAD := 5
const T_LAKE := 6      ## agua dentro de una zona (bloquea)

var seed_value := 0
var cell := 16.0           ## píxeles por celda
var w := 0                 ## celdas
var h := 0
var zone_id := PackedByteArray()      ## zona de cada celda, VOID = vacío
var barrier_id := PackedByteArray()   ## barrera de cada celda, VOID = ninguna
var walk := PackedByteArray()         ## 1 = caminable ahora mismo
var terrain := PackedByteArray()      ## T_* por celda
var zones: Array[Dictionary] = []     ## {name,center(celdas),radius}
var barriers: Array[Dictionary] = []  ## {kind,name,cost,open,cells,pos(px),rect(px),from_zone,to_zone}
var camps: Array[Dictionary] = []     ## {level,reward,pos,zone}
var entities: Array[Dictionary] = []  ## {kind:"structure"|"unit"|"decor", ...}
var spawn := Vector2.ZERO             ## px
var raid_point := Vector2.ZERO        ## px: por dónde entran las oleadas en la zona del jugador


func size_px() -> Vector2:
	return Vector2(w, h) * cell


func idx(cx: int, cy: int) -> int:
	return cy * w + cx


func in_bounds(cx: int, cy: int) -> bool:
	return cx >= 0 and cy >= 0 and cx < w and cy < h


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / cell)), int(floor(p.y / cell)))


func cell_center(cx: int, cy: int) -> Vector2:
	return Vector2((cx + 0.5) * cell, (cy + 0.5) * cell)


func zone_at(p: Vector2) -> int:
	var c := cell_of(p)
	if not in_bounds(c.x, c.y):
		return -1
	var z := zone_id[idx(c.x, c.y)]
	return -1 if z == VOID else z


func is_walkable(p: Vector2) -> bool:
	var c := cell_of(p)
	return in_bounds(c.x, c.y) and walk[idx(c.x, c.y)] != 0


func open_barrier(i: int) -> void:
	barriers[i]["open"] = true
	for c in barriers[i]["cells"]:
		walk[c] = 1


## Barrera más cercana a `p` dentro de `max_dist` px, o -1.
func barrier_near(p: Vector2, max_dist: float) -> int:
	var best := -1
	var best_d := max_dist
	for i in barriers.size():
		var d := p.distance_to(barriers[i]["pos"])
		if d < best_d:
			best_d = d
			best = i
	return best


## Huella para comprobar que la misma semilla da el mismo mapa.
func fingerprint() -> int:
	var parts := PackedStringArray()
	parts.append(str(hash(zone_id)))
	parts.append(str(hash(barrier_id)))
	parts.append(str(hash(terrain)))
	for e in entities:
		parts.append("%s|%s|%s|%d" % [e.get("kind"), e.get("type", e.get("sprite", "")), e.get("pos"), e.get("team", -1)])
	return "|".join(parts).hash()


## Comprueba que desde el punto de aparición se llega a todo (con las barreras como pasables).
## Devuelve [] si todo bien o la lista de problemas.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var reach := PackedByteArray()
	reach.resize(w * h)
	var s := cell_of(spawn)
	var stack: Array[int] = [idx(s.x, s.y)]
	reach[stack[0]] = 1
	while not stack.is_empty():
		var c: int = stack.pop_back()
		var cx := c % w
		var cy := c / w
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if not in_bounds(nx, ny):
				continue
			var n := idx(nx, ny)
			if reach[n] == 0 and (walk[n] != 0 or barrier_id[n] != VOID):
				reach[n] = 1
				stack.append(n)
	for e in entities:
		if e["kind"] == "decor":
			continue
		var cc := cell_of(e["pos"])
		if not in_bounds(cc.x, cc.y) or reach[idx(cc.x, cc.y)] == 0:
			problems.append("inalcanzable: %s en %s" % [e.get("type"), e["pos"]])
		elif walk[idx(cc.x, cc.y)] == 0:
			problems.append("sobre terreno bloqueado: %s en %s" % [e.get("type"), e["pos"]])
	var has_final := false
	for e in entities:
		if e.get("type", "") == "fortress":
			has_final = true
	if not has_final:
		problems.append("no hay base final")
	return problems

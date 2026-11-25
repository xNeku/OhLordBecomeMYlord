class_name MapGenerator
extends RefCounted
## Genera un MapData a partir de una semilla y data/world.json.
## Misma semilla -> mismo mapa (RandomNumberGenerator y FastNoiseLite con semilla fija).
##
## Reglas de mapa (Neku):
##  1. Las montañas son MUROS continuos que dividen el mapa: una cordillera de costa a costa
##     entre las regiones unidas por tierra, y crestas interiores. Solo se cruzan por PASOS que
##     abren los caminos.
##  2. Bosques en MASAS densas.
##  3. Un RÍO nace en la cordillera y baja al mar; los caminos lo cruzan con PUENTES.
##     El puente del camino principal está roto: es la primera barrera.
##  4. Caminos (A* con costes) que unen base, campamentos, avanzada y fortaleza, esquivando
##     bosque y montaña y abriendo pasos donde hace falta.
##  5. El mineral sale de los muros (filones) y la madera de los bosques; no se agotan.
##  6. Cada región tiene su suelo (inicio / centro / final).
## La región final es una isla al otro lado de un estrecho (barrera: muelle y barco).
## Garantía: todo punto de interés es alcanzable desde la aparición abriendo las barreras.

const V := MapData.VOID

var _rng := RandomNumberGenerator.new()
var _m: MapData
var _params: Dictionary
var _tp: Dictionary
var _taken: Array[Vector2] = []    ## posiciones (celdas) ya ocupadas
var _key: Dictionary = {}          ## puntos clave en celdas: spawn, outpost, fortress
var _camps: Array[Dictionary] = [] ## {zone, level, cell}
var _protect := PackedByteArray()  ## celdas donde no puede ir relieve
var _main_bridge := PackedInt32Array()  ## cruces de río del camino principal


static func load_params(path: String = "res://data/world.json") -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "No se pudo abrir " + path)
	return JSON.parse_string(f.get_as_text())


static func generate(seed_value: int, params: Dictionary) -> MapData:
	var g := MapGenerator.new()
	return g._generate(seed_value, params)


func _generate(seed_value: int, params: Dictionary) -> MapData:
	_params = params
	_tp = params["terrain"]
	_rng.seed = seed_value
	_m = MapData.new()
	_m.seed_value = seed_value
	_m.cell = float(params["cell_size"])
	_m.h = int(params["height_cells"])
	_layout_zones()
	_carve_land()
	_fill_sea()
	_build_barriers()
	_cordillera()
	_river()
	_choose_spots()
	_ridges()
	_forests()
	_roads()
	_river_barrier()
	_seal_unreachable()
	_ore()
	_place_content()
	return _m


# ------------------------------------------------------------------ zonas

func _layout_zones() -> void:
	var margin: float = _params["margin_cells"]
	var x := margin
	var zs: Array = _params["zones"]
	for zi in zs.size():
		var zp: Dictionary = zs[zi]
		var r: float = float(zp["radius"]) * _rng.randf_range(0.92, 1.08)
		var reach := r * 1.3
		var cx := x + reach
		var cy := _m.h * 0.5 + _rng.randf_range(-1.0, 1.0) * float(zp["jitter_y"])
		_m.zones.append({
			"name": zp["name"], "radius": r, "pattern": zp.get("ground_pattern", "inicio"),
			"center": Vector2(cx, cy),
			"phase": [_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU],
		})
		x = cx + reach
		if zi < _params["barriers"].size():
			x += float(_params["barriers"][zi]["gap_cells"])
	_m.w = int(ceil(x + margin))
	var n := _m.w * _m.h
	_m.zone_id.resize(n); _m.zone_id.fill(V)
	_m.barrier_id.resize(n); _m.barrier_id.fill(V)
	_m.walk.resize(n); _m.walk.fill(0)
	_m.terrain.resize(n); _m.terrain.fill(MapData.T_VOID)
	_m.ore.resize(n); _m.ore.fill(0)
	_protect.resize(n); _protect.fill(0)


func _boundary(z: Dictionary, theta: float) -> float:
	var p: Array = z["phase"]
	var r: float = z["radius"]
	return r * (1.0 + 0.12 * sin(2.0 * theta + p[0]) + 0.08 * sin(3.0 * theta + p[1]) + 0.05 * sin(5.0 * theta + p[2]))


## Tierra = unión de las manchas de cada zona; cada celda pertenece a la zona "más cercana"
## (distancia normalizada por su contorno), así las zonas que se solapan quedan pegadas.
func _carve_land() -> void:
	for cy in _m.h:
		for cx in _m.w:
			var best := -1
			var best_nd := 1.0
			for zi in _m.zones.size():
				var z: Dictionary = _m.zones[zi]
				var c: Vector2 = z["center"]
				var dx := cx + 0.5 - c.x
				var dy := cy + 0.5 - c.y
				var d := sqrt(dx * dx + dy * dy)
				if d > float(z["radius"]) * 1.3:
					continue
				var nd := d / _boundary(z, atan2(dy, dx))
				if nd <= best_nd:
					best_nd = nd
					best = zi
			if best >= 0:
				var i := _m.idx(cx, cy)
				_m.zone_id[i] = best
				_m.walk[i] = 1
				_m.terrain[i] = MapData.T_PLAIN


func _fill_sea() -> void:
	var sm := int(_tp["sea_margin_cells"])
	for cy in _m.h:
		for cx in _m.w:
			var i := _m.idx(cx, cy)
			if _m.terrain[i] != MapData.T_VOID:
				continue
			var edge := mini(mini(cx, _m.w - 1 - cx), mini(cy, _m.h - 1 - cy))
			var wobble := int(2.0 + 1.5 * sin(cx * 0.21 + cy * 0.13) + 1.0 * sin(cy * 0.37))
			if edge >= sm + wobble:
				_m.terrain[i] = MapData.T_WATER


# --------------------------------------------------------------- barreras

func _build_barriers() -> void:
	var bs: Array = _params["barriers"]
	for bi in bs.size():
		var bp: Dictionary = bs[bi]
		var b := {"kind": bp["kind"], "name": bp["name"], "cost": bp["cost"], "open": false,
			"cells": PackedInt32Array(), "from_zone": bi, "to_zone": bi + 1,
			"pos": Vector2.ZERO, "rect": Rect2(), "end_a": Vector2i.ZERO, "end_b": Vector2i.ZERO}
		_m.barriers.append(b)
		if bp["kind"] != "sea":
			continue  # el río se resuelve después de trazar los caminos
		var ya: Vector2 = _m.zones[bi]["center"]
		var yb: Vector2 = _m.zones[bi + 1]["center"]
		var row := int(round((ya.y + yb.y) * 0.5))
		var width := int(bp["width_cells"])
		var y0 := row - width / 2
		var xa := int(ya.x)
		while xa < _m.w and _m.zone_id[_m.idx(xa, row)] == bi:
			xa += 1
		var xb := int(yb.x)
		while xb > 0 and _m.zone_id[_m.idx(xb, row)] == bi + 1:
			xb -= 1
		var cells := PackedInt32Array()
		for cy in range(y0, y0 + width):
			for cx in range(xa - 3, xb + 4):
				if _m.in_bounds(cx, cy) and _m.zone_id[_m.idx(cx, cy)] == V:
					var i := _m.idx(cx, cy)
					_m.barrier_id[i] = bi
					_m.terrain[i] = MapData.T_WATER
					cells.append(i)
		b["cells"] = cells
		b["pos"] = Vector2((xa + xb) * 0.5 + 0.5, row + 0.5) * _m.cell
		b["rect"] = Rect2(Vector2(xa - 3, y0) * _m.cell, Vector2(xb - xa + 7, width) * _m.cell)
		b["end_a"] = Vector2i(xa - 1, row)
		b["end_b"] = Vector2i(xb + 1, row)


func _river_barrier_index() -> int:
	for bi in _m.barriers.size():
		if _m.barriers[bi]["kind"] == "river":
			return bi
	return -1


# ------------------------------------------------------ cordillera y río

## Muro de montaña continuo en la frontera entre las dos regiones que separa el río.
func _cordillera() -> void:
	var bi := _river_barrier_index()
	if bi < 0:
		return
	var za := bi
	var zb := bi + 1
	var th := int(_tp["wall_thickness"])
	var mark: Array[int] = []
	for cy in _m.h:
		for cx in _m.w:
			var i := _m.idx(cx, cy)
			var z := _m.zone_id[i]
			if z != za and z != zb:
				continue
			var other := zb if z == za else za
			var hit := false
			for dy in range(-th, th + 1):
				for dx in range(-th, th + 1):
					var nx := cx + dx
					var ny := cy + dy
					if _m.in_bounds(nx, ny) and _m.zone_id[_m.idx(nx, ny)] == other:
						hit = true
			if hit:
				mark.append(i)
	for i in mark:
		_m.terrain[i] = MapData.T_MOUNTAIN
		_m.walk[i] = 0


## Río: nace en el extremo norte de la cordillera y baja pegado a ella (lado de la región
## siguiente) hasta el mar del sur. Corta la región de costa a costa.
func _river() -> void:
	var bi := _river_barrier_index()
	if bi < 0:
		return
	var zb := bi + 1
	var wall_x := PackedInt32Array()
	wall_x.resize(_m.h)
	wall_x.fill(-1)
	var top := -1
	for cy in _m.h:
		for cx in _m.w:
			if _m.terrain[_m.idx(cx, cy)] == MapData.T_MOUNTAIN:
				wall_x[cy] = cx  # el más a la derecha de la fila
				if top < 0:
					top = cy
	if top < 0:
		return
	var width := int(_tp["river_width"])
	var off := int(_tp["river_offset_cells"])
	var last_wall := wall_x[top]
	var x := last_wall + off
	# nacimiento: brazo que sale de la montaña
	for k in range(last_wall + 1, x + 1):
		_set_river(k, top, width, zb)
	for cy in range(top, _m.h):
		if wall_x[cy] >= 0:
			last_wall = wall_x[cy]
		var target := last_wall + off
		x += clampi(target - x, -1, 1)  # sigue a la cordillera sin saltos (siempre conectado)
		if _rng.randf() < 0.25:
			x += _rng.randi_range(-1, 1)
		x = clampi(x, last_wall + 2, last_wall + off + 3)
		var any := false
		for k in width:
			if _set_river(x + k, cy, width, zb):
				any = true
		if not any and cy > top + 3:
			break  # llegó al mar


func _set_river(cx: int, cy: int, _w: int, zone: int) -> bool:
	if not _m.in_bounds(cx, cy):
		return false
	var i := _m.idx(cx, cy)
	if _m.zone_id[i] == V:
		return false
	_m.terrain[i] = MapData.T_RIVER
	_m.walk[i] = 0
	return true


# ----------------------------------------------------- puntos y relieve

func _choose_spots() -> void:
	for cp in _params["content"]:
		var zone: int = cp["zone"]
		var zc: Vector2 = _m.zones[zone]["center"]
		var zr: float = _m.zones[zone]["radius"]
		if cp.get("player_base", false):
			_key["spawn"] = _free_spot(zone, 5, 0.0, zc + Vector2(-zr * 0.35, 0), 4.0)
			_claim(_key["spawn"])
		if cp.get("enemy_outpost", false):
			_key["outpost"] = _free_spot(zone, 6, 14.0, zc + Vector2(zr * 0.3, 0), 8.0)
			_claim(_key["outpost"])
		if cp.get("final_base", false):
			_key["fortress"] = _free_spot(zone, 6, 14.0, zc + Vector2(zr * 0.25, 0), 6.0)
			_claim(_key["fortress"])
	for cp in _params["content"]:
		var zone2: int = cp["zone"]
		for camp in cp.get("camps", []):
			var cs := _free_spot(zone2, 4, 16.0)
			if cs == Vector2.INF:
				cs = _free_spot(zone2, 2, 10.0)
			if cs == Vector2.INF:
				continue
			_claim(cs)
			_camps.append({"zone": zone2, "level": int(camp["level"]), "cell": cs})
	var cr := float(_tp["clear_radius_key"])
	for k in _key:
		_protect_disc(_key[k], cr)
	for c in _camps:
		_protect_disc(c["cell"], float(_tp["clear_radius_camp"]))
	for b in _m.barriers:
		if b["kind"] == "sea":
			_protect_disc(Vector2(b["end_a"]), 4.0)
			_protect_disc(Vector2(b["end_b"]), 4.0)


func _protect_disc(c: Vector2, r: float) -> void:
	if c == Vector2.INF:
		return
	for cy in range(int(c.y - r), int(c.y + r) + 1):
		for cx in range(int(c.x - r), int(c.x + r) + 1):
			if _m.in_bounds(cx, cy) and Vector2(cx, cy).distance_to(c) <= r:
				_protect[_m.idx(cx, cy)] = 1


## Crestas interiores: líneas continuas (|ruido| pequeño) solo donde una máscara lo permite.
func _ridges() -> void:
	var n := FastNoiseLite.new()
	n.seed = _m.seed_value
	n.frequency = float(_tp["ridge_frequency"])
	n.fractal_octaves = 2
	var mask := FastNoiseLite.new()
	mask.seed = _m.seed_value + 55
	mask.frequency = float(_tp["ridge_frequency"]) * 0.7
	var wdt := float(_tp["ridge_width"])
	var mt := float(_tp["ridge_mask_threshold"])
	for cy in _m.h:
		for cx in _m.w:
			var i := _m.idx(cx, cy)
			if _m.terrain[i] != MapData.T_PLAIN or _protect[i] == 1:
				continue
			if absf(n.get_noise_2d(cx, cy)) < wdt and mask.get_noise_2d(cx, cy) > mt:
				_m.terrain[i] = MapData.T_MOUNTAIN
				_m.walk[i] = 0


func _forests() -> void:
	var n := FastNoiseLite.new()
	n.seed = _m.seed_value + 202
	n.frequency = float(_tp["forest_frequency"])
	n.fractal_octaves = 3
	var t := float(_tp["forest_threshold"]) * 2.0 - 1.0
	for cy in _m.h:
		for cx in _m.w:
			var i := _m.idx(cx, cy)
			if _m.terrain[i] == MapData.T_PLAIN and _protect[i] == 0 and n.get_noise_2d(cx, cy) > t:
				_m.terrain[i] = MapData.T_FOREST


# ---------------------------------------------------------------- caminos

func _cost_of(t: int) -> float:
	var rc: Dictionary = _tp["road_cost"]
	match t:
		MapData.T_FOREST: return float(rc["forest"])
		MapData.T_MOUNTAIN: return float(rc["mountain"])
		MapData.T_RIVER: return float(rc["river"])
		MapData.T_ROAD, MapData.T_BRIDGE: return float(rc["road"])
	return float(rc["plain"])


func _roads() -> void:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, _m.w, _m.h)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	for cy in _m.h:
		for cx in _m.w:
			var i := _m.idx(cx, cy)
			var p := Vector2i(cx, cy)
			if _m.zone_id[i] == V and _m.barrier_id[i] == V:
				astar.set_point_solid(p, true)
			else:
				astar.set_point_weight_scale(p, _cost_of(_m.terrain[i]))
	var legs: Array = []  # [desde, hasta, es_camino_principal]
	var spawn := Vector2i(_key["spawn"])
	var outpost := Vector2i(_key.get("outpost", _key["spawn"]))
	var fort := Vector2i(_key["fortress"])
	legs.append([spawn, outpost, true])
	for c in _camps:
		var from := spawn if c["zone"] == 0 else (outpost if c["zone"] == 1 else fort)
		legs.append([from, Vector2i(c["cell"]), false])
	for b in _m.barriers:
		if b["kind"] == "sea":
			legs.append([outpost, b["end_a"], true])
			legs.append([b["end_b"], fort, true])
	for leg in legs:
		var path := astar.get_id_path(leg[0], leg[1])
		for p in path:
			var i := _m.idx(p.x, p.y)
			if _m.barrier_id[i] != V:
				continue  # el estrecho lo cruza el barco
			match _m.terrain[i]:
				MapData.T_MOUNTAIN:
					# paso: el camino abre la montaña (y un poco a los lados)
					_m.terrain[i] = MapData.T_ROAD
					_m.walk[i] = 1
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var q: Vector2i = p + d
						if _m.in_bounds(q.x, q.y) and _m.terrain[_m.idx(q.x, q.y)] == MapData.T_MOUNTAIN and _rng.randf() < 0.5:
							_m.terrain[_m.idx(q.x, q.y)] = MapData.T_PLAIN
							_m.walk[_m.idx(q.x, q.y)] = 1
				MapData.T_RIVER:
					_m.terrain[i] = MapData.T_BRIDGE
					_m.walk[i] = 1
					if leg[2]:
						_main_bridge.append(i)
				MapData.T_PLAIN, MapData.T_FOREST:
					_m.terrain[i] = MapData.T_ROAD
					_m.walk[i] = 1
			astar.set_point_weight_scale(p, _cost_of(_m.terrain[i]))
			_protect_disc(Vector2(p), float(_tp["road_clearance"]))


## Todos los puentes sobre el río pertenecen a la barrera "puente roto": se reparan a la vez.
func _river_barrier() -> void:
	var bi := _river_barrier_index()
	if bi < 0:
		return
	var b: Dictionary = _m.barriers[bi]
	var cells := PackedInt32Array()
	for i in _m.w * _m.h:
		if _m.terrain[i] == MapData.T_BRIDGE:
			cells.append(i)
			_m.barrier_id[i] = bi
			_m.walk[i] = 0
	b["cells"] = cells
	var main := _main_bridge if _main_bridge.size() > 0 else cells
	if main.is_empty():
		push_warning("El camino principal no cruza el río (semilla %d)" % _m.seed_value)
		return
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for i in main:
		var c := Vector2(i % _m.w, i / _m.w)
		mn = mn.min(c)
		mx = mx.max(c)
	b["pos"] = (mn + mx + Vector2.ONE) * 0.5 * _m.cell
	b["rect"] = Rect2(mn * _m.cell, (mx - mn + Vector2.ONE) * _m.cell).grow(2.0)


func _seal_unreachable() -> void:
	var reach := PackedByteArray()
	reach.resize(_m.w * _m.h)
	var s: Vector2 = _key["spawn"]
	var start := _m.idx(int(s.x), int(s.y))
	var stack := PackedInt32Array([start])
	reach[start] = 1
	while stack.size() > 0:
		var c := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var cx := c % _m.w
		var cy := c / _m.w
		for d in 4:
			var nx := cx + (1 if d == 0 else (-1 if d == 1 else 0))
			var ny := cy + (1 if d == 2 else (-1 if d == 3 else 0))
			if not _m.in_bounds(nx, ny):
				continue
			var n := _m.idx(nx, ny)
			if reach[n] == 0 and (_m.walk[n] != 0 or _m.barrier_id[n] != V):
				reach[n] = 1
				stack.append(n)
	for i in _m.w * _m.h:
		if _m.walk[i] != 0 and reach[i] == 0:
			_m.walk[i] = 0
			_m.terrain[i] = MapData.T_MOUNTAIN


## Filones: algunas celdas de muro que dan al llano (ahí se mina; no se agotan).
func _ore() -> void:
	var ch := float(_tp["ore_chance"])
	for cy in _m.h:
		for cx in _m.w:
			var i := _m.idx(cx, cy)
			if _m.terrain[i] == MapData.T_MOUNTAIN and _m._touches_walk(cx, cy) and _rng.randf() < ch:
				_m.ore[i] = 1


# -------------------------------------------------------------- contenido

func _free_spot(zone: int, edge: int, min_dist: float, around: Vector2 = Vector2.INF, around_r: float = 0.0) -> Vector2:
	var z: Dictionary = _m.zones[zone]
	var c: Vector2 = z["center"]
	var ext := float(z["radius"])
	for attempt in 400:
		var cx: int
		var cy: int
		if around != Vector2.INF:
			var ang := _rng.randf() * TAU
			var rr := _rng.randf_range(0.0, around_r + attempt * 0.05)
			cx = int(around.x + cos(ang) * rr)
			cy = int(around.y + sin(ang) * rr)
		else:
			cx = int(c.x + _rng.randf_range(-ext, ext))
			cy = int(c.y + _rng.randf_range(-ext, ext))
		if not _interior(cx, cy, zone, edge):
			continue
		var p := Vector2(cx, cy)
		var ok := true
		for t in _taken:
			if t.distance_to(p) < min_dist:
				ok = false
				break
		if ok:
			return p
	return Vector2.INF


func _interior(cx: int, cy: int, zone: int, edge: int) -> bool:
	if not _m.in_bounds(cx, cy):
		return false
	var t := _m.terrain[_m.idx(cx, cy)]
	if not (t == MapData.T_PLAIN or t == MapData.T_FOREST or t == MapData.T_ROAD):
		return false
	for d in [Vector2i(edge, 0), Vector2i(-edge, 0), Vector2i(0, edge), Vector2i(0, -edge), Vector2i(edge, edge), Vector2i(-edge, -edge)]:
		var nx: int = cx + d.x
		var ny: int = cy + d.y
		if not _m.in_bounds(nx, ny):
			return false
		var i := _m.idx(nx, ny)
		if _m.zone_id[i] != zone or _m.walk[i] == 0:
			return false
	return true


func _px(cellpos: Vector2) -> Vector2:
	return (cellpos + Vector2(0.5, 0.5)) * _m.cell


func _claim(cellpos: Vector2) -> void:
	if cellpos != Vector2.INF:
		_taken.append(cellpos)


func _struct(type: String, team: int, cellpos: Vector2, zone: int, tag: int = -1) -> void:
	_m.entities.append({"kind": "structure", "type": type, "team": team, "pos": _px(cellpos), "zone": zone, "tag": tag})


func _defenders(comp: Dictionary, team: int, center: Vector2, zone: int, ring: float, tag: int) -> void:
	for type in comp:
		for n in int(comp[type]):
			var ang := _rng.randf() * TAU
			var rr := _rng.randf_range(ring * 0.4, ring)
			var cp := center + Vector2(cos(ang), sin(ang)) * rr
			var pos := _px(cp) + Vector2(_rng.randf(), _rng.randf()) * 8.0
			if _m.zone_at(pos) != zone or not _m.is_walkable(pos):
				pos = _px(center)
			_m.entities.append({"kind": "unit", "type": type, "team": team, "pos": pos, "zone": zone, "tag": tag, "seek": false})


func _place_content() -> void:
	for cp in _params["content"]:
		var zone: int = cp["zone"]
		if cp.get("player_base", false):
			var s: Vector2 = _key["spawn"]
			_m.spawn = _px(s)
			_struct("townhall", UnitDB.PLAYER, s, zone)
			for n in int(cp.get("houses", 0)):
				var hs := _free_spot(zone, 1, 5.0, s, 8.0)
				if hs != Vector2.INF:
					_claim(hs)
					_struct("house", UnitDB.PLAYER, hs, zone)
			_m.raid_point = _raid_point()
		if cp.get("enemy_outpost", false):
			var op: Dictionary = _params["enemy_outpost"]
			var s2: Vector2 = _key["outpost"]
			_struct("enemy_hall", UnitDB.ENEMY, s2, zone)
			for n in int(op["towers"]):
				var ts := _free_spot(zone, 1, 4.0, s2, 7.0)
				if ts != Vector2.INF:
					_claim(ts)
					_struct("enemy_tower", UnitDB.ENEMY, ts, zone)
			_defenders(op["defenders"], UnitDB.ENEMY, s2, zone, 7.0, -1)
		if cp.get("final_base", false):
			var fb: Dictionary = _params["final_base"]
			var s3: Vector2 = _key["fortress"]
			_struct("fortress", UnitDB.ENEMY, s3, zone)
			for n in int(fb["towers"]):
				var ts2 := _free_spot(zone, 1, 4.0, s3, 9.0)
				if ts2 != Vector2.INF:
					_claim(ts2)
					_struct("enemy_tower", UnitDB.ENEMY, ts2, zone)
			_defenders(fb["defenders"], UnitDB.ENEMY, s3, zone, 9.0, -1)
		for n in int(_params["decor"].get("trees_per_zone", 0)):
			var t := _free_spot(zone, 1, 6.0)
			if t != Vector2.INF:
				_claim(t)
				_m.entities.append({"kind": "decor", "sprite": str(_params["decor"]["tree"]), "pos": _px(t), "zone": zone})
	for c in _camps:
		var cl: Dictionary = _params["camp_levels"][str(c["level"])]
		var tag := _m.camps.size()
		_m.camps.append({"level": c["level"], "reward": cl["reward"], "pos": _px(c["cell"]), "zone": c["zone"]})
		_struct("camp_tent", UnitDB.NEUTRAL, c["cell"], c["zone"], tag)
		_defenders(cl["defenders"], UnitDB.NEUTRAL, c["cell"], c["zone"], 5.0, tag)


## Las oleadas entran por el camino de tu región más cercano al puente roto.
func _raid_point() -> Vector2:
	var target: Vector2 = _m.barriers[0]["pos"]
	var best := _m.spawn
	var best_d := 1.0e20
	for i in _m.w * _m.h:
		if _m.terrain[i] == MapData.T_ROAD and _m.zone_id[i] == 0 and _m.walk[i] == 1:
			var p := _m.cell_center(i % _m.w, i / _m.w)
			var d := p.distance_squared_to(target)
			if d < best_d:
				best_d = d
				best = p
	return best

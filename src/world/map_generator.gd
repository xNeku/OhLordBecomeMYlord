class_name MapGenerator
extends RefCounted
## Genera un MapData a partir de una semilla y data/world.json.
## Misma semilla -> mismo mapa (RandomNumberGenerator y FastNoiseLite con semilla fija).
##
## Pasos: zonas (regiones de tierra) -> mar entre ellas y vacío estrellado fuera
##        -> barreras sobre el mar -> puntos clave -> caminos (A*) -> relieve (montañas,
##        lagos, bosques) respetando caminos y puntos clave -> tierra inalcanzable a montaña
##        -> estructuras, campamentos y decoración.
## Garantía: todo punto de interés es alcanzable desde la aparición abriendo las barreras.

const V := MapData.VOID

var _rng := RandomNumberGenerator.new()
var _m: MapData
var _params: Dictionary
var _taken: Array[Vector2] = []   ## posiciones (celdas) ya ocupadas
var _key: Dictionary = {}         ## puntos clave en celdas: spawn, outpost, fortress
var _protect := PackedByteArray() ## celdas donde no puede ir relieve que bloquee


static func load_params(path: String = "res://data/world.json") -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "No se pudo abrir " + path)
	return JSON.parse_string(f.get_as_text())


static func generate(seed_value: int, params: Dictionary) -> MapData:
	var g := MapGenerator.new()
	return g._generate(seed_value, params)


func _generate(seed_value: int, params: Dictionary) -> MapData:
	_params = params
	_rng.seed = seed_value
	_m = MapData.new()
	_m.seed_value = seed_value
	_m.cell = float(params["cell_size"])
	_m.h = int(params["height_cells"])
	_layout_zones()
	_carve_zones()
	_fill_sea()
	_build_barriers()
	_choose_keypoints()
	_build_roads()
	_build_relief()
	_seal_unreachable()
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
		var reach := r * 1.3  # extensión máxima del contorno irregular
		var cx := x + reach
		var cy := _m.h * 0.5 + _rng.randf_range(-1.0, 1.0) * float(zp["jitter_y"])
		_m.zones.append({
			"name": zp["name"], "radius": r, "pattern": zp.get("ground_pattern", "grass"),
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
	_protect.resize(n); _protect.fill(0)


func _boundary(z: Dictionary, theta: float) -> float:
	var p: Array = z["phase"]
	var r: float = z["radius"]
	return r * (1.0 + 0.12 * sin(2.0 * theta + p[0]) + 0.08 * sin(3.0 * theta + p[1]) + 0.05 * sin(5.0 * theta + p[2]))


func _carve_zones() -> void:
	for zi in _m.zones.size():
		var z: Dictionary = _m.zones[zi]
		var c: Vector2 = z["center"]
		var ext := int(ceil(float(z["radius"]) * 1.3)) + 1
		for cy in range(maxi(int(c.y) - ext, 0), mini(int(c.y) + ext + 1, _m.h)):
			for cx in range(maxi(int(c.x) - ext, 0), mini(int(c.x) + ext + 1, _m.w)):
				var dx := cx + 0.5 - c.x
				var dy := cy + 0.5 - c.y
				if sqrt(dx * dx + dy * dy) <= _boundary(z, atan2(dy, dx)):
					var i := _m.idx(cx, cy)
					_m.zone_id[i] = zi
					_m.walk[i] = 1
					_m.terrain[i] = MapData.T_PLAIN


## Mar alrededor y entre las regiones; más allá, vacío estrellado.
func _fill_sea() -> void:
	var sm := int(_params["terrain"]["sea_margin_cells"])
	for cy in _m.h:
		for cx in _m.w:
			var i := _m.idx(cx, cy)
			if _m.terrain[i] != MapData.T_VOID:
				continue
			# el mar ocupa todo salvo una franja irregular en el borde del mapa
			var edge := mini(mini(cx, _m.w - 1 - cx), mini(cy, _m.h - 1 - cy))
			var wobble := int(2.0 + 1.5 * sin(cx * 0.21 + cy * 0.13) + 1.0 * sin(cy * 0.37))
			if edge >= sm + wobble:
				_m.terrain[i] = MapData.T_WATER


# --------------------------------------------------------------- barreras

func _build_barriers() -> void:
	var bs: Array = _params["barriers"]
	for bi in bs.size():
		var bp: Dictionary = bs[bi]
		var za: Dictionary = _m.zones[bi]
		var zb: Dictionary = _m.zones[bi + 1]
		var ya: Vector2 = za["center"]
		var yb: Vector2 = zb["center"]
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
		_m.barriers.append({
			"kind": bp["kind"], "name": bp["name"], "cost": bp["cost"], "open": false,
			"cells": cells, "from_zone": bi, "to_zone": bi + 1,
			"pos": Vector2((xa + xb) * 0.5 + 0.5, row + 0.5) * _m.cell,
			"rect": Rect2(Vector2(xa - 3, y0) * _m.cell, Vector2(xb - xa + 7, width) * _m.cell),
			"end_a": Vector2i(xa - 1, row), "end_b": Vector2i(xb + 1, row),
		})


# ----------------------------------------------------------- puntos clave

func _choose_keypoints() -> void:
	for cp in _params["content"]:
		var zone: int = cp["zone"]
		var zc: Vector2 = _m.zones[zone]["center"]
		var zr: float = _m.zones[zone]["radius"]
		if cp.get("player_base", false):
			_key["spawn"] = _free_spot(zone, 5, 0.0, zc + Vector2(-zr * 0.35, 0), 4.0)
		if cp.get("enemy_outpost", false):
			_key["outpost"] = _free_spot(zone, 6, 0.0, zc + Vector2(zr * 0.2, 0), 8.0)
		if cp.get("final_base", false):
			_key["fortress"] = _free_spot(zone, 6, 0.0, zc + Vector2(zr * 0.25, 0), 6.0)
	var cr := float(_params["terrain"]["clear_radius_key"])
	for k in _key:
		_protect_disc(_key[k], cr)
	for b in _m.barriers:
		_protect_disc(Vector2(b["end_a"]), 4.0)
		_protect_disc(Vector2(b["end_b"]), 4.0)


func _protect_disc(c: Vector2, r: float) -> void:
	if c == Vector2.INF:
		return
	for cy in range(int(c.y - r), int(c.y + r) + 1):
		for cx in range(int(c.x - r), int(c.x + r) + 1):
			if _m.in_bounds(cx, cy) and Vector2(cx, cy).distance_to(c) <= r:
				_protect[_m.idx(cx, cy)] = 1


# ---------------------------------------------------------------- caminos

func _build_roads() -> void:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, _m.w, _m.h)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	var noise := FastNoiseLite.new()
	noise.seed = _m.seed_value + 17
	noise.frequency = 0.12
	var wiggle := float(_params["terrain"]["road_wiggle"])
	for cy in _m.h:
		for cx in _m.w:
			var i := _m.idx(cx, cy)
			var land := _m.zone_id[i] != V
			if not land and _m.barrier_id[i] == V:
				astar.set_point_solid(Vector2i(cx, cy), true)
			else:
				# peso con ruido: caminos serpenteantes en vez de rectas perfectas
				astar.set_point_weight_scale(Vector2i(cx, cy), 1.0 + wiggle * (noise.get_noise_2d(cx, cy) * 0.5 + 0.5))
	var stops: Array[Vector2i] = []
	stops.append(Vector2i(_key["spawn"]))
	stops.append(_m.barriers[0]["end_a"])
	stops.append(_m.barriers[0]["end_b"])
	if _key.has("outpost"):
		stops.append(Vector2i(_key["outpost"]))
	if _m.barriers.size() > 1:
		stops.append(_m.barriers[1]["end_a"])
		stops.append(_m.barriers[1]["end_b"])
	stops.append(Vector2i(_key["fortress"]))
	var clear := int(_params["terrain"]["road_clearance"])
	for k in stops.size() - 1:
		var path := astar.get_id_path(stops[k], stops[k + 1])
		for p in path:
			var i := _m.idx(p.x, p.y)
			if _m.barrier_id[i] == V and _m.zone_id[i] != V:
				_m.terrain[i] = MapData.T_ROAD
			_protect_disc(Vector2(p), clear)


# ----------------------------------------------------------------- relieve

func _build_relief() -> void:
	var tp: Dictionary = _params["terrain"]
	var mnt := FastNoiseLite.new()
	mnt.seed = _m.seed_value
	mnt.frequency = float(tp["noise_frequency"])
	mnt.fractal_octaves = 3
	var lake := FastNoiseLite.new()
	lake.seed = _m.seed_value + 101
	lake.frequency = float(tp["noise_frequency"]) * 0.8
	var forest := FastNoiseLite.new()
	forest.seed = _m.seed_value + 202
	forest.frequency = float(tp["noise_frequency"]) * 1.4
	var t_m := float(tp["mountain_threshold"]) * 2.0 - 1.0
	var t_l := float(tp["lake_threshold"]) * 2.0 - 1.0
	var t_f := float(tp["forest_threshold"]) * 2.0 - 1.0
	for cy in _m.h:
		for cx in _m.w:
			var i := _m.idx(cx, cy)
			if _m.terrain[i] != MapData.T_PLAIN:
				continue
			var blocked_ok := _protect[i] == 0
			if blocked_ok and mnt.get_noise_2d(cx, cy) > t_m:
				_m.terrain[i] = MapData.T_MOUNTAIN
				_m.walk[i] = 0
			elif blocked_ok and lake.get_noise_2d(cx, cy) > t_l:
				_m.terrain[i] = MapData.T_LAKE
				_m.walk[i] = 0
			elif forest.get_noise_2d(cx, cy) > t_f:
				_m.terrain[i] = MapData.T_FOREST


## La tierra que haya quedado encerrada por el relieve pasa a montaña: así nada se coloca allí.
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


# -------------------------------------------------------------- contenido

## Celda interior caminable de una zona (a >= edge celdas de cualquier obstáculo) lejos de lo ya colocado.
func _free_spot(zone: int, edge: int, min_dist: float, around: Vector2 = Vector2.INF, around_r: float = 0.0, allow_road: bool = false) -> Vector2:
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
		if not _interior(cx, cy, zone, edge, allow_road):
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


func _interior(cx: int, cy: int, zone: int, edge: int, allow_road: bool = false) -> bool:
	if not _m.in_bounds(cx, cy):
		return false
	var t := _m.terrain[_m.idx(cx, cy)]
	if not (t == MapData.T_PLAIN or t == MapData.T_FOREST or (allow_road and t == MapData.T_ROAD)):
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
	var content: Array = _params["content"]
	for cp in content:
		var zone: int = cp["zone"]
		var zc: Vector2 = _m.zones[zone]["center"]
		var zr: float = _m.zones[zone]["radius"]

		if cp.get("player_base", false):
			var s: Vector2 = _key["spawn"]
			_m.spawn = _px(s)
			_claim(s)
			_struct("townhall", UnitDB.PLAYER, s, zone)
			for n in int(cp.get("houses", 0)):
				var hs := _free_spot(zone, 1, 5.0, s, 8.0)
				if hs != Vector2.INF:
					_claim(hs)
					_struct("house", UnitDB.PLAYER, hs, zone)
			# entrada de oleadas: junto al extremo de la primera barrera, en tu zona
			var q := _free_spot(zone, 1, 0.0, Vector2(_m.barriers[0]["end_a"]) + Vector2(-4, 0), 4.0, true)
			_m.raid_point = _px(q if q != Vector2.INF else s)

		if cp.get("enemy_outpost", false):
			var op: Dictionary = _params["enemy_outpost"]
			var s2: Vector2 = _key["outpost"]
			_claim(s2)
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
			_claim(s3)
			_struct("fortress", UnitDB.ENEMY, s3, zone)
			for n in int(fb["towers"]):
				var ts2 := _free_spot(zone, 1, 4.0, s3, 9.0)
				if ts2 != Vector2.INF:
					_claim(ts2)
					_struct("enemy_tower", UnitDB.ENEMY, ts2, zone)
			_defenders(fb["defenders"], UnitDB.ENEMY, s3, zone, 9.0, -1)

		for camp in cp.get("camps", []):
			var lvl := str(int(camp["level"]))
			var cl: Dictionary = _params["camp_levels"][lvl]
			var cs := _free_spot(zone, 3, 16.0)
			if cs == Vector2.INF:
				cs = _free_spot(zone, 1, 10.0)
			if cs == Vector2.INF:
				continue
			_claim(cs)
			var tag := _m.camps.size()
			_m.camps.append({"level": int(lvl), "reward": cl["reward"], "pos": _px(cs), "zone": zone})
			_struct("camp_tent", UnitDB.NEUTRAL, cs, zone, tag)
			_defenders(cl["defenders"], UnitDB.NEUTRAL, cs, zone, 5.0, tag)

		for n in int(cp.get("trees", 0)) / 3:  # árboles con cara: pocos, como hitos (los bosques ya los pinta el suelo)
			var t := _free_spot(zone, 1, 4.0)
			if t != Vector2.INF:
				_claim(t)
				_m.entities.append({"kind": "decor", "sprite": str(_params["decor"]["tree"]), "pos": _px(t), "zone": zone})
		for n in int(cp.get("ore", 0)):
			var o := _free_spot(zone, 1, 3.0)
			if o != Vector2.INF:
				_claim(o)
				_m.entities.append({"kind": "decor", "sprite": str(_params["decor"]["ore"]), "pos": _px(o), "zone": zone})

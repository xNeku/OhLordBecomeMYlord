class_name MapGenerator
extends RefCounted
## Genera un MapData a partir de una semilla y data/world.json.
## Misma semilla -> mismo mapa (solo se usa un RandomNumberGenerator con semilla fija).
## Garantía: zonas encadenadas por barreras; todo punto de interés es alcanzable
## desde el punto de aparición una vez abiertas las barreras (ver MapData.validate).

const V := MapData.VOID

var _rng := RandomNumberGenerator.new()
var _m: MapData
var _params: Dictionary
var _taken: Array[Vector2] = []   ## posiciones (celdas) ya ocupadas


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
	_build_barriers()
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
			"name": zp["name"], "color": Color(zp["color"]), "radius": r,
			"center": Vector2(cx, cy),
			"phase": [_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU],
		})
		x = cx + reach
		if zi < _params["barriers"].size():
			x += float(_params["barriers"][zi]["gap_cells"])
	_m.w = int(ceil(x + margin))
	_m.zone_id.resize(_m.w * _m.h)
	_m.zone_id.fill(V)
	_m.barrier_id.resize(_m.w * _m.h)
	_m.barrier_id.fill(V)
	_m.walk.resize(_m.w * _m.h)
	_m.walk.fill(0)


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
		# borde derecho de la zona A y borde izquierdo de la zona B en la fila central
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
					cells.append(i)
		_m.barriers.append({
			"kind": bp["kind"], "name": bp["name"], "cost": bp["cost"], "open": false,
			"cells": cells, "from_zone": bi, "to_zone": bi + 1,
			"pos": Vector2((xa + xb) * 0.5 + 0.5, row + 0.5) * _m.cell,
			"color_closed": Color(bp["color_closed"]), "color_open": Color(bp["color_open"]),
		})


# -------------------------------------------------------------- contenido

## Celda interior de una zona (a >= edge celdas del borde) lejos de lo ya colocado.
func _free_spot(zone: int, edge: int, min_dist: float, around: Vector2 = Vector2.INF, around_r: float = 0.0) -> Vector2:
	var z: Dictionary = _m.zones[zone]
	var c: Vector2 = z["center"]
	var ext := float(z["radius"])
	for attempt in 300:
		var cx: int
		var cy: int
		if around != Vector2.INF:
			var ang := _rng.randf() * TAU
			var rr := _rng.randf_range(0.0, around_r)
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
	for d in [Vector2i(edge, 0), Vector2i(-edge, 0), Vector2i(0, edge), Vector2i(0, -edge), Vector2i(0, 0)]:
		var nx: int = cx + d.x
		var ny: int = cy + d.y
		if not _m.in_bounds(nx, ny) or _m.zone_id[_m.idx(nx, ny)] != zone:
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
			if not _interior(int(cp.x), int(cp.y), zone, 1):
				cp = center
			var pos := _px(cp) + Vector2(_rng.randf(), _rng.randf()) * 8.0
			if _m.zone_at(pos) != zone:
				pos = _px(center)
			_m.entities.append({"kind": "unit", "type": type, "team": team, "pos": pos, "zone": zone, "tag": tag, "seek": false})


func _place_content() -> void:
	var content: Array = _params["content"]
	for cp in content:
		var zone: int = cp["zone"]
		var zc: Vector2 = _m.zones[zone]["center"]
		var zr: float = _m.zones[zone]["radius"]

		if cp.get("player_base", false):
			var s := _free_spot(zone, 4, 0.0, zc + Vector2(-zr * 0.35, 0), 4.0)
			_m.spawn = _px(s)
			_claim(s)
			_struct("townhall", UnitDB.PLAYER, s, zone)
			for n in int(cp.get("houses", 0)):
				var hs := _free_spot(zone, 2, 5.0, s, 9.0)
				if hs != Vector2.INF:
					_claim(hs)
					_struct("house", UnitDB.PLAYER, hs, zone)
			# punto de entrada de oleadas: borde este de la zona 0, hacia la primera barrera
			var rp := Vector2(zc.x + zr * 0.8, zc.y)
			var q := _free_spot(zone, 2, 0.0, rp, 5.0)
			_m.raid_point = _px(q if q != Vector2.INF else s)

		if cp.get("enemy_outpost", false):
			var op: Dictionary = _params["enemy_outpost"]
			var s2 := _free_spot(zone, 6, 14.0, zc + Vector2(zr * 0.2, 0), 8.0)
			_claim(s2)
			_struct("enemy_hall", UnitDB.ENEMY, s2, zone)
			for n in int(op["towers"]):
				var ts := _free_spot(zone, 2, 4.0, s2, 7.0)
				if ts != Vector2.INF:
					_claim(ts)
					_struct("enemy_tower", UnitDB.ENEMY, ts, zone)
			_defenders(op["defenders"], UnitDB.ENEMY, s2, zone, 7.0, -1)

		if cp.get("final_base", false):
			var fb: Dictionary = _params["final_base"]
			var s3 := _free_spot(zone, 6, 14.0, zc + Vector2(zr * 0.25, 0), 6.0)
			_claim(s3)
			_struct("fortress", UnitDB.ENEMY, s3, zone)
			for n in int(fb["towers"]):
				var ts2 := _free_spot(zone, 2, 4.0, s3, 9.0)
				if ts2 != Vector2.INF:
					_claim(ts2)
					_struct("enemy_tower", UnitDB.ENEMY, ts2, zone)
			_defenders(fb["defenders"], UnitDB.ENEMY, s3, zone, 9.0, -1)

		for camp in cp.get("camps", []):
			var lvl := str(int(camp["level"]))
			var cl: Dictionary = _params["camp_levels"][lvl]
			var cs := _free_spot(zone, 4, 16.0)
			if cs == Vector2.INF:
				continue
			_claim(cs)
			var tag := _m.camps.size()
			_m.camps.append({"level": int(lvl), "reward": cl["reward"], "pos": _px(cs), "zone": zone})
			_struct("camp_tent", UnitDB.NEUTRAL, cs, zone, tag)
			_defenders(cl["defenders"], UnitDB.NEUTRAL, cs, zone, 5.0, tag)

		for n in int(cp.get("trees", 0)):
			var t := _free_spot(zone, 2, 3.0)
			if t != Vector2.INF:
				_claim(t)
				_m.entities.append({"kind": "decor", "sprite": int(_params["decor"]["tree_row"]), "pos": _px(t), "zone": zone})
		for n in int(cp.get("ore", 0)):
			var o := _free_spot(zone, 2, 3.0)
			if o != Vector2.INF:
				_claim(o)
				_m.entities.append({"kind": "decor", "sprite": int(_params["decor"]["ore_row"]), "pos": _px(o), "zone": zone})

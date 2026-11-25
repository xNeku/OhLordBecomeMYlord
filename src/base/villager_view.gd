class_name VillagerView
extends Node2D
## Aldeanos visibles (leñadores y mineros). Solo decoración: no están en la simulación.
## Cada uno va de su centro (o del ayuntamiento) al bosque / muro más cercano, trabaja unos
## segundos y vuelve. El número sigue al reparto de trabajadores del ayuntamiento.

@onready var batch: SpriteBatch = $Batch

var eco: Economy
var map: MapData
var db: UnitDB
var cfg: Dictionary
var _list: Array[Dictionary] = []  ## {home, site, t, row, period}
var _time := 0.0
var _tint := Color.WHITE


func bind(e: Economy, m: MapData, unit_db: UnitDB, hero_data: Dictionary) -> void:
	eco = e
	map = m
	db = unit_db
	cfg = hero_data["villagers"]
	var ht := db.type_index(db.unit_id(hero_data["faction"], "base"))
	_tint = db.tint[ht]
	SimRenderer._set_grid(batch, db._art["units_foot"]["grid"])
	eco.changed.connect(_rebuild)
	eco.building_finished.connect(func(_id, _p): _rebuild())
	_rebuild()


func _homes(type_id: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var sim := eco.battle.sim
	var t := db.type_index(type_id)
	for i in sim.high:
		if sim.alive[i] == 1 and sim.type[i] == t and sim.team[i] == UnitDB.PLAYER:
			out.append(Vector2(sim.px[i], sim.py[i]))
	if out.is_empty():
		out.append(map.spawn)
	return out


func _rebuild() -> void:
	_list.clear()
	var per := maxi(1, int(cfg["workers_per_villager"]))
	var maxv := int(cfg["max_visible"])
	var groups := [
		["wood", "lumber_center", MapData.T_FOREST, String(cfg["wood_sprite"])],
		["mining", "miners_center", MapData.T_MOUNTAIN, String(cfg["mining_sprite"])],
	]
	for g in groups:
		var n := mini(int(round(eco.workers() * eco.split[g[0]] / 100.0)) / per, maxv / 2)
		if n <= 0:
			continue
		var homes := _homes(g[1])
		var row := db._resolve(UnitDB.ATLAS_FOOT, g[3], g[3])
		for k in n:
			var home: Vector2 = homes[k % homes.size()]
			var site := map.nearest_terrain(home, g[2], 40, true)
			if site == Vector2.INF:
				continue
			site += Vector2(randf_range(-6, 6), randf_range(-6, 6))
			var walk_s := home.distance_to(site) / float(cfg["speed"])
			_list.append({"home": home + Vector2(randf_range(-8, 8), 10), "site": site, "row": row,
				"walk": walk_s, "period": walk_s * 2.0 + float(cfg["work_s"]), "t": randf() * 10.0})


func _process(delta: float) -> void:
	_time += delta
	batch.reserve(_list.size())
	for v in _list:
		v["t"] = fmod(float(v["t"]) + delta, float(v["period"]))
		var t: float = v["t"]
		var w: float = v["walk"]
		var p: Vector2
		var frame := int(_time * 6.0) & 1
		var going := true
		if t < w:
			p = (v["home"] as Vector2).lerp(v["site"], t / w)
		elif t < w + float(cfg["work_s"]):
			p = v["site"]
			frame = int(_time * 4.0) & 1  # golpe de hacha / pico
		else:
			p = (v["site"] as Vector2).lerp(v["home"], (t - w - float(cfg["work_s"])) / w)
			going = false
		var dir: float = (v["site"] as Vector2).x - (v["home"] as Vector2).x
		var sc := 1.0 if (dir >= 0.0) == going else -1.0
		batch.put(floorf(p.x + 0.5), floorf(p.y - 2.0 + 0.5), sc, float(frame), float(v["row"]), 0.0, _tint)
	batch.commit()

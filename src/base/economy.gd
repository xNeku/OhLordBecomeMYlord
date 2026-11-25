class_name Economy
extends Node
## Economía de la base (Hito 3). Los trabajadores son un número: el jugador reparte el 100 %
## entre construir, madera y minería. Los recursos solo sirven para construir y mejorar
## (las tropas son gratis). Datos en data/economy.json y data/buildings.json.

signal changed
signal building_finished(id: String, pos: Vector2)
signal message(text: String)

const SPLIT_KEYS := ["build", "wood", "mining"]
const TAG_PLAYER_BUILDING := 1000

var params: Dictionary
var catalog: Dictionary        ## construibles
var upgrades: Dictionary       ## mejoras_cuartel
var split := {"build": 30, "wood": 40, "mining": 30}
var counts: Dictionary = {}    ## id -> cuántas hay terminadas
var queue: Array[Dictionary] = []  ## {id, pos, work, total}
var stat_level: Dictionary = {}
var capacity_level := 0

var battle: Battle
var map: MapData
var store: TroopStore
var faction := "goblin"
var _wood_acc := 0.0
var _min_acc := 0.0
var _type_to_id: Dictionary = {}


func setup(b: Battle, m: MapData, s: TroopStore, hero_faction: String) -> void:
	battle = b
	map = m
	store = s
	faction = hero_faction
	params = _load("res://data/economy.json")
	var bdata := _load("res://data/buildings.json")
	catalog = bdata["construibles"]
	upgrades = bdata["mejoras_cuartel"]
	for k in SPLIT_KEYS:
		split[k] = int(params["default_split"][k])
	for id in catalog:
		counts[id] = 0
		_type_to_id[catalog[id]["unit_type"]] = id
	for a in store.archetypes:
		stat_level[a] = 0
	# las estructuras iniciales del mapa (casas) cuentan como construidas
	for e in map.entities:
		if e["kind"] == "structure" and int(e["team"]) == UnitDB.PLAYER and _type_to_id.has(e["type"]):
			counts[_type_to_id[e["type"]]] += 1
	var sr: Dictionary = params["start_resources"]
	GameState.add_resources(int(sr["wood"]), int(sr["mineral"]))
	changed.emit()


static func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


# ------------------------------------------------------------ trabajadores

func workers() -> int:
	return int(params["base_workers"]) + int(counts.get("house", 0)) * int(params["workers_per_house"])


## Cambia un porcentaje y reparte el resto entre los otros dos para que sumen 100.
func set_split(key: String, value: int) -> void:
	value = clampi(value, 0, 100)
	var others: Array = SPLIT_KEYS.filter(func(k): return k != key)
	var rest := 100 - value
	var a: int = split[others[0]]
	var b: int = split[others[1]]
	if a + b == 0:
		split[others[0]] = rest / 2
	else:
		split[others[0]] = int(round(float(rest) * a / (a + b)))
	split[others[1]] = rest - int(split[others[0]])
	split[key] = value
	changed.emit()


func wood_per_s() -> float:
	var bonus := 1.0 + float(counts.get("lumber_center", 0)) * float(catalog["lumber_center"].get("wood_bonus", 0.0))
	return workers() * split["wood"] / 100.0 * float(params["wood_per_worker_s"]) * bonus


func mineral_per_s() -> float:
	var bonus := 1.0 + float(counts.get("miners_center", 0)) * float(catalog["miners_center"].get("mineral_bonus", 0.0))
	return workers() * split["mining"] / 100.0 * float(params["mineral_per_worker_s"]) * bonus


func build_per_s() -> float:
	return workers() * split["build"] / 100.0 * float(params["build_work_per_worker_s"])


# ------------------------------------------------------------ construcción

func queued_of(id: String) -> int:
	var n := 0
	for q in queue:
		if q["id"] == id:
			n += 1
	return n


## "" si se puede construir; si no, el motivo.
func build_block_reason(id: String) -> String:
	var c: Dictionary = catalog[id]
	if counts[id] + queued_of(id) >= int(c["max"]):
		return "máximo alcanzado"
	if not GameState.can_afford(c["cost"]):
		return "faltan recursos"
	return ""


func order_building(id: String) -> bool:
	if build_block_reason(id) != "":
		message.emit("%s: %s" % [catalog[id]["name"], build_block_reason(id)])
		return false
	var spot := _find_spot()
	if spot == Vector2.INF:
		message.emit("No queda sitio libre alrededor del ayuntamiento")
		return false
	GameState.spend(catalog[id]["cost"])
	var work := float(catalog[id]["work"])
	queue.append({"id": id, "pos": spot, "work": work, "total": work})
	message.emit("Construyendo: %s" % catalog[id]["name"])
	changed.emit()
	return true


func _find_spot() -> Vector2:
	var pl: Dictionary = params["placement"]
	var spacing := float(pl["spacing_px"])
	var taken: Array[Vector2] = []
	var sim := battle.sim
	for i in sim.high:
		if sim.alive[i] == 1 and sim.team[i] == UnitDB.PLAYER and sim.db.is_structure[sim.type[i]] == 1:
			taken.append(Vector2(sim.px[i], sim.py[i]))
	for q in queue:
		taken.append(q["pos"])
	for r in range(int(pl["min_radius_cells"]), int(pl["max_radius_cells"]) + 1):
		var steps := 6 * r
		for k in steps:
			var ang := TAU * k / steps
			var p := map.spawn + Vector2(cos(ang), sin(ang)) * r * map.cell
			if not _clear(p):
				continue
			var ok := true
			for t in taken:
				if t.distance_to(p) < spacing:
					ok = false
					break
			if ok:
				return p
	return Vector2.INF


func _clear(p: Vector2) -> bool:
	for d in [Vector2.ZERO, Vector2(12, 12), Vector2(-12, 12), Vector2(12, -12), Vector2(-12, -12)]:
		if not map.is_walkable(p + d):
			return false
	return true


func on_structure_destroyed(type_id: String, team: int) -> void:
	if team == UnitDB.PLAYER and _type_to_id.has(type_id):
		counts[_type_to_id[type_id]] = maxi(0, counts[_type_to_id[type_id]] - 1)
		changed.emit()


func _process(delta: float) -> void:
	if battle == null:
		return
	_wood_acc += wood_per_s() * delta
	_min_acc += mineral_per_s() * delta
	if _wood_acc >= 1.0 or _min_acc >= 1.0:
		var w := int(_wood_acc)
		var m := int(_min_acc)
		_wood_acc -= w
		_min_acc -= m
		GameState.add_resources(w, m)
	if not queue.is_empty():
		var q: Dictionary = queue[0]
		q["work"] -= build_per_s() * delta
		if q["work"] <= 0.0:
			queue.pop_front()
			var id: String = q["id"]
			var p: Vector2 = q["pos"]
			battle.sim.spawn(catalog[id]["unit_type"], UnitDB.PLAYER, p.x, p.y, false, TAG_PLAYER_BUILDING, maxi(map.zone_at(p), 0))
			counts[id] += 1
			building_finished.emit(id, p)
			message.emit("¡%s terminado!" % catalog[id]["name"])
			changed.emit()


# ------------------------------------------------------- mejoras del cuartel

func barracks_ready() -> bool:
	return counts.get("barracks", 0) > 0


func unlock_cost(arch: String) -> Dictionary:
	return upgrades["unlock"].get(arch, {})


func stat_cost(arch: String) -> Dictionary:
	return _scaled(upgrades["stats"]["cost_base"], stat_level[arch] + 1)


func capacity_cost() -> Dictionary:
	return _scaled(upgrades["capacity"]["cost_base"], capacity_level + 1)


func _scaled(base: Dictionary, lvl: int) -> Dictionary:
	return {"wood": int(base.get("wood", 0)) * lvl, "mineral": int(base.get("mineral", 0)) * lvl}


func _try_pay(cost: Dictionary, what: String) -> bool:
	if not barracks_ready():
		message.emit("Primero construye el cuartel")
		return false
	if not GameState.spend(cost):
		message.emit("%s: faltan recursos" % what)
		return false
	return true


func unlock_archetype(arch: String) -> bool:
	if store.is_unlocked(arch) or not _try_pay(unlock_cost(arch), "Desbloquear"):
		return false
	store.unlock(arch)
	message.emit("¡Tropa desbloqueada! Repártela en la pestaña Tropas")
	changed.emit()
	return true


func upgrade_stats(arch: String) -> bool:
	var st: Dictionary = upgrades["stats"]
	if stat_level[arch] >= int(st["max_level"]) or not store.is_unlocked(arch):
		return false
	if not _try_pay(stat_cost(arch), "Mejora"):
		return false
	stat_level[arch] += 1
	var lvl: int = stat_level[arch]
	battle.db.set_multipliers(battle.db.unit_id(faction, arch),
		1.0 + float(st["hp_per_level"]) * lvl, 1.0 + float(st["damage_per_level"]) * lvl)
	changed.emit()
	return true


func upgrade_capacity() -> bool:
	var cp: Dictionary = upgrades["capacity"]
	if capacity_level >= int(cp["max_level"]):
		return false
	if not _try_pay(capacity_cost(), "Capacidad"):
		return false
	capacity_level += 1
	store.set_capacity(store.capacity + int(cp["per_level"]))
	changed.emit()
	return true


static func cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	if int(cost.get("wood", 0)) > 0:
		parts.append("%d madera" % int(cost["wood"]))
	if int(cost.get("mineral", 0)) > 0:
		parts.append("%d mineral" % int(cost["mineral"]))
	return "gratis" if parts.is_empty() else ", ".join(parts)

class_name World
extends Node2D
## Escena de juego (Hitos 1-4 en versión prototipo). Orquesta módulos independientes:
## MapGenerator/MapData (datos) · WorldView (suelo) · Battle (simulación+render) · Hero · WaveDirector · Hud/Dial.

@onready var view: WorldView = $WorldView
@onready var decor: SpriteBatch = $WorldView/Decor
@onready var battle: Battle = $Battle
@onready var hero: Hero = $Hero
@onready var waves: WaveDirector = $WaveDirector
@onready var hud: Hud = $Ui/Hud
@onready var dial: TroopDial = $Ui/TroopDial
@onready var base_menu: BaseMenu = $Ui/BaseMenu
@onready var economy: Economy = $Economy
@onready var construction: ConstructionView = $Construction
@onready var villagers: VillagerView = $Villagers
@onready var debug: DebugOverlay = $DebugOverlay

var params: Dictionary
var map: MapData
var ended := false


func _ready() -> void:
	GameState.reset_run()
	params = MapGenerator.load_params()
	map = MapGenerator.generate(GameState.seed_value, params)
	var problems := map.validate()
	for p in problems:
		push_warning("Mapa semilla %d: %s" % [map.seed_value, p])

	battle.setup(map.size_px(), 8192)
	battle.sim.set_walk_grid(map.walk, map.w, map.h, map.cell)
	battle.sim.structure_destroyed.connect(_on_structure_destroyed)
	debug.bind(battle)
	view.setup(map, params.get("ground", {}))
	_populate()

	hero.global_position = map.spawn + Vector2(0, 28)
	hero.setup(map, battle)
	hero.zone_changed.connect(_on_zone_changed)
	dial.bind(hero.launcher, hero.store, battle.db, hero.data["faction"])
	economy.setup(battle, map, hero.store, hero.data["faction"])
	economy.message.connect(func(t: String): hud.show_banner(t, 2.5))
	construction.bind(economy)
	villagers.bind(economy, map, battle.db, hero.data)
	base_menu.bind(economy, hero.store, battle.db, hero.data["faction"])
	hero.store.resting_changed.connect(func(on: bool):
		if on: hud.show_banner("Descansando en la base: reponiendo tropas", 2.0))
	waves.setup(battle, map, params)
	waves.wave_started.connect(_on_wave_started)
	hud.retry_pressed.connect(func(): get_tree().reload_current_scene())
	hud.menu_pressed.connect(_to_menu)
	hud.set_objective("Objetivo: destruye la fortaleza de la última zona")
	hud.show_banner("Semilla %d · Q + clic lanza tropas · Tab abre la base" % map.seed_value, 4.0)
	_on_zone_changed(hero.zone)


func _populate() -> void:
	var n_decor := 0
	for e in map.entities:
		if e["kind"] == "decor":
			n_decor += 1
	decor.reserve(n_decor)
	var sim := battle.sim
	for e in map.entities:
		match e["kind"]:
			"decor":
				var p: Vector2 = e["pos"]
				decor.put(p.x, p.y - 4.0, 1.0, float(int(p.x) & 1), float(battle.db.structure_row(e["sprite"])), 0.0, Color.WHITE)
			"structure":
				sim.spawn(e["type"], e["team"], e["pos"].x, e["pos"].y, false, e["tag"], e["zone"])
			"unit":
				sim.spawn(e["type"], e["team"], e["pos"].x, e["pos"].y, e.get("seek", false), e["tag"], e["zone"])
	decor.commit()
	SimRenderer._set_grid(decor, battle.db._structs["grid"])


func _process(_delta: float) -> void:
	if ended:
		return
	var bi := map.barrier_near(hero.global_position, 64.0)
	if bi >= 0 and not map.barriers[bi]["open"]:
		var b: Dictionary = map.barriers[bi]
		var cost: Dictionary = b["cost"]
		var affordable := GameState.can_afford(cost)
		hud.set_prompt("[F] %s — %s" % [b["name"], _cost_text(cost)], affordable)
		if Input.is_action_just_pressed("interact"):
			if GameState.spend(cost):
				map.open_barrier(bi)
				battle.sim.set_walk_grid(map.walk, map.w, map.h, map.cell)  # el array se duplicó al modificarlo
				view.refresh()
				hud.show_banner("%s: ¡camino abierto!" % b["name"], 3.0)
			else:
				hud.show_banner("Faltan recursos (consigue más destruyendo campamentos)", 2.5)
	else:
		hud.set_prompt("")
	hud.set_rates(economy.wood_per_s(), economy.mineral_per_s())
	hero.launcher.mount_chance = economy.mount_chance()
	var st := hero.store
	hud.set_troops("Tropas %d/%d  ·  huecos %d/%d%s" % [st.total(), st.allocated_total(), st.carried_slots(), st.capacity,
		"  ·  reponiendo..." if st.resting else ("  ·  vuelve a la base para reponer" if st.total() < st.allocated_total() and not st.at_base else "")])
	if waves.enabled:
		hud.set_wave_text("Próxima oleada en %ds (oleada %d)" % [int(waves.seconds_to_next()), waves.wave_number + 1])


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	if int(cost.get("wood", 0)) > 0:
		parts.append("%d madera" % int(cost["wood"]))
	if int(cost.get("mineral", 0)) > 0:
		parts.append("%d mineral" % int(cost["mineral"]))
	return "repara/abre por " + ", ".join(parts)


func _on_zone_changed(z: int) -> void:
	if z >= 0:
		hud.set_zone("Zona %d/%d: %s" % [z + 1, map.zones.size(), map.zones[z]["name"]])
	else:
		hud.set_zone("")


func _on_wave_started(number: int, size: int) -> void:
	hud.show_banner("¡Oleada %d! (%d enemigos)" % [number, size], 3.0)


func _on_structure_destroyed(type_id: String, team: int, pos: Vector2, tag: int) -> void:
	economy.on_structure_destroyed(type_id, team)
	match type_id:
		"camp_tent":
			var r: Dictionary = map.camps[tag]["reward"]
			GameState.add_resources(int(r["wood"]), int(r["mineral"]))
			hud.show_banner("Campamento destruido: +%d madera +%d mineral" % [int(r["wood"]), int(r["mineral"])], 3.0)
		"fortress":
			_end(true)
		"townhall":
			_end(false)


func _end(victory: bool) -> void:
	if ended:
		return
	ended = true
	waves.enabled = false
	hero.input_enabled = false
	hud.show_end(victory)


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

extends SceneTree
## Prueba de humo de la campaña SIN ventana y a velocidad máxima:
##   godot --headless --path . --fixed-fps 60 -s tools/smoke_world.gd -- 123
## Teletransporta al héroe, lanza tropas, destruye un campamento, abre la barrera y dispara una oleada.

var w  # sin tipo: world.gd usa el autoload GameState, que no existe al compilar scripts de -s
var failures := 0

func check(cond: bool, msg: String) -> void:
	print(("  OK   " if cond else "  FALLO ") + msg)
	if not cond: failures += 1

func frames(n: int) -> void:
	for i in n: await process_frame

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	root.get_node("GameState").seed_value = int(args[0]) if args.size() > 0 else 123
	w = (load("res://scenes/world/World.tscn") as PackedScene).instantiate()
	root.add_child(w)
	_run()

func _run() -> void:
	await frames(3)
	if w.battle == null or w.battle.sim == null:
		print("RESULTADO smoke: la escena World no cargó (mira los errores de arriba)")
		quit(1)
		return
	var gs := root.get_node("GameState")
	var sim: BattleSim = w.battle.sim
	print("Mapa semilla %d: %d unidades/estructuras vivas, %d campamentos" % [w.map.seed_value, sim.alive_count, w.map.camps.size()])
	check(sim.alive_count > 50, "la simulación se llenó con las entidades del mapa")
	check(w.hero.zone == 0, "el héroe empieza en la zona 0")

	# --- lanzar tropas contra el campamento 0 ---
	var camp: Dictionary = w.map.camps[0]
	var dir: Vector2 = (camp["pos"] - w.map.spawn).normalized()
	var spot: Vector2 = camp["pos"] - dir * 70.0
	if not w.map.is_walkable(spot): spot = w.map.spawn
	w.hero.global_position = spot
	w.hero.last_dir = (camp["pos"] - spot).normalized()
	w.hero.launcher._pad_aim = true
	var before: int = w.hero.store.total()
	Input.action_press("dial_open")
	await frames(2)
	check(w.hero.launcher.active, "mantener dial_open activa el modo lanzar")
	for sel in 4:
		w.hero.launcher.selected = sel
		Input.action_press("throw_troops")
		await frames(40)
		Input.action_release("throw_troops")
	Input.action_release("dial_open")
	await frames(2)
	check(not w.hero.launcher.active, "soltar dial_open sale del modo lanzar")
	var spent: int = before - w.hero.store.total()
	check(spent > 0, "se lanzaron %d tropas" % spent)
	print("  tropas jugador vivas: %d" % sim.team_count[0])

	# --- capacidad por huecos y reposición solo en la base ---
	var st = w.hero.store
	st.set_allocation("base", 9999)
	check(st.used_slots() <= st.capacity, "el reparto nunca supera la capacidad en huecos (%d/%d)" % [st.used_slots(), st.capacity])
	st.set_allocation("base", 30)
	var away: int = st.count_of("base")
	await frames(240)
	check(st.count_of("base") == away, "lejos de la base NO se reponen tropas (%d)" % st.count_of("base"))

	# --- combate contra el campamento ---
	var tents_before := _alive_of(sim, "camp_tent")
	var ticks := 0
	while _alive_of(sim, "camp_tent") == tents_before and ticks < 90 * 60:
		await frames(60)
		ticks += 60
		if sim.team_count[0] < 6 and w.hero.store.total() > 0:
			Input.action_press("dial_open"); Input.action_press("throw_troops")
			await frames(30)
			Input.action_release("throw_troops"); Input.action_release("dial_open")
	check(_alive_of(sim, "camp_tent") < tents_before, "se destruyó un campamento con tropas lanzadas (%ds)" % (ticks / 60))

	w.hero.global_position = w.map.spawn + Vector2(0, 28)
	await frames(60 * 6)
	check(st.count_of("base") == 30, "descansando en la base se reponen gratis (base %d/30)" % st.count_of("base"))

	# --- economía y construcción (Hito 3) ---
	var eco = w.economy
	var wood0: int = gs.wood
	await frames(120)
	check(gs.wood > wood0, "los trabajadores producen madera (%d -> %d)" % [wood0, gs.wood])
	gs.wood = 500; gs.mineral = 500
	eco.set_split("build", 100)
	check(eco.split["build"] + eco.split["wood"] + eco.split["mining"] == 100, "el reparto de trabajadores suma 100")
	check(eco.order_building("barracks"), "se encarga un cuartel")
	var structs_before: int = sim.team_count[0]
	var t2 := 0
	while not eco.barracks_ready() and t2 < 60 * 60:
		await frames(30); t2 += 30
	check(eco.barracks_ready(), "el cuartel se termina con trabajadores en construir (%ds)" % (t2 / 60))
	check(sim.team_count[0] > structs_before, "el cuartel aparece en la simulación")
	check(eco.unlock_archetype("ranged") and st.is_unlocked("ranged"), "el cuartel desbloquea tropas a distancia")
	var t_base: int = sim.db.type_index("goblin_base")
	var hp0: float = sim.db.hp[t_base]
	check(eco.upgrade_stats("base") and sim.db.hp[t_base] > hp0, "mejora de stats sube la vida (%.0f -> %.0f)" % [hp0, sim.db.hp[t_base]])
	var cap0: int = st.capacity
	check(eco.upgrade_capacity() and st.capacity > cap0, "mejora de capacidad (%d -> %d)" % [cap0, st.capacity])
	eco.set_split("build", 30)

	# --- barrera ---
	gs.wood = 500; gs.mineral = 500
	var b: Dictionary = w.map.barriers[0]
	w.hero.global_position = b["pos"] - Vector2(60, 0)
	await frames(3)
	check(not w.map.is_walkable(b["pos"]), "la barrera cerrada no es caminable")
	Input.action_press("interact"); await frames(2); Input.action_release("interact")
	await frames(2)
	check(w.map.barriers[0]["open"], "interactuar con recursos abre la barrera")
	check(w.map.is_walkable(b["pos"]) and sim.walk[w.map.idx(w.map.cell_of(b["pos"]).x, w.map.cell_of(b["pos"]).y)] != 0, "la simulación también ve la barrera abierta")
	# el héroe cruza andando
	Input.action_press("move_right")
	await frames(60 * 6)
	Input.action_release("move_right")
	check(w.hero.zone >= 1, "el héroe cruzó a la zona %d" % w.hero.zone)

	# --- oleada enemiga ---
	w.hero.global_position = w.map.spawn
	w.waves._launch()
	await frames(5)
	check(sim.team_count[1] > 20, "la oleada generó enemigos (equipo 1: %d)" % sim.team_count[1])
	await frames(60 * 40)
	print("  tras 40 s: enemigos=%d, jugador=%d, ayuntamiento vivo=%s" % [sim.team_count[1], sim.team_count[0], str(not w.ended)])
	print("RESULTADO smoke: %d fallos" % failures)
	quit(1 if failures > 0 else 0)


func _alive_of(sim: BattleSim, type_id: String) -> int:
	var t: int = sim.db.type_index(type_id)
	var n := 0
	for i in sim.high:
		if sim.alive[i] == 1 and sim.type[i] == t:
			n += 1
	return n

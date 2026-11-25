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

	# --- menú de tropas: el reparto respeta la capacidad ---
	var st = w.hero.store
	st.set_allocation("base", 9999)
	check(st.allocated_total() <= st.capacity, "el reparto nunca supera la capacidad (%d/%d)" % [st.allocated_total(), st.capacity])
	st.set_allocation("base", 30)
	await frames(240)
	check(st.count_of("base") == 30, "el cuartel repone gratis hasta lo elegido (base %d/30)" % st.count_of("base"))
	var gs0: int = gs.wood + gs.mineral

	# --- dejar combatir 90 s de simulación ---
	var ticks := 0
	while gs.wood == 0 and ticks < 90 * 60:
		await frames(60)
		ticks += 60
		if sim.team_count[0] < 6 and w.hero.store.total() > 0:
			Input.action_press("dial_open"); Input.action_press("throw_troops")
			await frames(30)
			Input.action_release("throw_troops"); Input.action_release("dial_open")
	check(gs.wood > 0, "al destruir el campamento se cobró recompensa (madera=%d mineral=%d, %ds)" % [gs.wood, gs.mineral, ticks / 60])

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

extends SceneTree
## Benchmark de la simulación SIN ventana (Hito 0).
## Uso:  godot --headless --path . -s tools/bench_headless.gd -- 2000 400
##        (unidades por bando, pasos). Imprime ms por paso (media, p95, máx).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var per_side := int(args[0]) if args.size() > 0 else 1000
	var steps := int(args[1]) if args.size() > 1 else 300
	var db := UnitDB.load_from()
	var sim := BattleSim.new()
	sim.setup(db, 3000.0, 2000.0, 4096)
	seed(7)
	var kinds := ["goblin_base", "goblin_base", "goblin_base", "goblin_brute", "goblin_ranged", "goblin_special", "goblin_brute_mounted", "beast_warg"]
	var kinds_b := ["dwarf_base", "dwarf_base", "dwarf_brute", "dwarf_ranged", "dwarf_ranged", "dwarf_special", "dwarf_ranged_mounted", "beast_bear"]
	var spread := 60.0 + sqrt(per_side) * 9.0
	for n in per_side:
		sim.spawn(kinds[randi() % kinds.size()], 0, 900.0 + randf_range(-spread, spread), 1000.0 + randf_range(-spread, spread), true)
		sim.spawn(kinds_b[randi() % kinds_b.size()], 1, 2100.0 + randf_range(-spread, spread), 1000.0 + randf_range(-spread, spread), true)
	var times: Array[float] = []
	for s in steps:
		var t0 := Time.get_ticks_usec()
		sim.step()
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
		if s % 100 == 0:
			print("  paso %d: vivos=%d (jugador %d / enemigo %d)  %.2f ms" % [s, sim.alive_count, sim.team_count[0], sim.team_count[1], times[-1]])
		if sim.team_count[0] == 0 or sim.team_count[1] == 0:
			break
	var sorted := times.duplicate()
	sorted.sort()
	var sum := 0.0
	for v in times: sum += v
	print("RESULTADO unidades/bando=%d  pasos=%d  media=%.2f ms  p95=%.2f ms  max=%.2f ms  (presupuesto a %d Hz = %.1f ms)" % [
		per_side, times.size(), sum / times.size(), sorted[int(sorted.size() * 0.95)], sorted[-1], BattleSim.STEP_HZ, 1000.0 / BattleSim.STEP_HZ])
	quit()

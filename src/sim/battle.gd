class_name Battle
extends Node2D
## Nodo que posee una BattleSim y la avanza con paso fijo. La lógica vive en BattleSim;
## el dibujado en SimRenderer (hijo). Se reutiliza en el mundo y en el benchmark.

signal stepped

@onready var renderer: SimRenderer = $SimRenderer

var sim: BattleSim
var db: UnitDB
var accum := 0.0
var time_scale := 1.0
var paused := false
var last_step_ms := 0.0
var avg_step_ms := 0.0
var worst_recent_ms := 0.0
var _worst_timer := 0.0
var _worst_acc := 0.0


func setup(world_size: Vector2, initial_capacity: int = 4096) -> void:
	db = UnitDB.load_from()
	sim = BattleSim.new()
	sim.setup(db, world_size.x, world_size.y, initial_capacity)
	renderer.bind(sim)


func _process(delta: float) -> void:
	if sim == null or paused:
		return
	accum += delta * time_scale
	var steps := 0
	while accum >= BattleSim.STEP_DT and steps < 3:
		var t0 := Time.get_ticks_usec()
		sim.step(BattleSim.STEP_DT)
		last_step_ms = (Time.get_ticks_usec() - t0) / 1000.0
		avg_step_ms = lerpf(avg_step_ms, last_step_ms, 0.1)
		_worst_acc = maxf(_worst_acc, last_step_ms)
		accum -= BattleSim.STEP_DT
		steps += 1
		stepped.emit()
	if steps == 3:
		accum = 0.0  # la simulación no llega al tiempo real: se ralentiza en vez de acumular deuda
	_worst_timer += delta
	if _worst_timer >= 2.0:
		worst_recent_ms = _worst_acc
		_worst_acc = 0.0
		_worst_timer = 0.0
	renderer.alpha = clampf(accum / BattleSim.STEP_DT, 0.0, 1.0)

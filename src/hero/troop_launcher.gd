class_name TroopLauncher
extends Node2D
## Modo "lanzar tropas": mantener dial_open abre el dial; throw_troops coloca tropas.
## Las tropas lanzadas pasan a la simulación y luchan solas. Sin selección ni órdenes.

signal dial_toggled(active: bool)
signal selection_changed(index: int)
signal thrown(arch: String, amount: int)

var hero: Hero
var battle: Battle
var map: MapData
var store: TroopStore
var archetypes: Array = []
var faction := "goblin"
var launch_radius := 110.0
var batch := 4
var repeat_s := 0.08

## Probabilidad de que una tropa lanzada salga montada (la sube el Centro de bestias). La pone World.
var mount_chance := 0.0

var active := false
var selected := 0
var aim := Vector2.ZERO
var _cooldown := 0.0
var _suppressed := false  ## clic derecho / B: sale del modo hasta soltar el botón del dial
var _pad_aim := false


func setup(h: Hero, b: Battle, m: MapData, hero_data: Dictionary, s: TroopStore) -> void:
	hero = h
	battle = b
	map = m
	store = s
	archetypes = hero_data["archetypes"]
	faction = hero_data["faction"]
	launch_radius = float(hero_data["launch_radius"])
	batch = int(hero_data["throw_batch"])
	repeat_s = float(hero_data["throw_repeat_s"])


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pad_aim = false
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		_pad_aim = true


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("dial_next"):
		_select((selected + 1) % archetypes.size())
	elif event.is_action_pressed("dial_prev"):
		_select((selected - 1 + archetypes.size()) % archetypes.size())
	elif event.is_action_pressed("cancel"):
		_suppressed = true
		_set_active(false)


func _select(i: int) -> void:
	if i != selected:
		selected = i
		selection_changed.emit(selected)


func _set_active(on: bool) -> void:
	if active == on:
		return
	active = on
	dial_toggled.emit(on)
	queue_redraw()


func _process(delta: float) -> void:
	if hero == null:
		return
	var want := Input.is_action_pressed("dial_open") and not _suppressed
	if not Input.is_action_pressed("dial_open"):
		_suppressed = false
	_set_active(want)
	if not active:
		return

	# selección con el stick derecho (ángulo -> casilla: 0 arriba, 1 derecha, 2 abajo, 3 izquierda)
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() > 0.6 and archetypes.size() == 4:
		var ang := fposmod(rs.angle() + PI / 2.0 + PI / 4.0, TAU)
		_select(int(ang / (PI / 2.0)) % 4)

	_update_aim()
	_cooldown -= delta
	if Input.is_action_pressed("throw_troops") and _cooldown <= 0.0:
		_cooldown = repeat_s
		_throw()
	queue_redraw()


func _update_aim() -> void:
	var raw: Vector2
	if _pad_aim:
		raw = hero.global_position + hero.last_dir * launch_radius * 0.75
	else:
		raw = get_global_mouse_position()
	var off := raw - hero.global_position
	if off.length() > launch_radius:
		off = off.normalized() * launch_radius
	var p := hero.global_position + off
	# se pega a zona válida: retrocede hacia el héroe hasta encontrar suelo caminable
	var tries := 0
	while not map.is_walkable(p) and tries < 24:
		p = hero.global_position + (p - hero.global_position) * 0.9
		tries += 1
	aim = p


func _throw() -> void:
	var arch: String = archetypes[selected]
	if not store.is_unlocked(arch):
		return
	var n := store.take(arch, batch)
	if n <= 0:
		return
	var type_id := battle.db.unit_id(faction, arch)
	var mounted_id := battle.db.mounted_id(faction, arch)
	var z := maxi(map.zone_at(hero.global_position), 0)
	for k in n:
		var tid := type_id
		if mounted_id != "" and randf() < mount_chance:
			tid = mounted_id
		var jitter := Vector2(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))
		var p := aim + jitter
		if not map.is_walkable(p):
			p = aim
		battle.sim.spawn(tid, UnitDB.PLAYER, p.x, p.y, true, -1, z)
	thrown.emit(arch, n)


func _draw() -> void:
	if not active:
		return
	var col := Color(0.65, 1.0, 0.18, 0.35)
	draw_arc(Vector2.ZERO, launch_radius, 0.0, TAU, 72, col, 1.0)
	var local_aim := to_local(aim)
	draw_arc(local_aim, 6.0, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 1.0)
	draw_line(local_aim + Vector2(-9, 0), local_aim + Vector2(-4, 0), Color(1, 1, 1, 0.9), 1.0)
	draw_line(local_aim + Vector2(9, 0), local_aim + Vector2(4, 0), Color(1, 1, 1, 0.9), 1.0)
	draw_line(local_aim + Vector2(0, -9), local_aim + Vector2(0, -4), Color(1, 1, 1, 0.9), 1.0)
	draw_line(local_aim + Vector2(0, 9), local_aim + Vector2(0, 4), Color(1, 1, 1, 0.9), 1.0)

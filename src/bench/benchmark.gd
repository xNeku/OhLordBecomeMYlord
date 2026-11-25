extends Node2D
## Hito 0: dos bandos luchando. Criterio: 2.000 unidades a 60 FPS en Mac y tablet.
## Teclas: +/- (o botones) cambian unidades por bando, F3 oculta el overlay, rueda = zoom.

const WORLD := Vector2(3000, 2000)

@onready var battle: Battle = $Battle
@onready var cam: Camera2D = $Camera2D
@onready var overlay: DebugOverlay = $DebugOverlay
@onready var info: Label = $Ui/Panel/Box/Info

var per_side := 1000
var _restart_timer := 0.0
var _auto_restart := true


func _ready() -> void:
	battle.setup(WORLD, 8192)
	overlay.bind(battle)
	cam.position = WORLD * 0.5
	_start_battle()


func _start_battle() -> void:
	var sim := battle.sim
	sim.clear_all()
	var kinds_a := ["goblin_base", "goblin_base", "goblin_base", "goblin_brute", "goblin_ranged", "goblin_special"]
	var kinds_b := ["dwarf_base", "dwarf_base", "dwarf_brute", "dwarf_ranged", "dwarf_ranged", "dwarf_special"]
	var spread := 60.0 + sqrt(per_side) * 9.0
	for n in per_side:
		sim.spawn(kinds_a[randi() % kinds_a.size()], 0, 900.0 + randf_range(-spread, spread), 1000.0 + randf_range(-spread, spread), true)
		sim.spawn(kinds_b[randi() % kinds_b.size()], 1, 2100.0 + randf_range(-spread, spread), 1000.0 + randf_range(-spread, spread), true)
	_refresh_info()


func _refresh_info() -> void:
	info.text = "Unidades por bando: %d (total %d)" % [per_side, per_side * 2]


func _process(delta: float) -> void:
	var sim := battle.sim
	if _auto_restart and (sim.team_count[0] == 0 or sim.team_count[1] == 0):
		_restart_timer += delta
		if _restart_timer > 2.0:
			_restart_timer = 0.0
			_start_battle()
	var pan := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	cam.position += pan * 600.0 * delta / cam.zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom = (cam.zoom * 1.15).clamp(Vector2(0.15, 0.15), Vector2(6, 6))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom = (cam.zoom / 1.15).clamp(Vector2(0.15, 0.15), Vector2(6, 6))
	if event.is_action_pressed("back_to_menu"):
		_on_back_pressed()


func _on_more_pressed() -> void:
	per_side = mini(per_side + 500, 20000)
	_start_battle()


func _on_less_pressed() -> void:
	per_side = maxi(per_side - 500, 100)
	_start_battle()


func _on_restart_pressed() -> void:
	_start_battle()


func _on_fast_toggled(on: bool) -> void:
	battle.time_scale = 3.0 if on else 1.0


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

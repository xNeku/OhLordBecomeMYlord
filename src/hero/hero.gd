class_name Hero
extends Node2D
## Héroe controlado por el jugador. Se mueve libremente por celdas caminables del mapa.
## Lleva las tropas (TroopStore) y el lanzador (TroopLauncher) como hijos.

signal zone_changed(zone: int)

@onready var sprite: Sprite2D = $Sprite
@onready var camera: Camera2D = $Camera2D
@onready var store: TroopStore = $TroopStore
@onready var launcher: TroopLauncher = $Launcher

var data: Dictionary
var map: MapData
var speed := 96.0
var radius := 4.0
var zone := -1
var last_dir := Vector2.RIGHT
var input_enabled := true
var _anim_t := 0.0


func _ready() -> void:
	var f := FileAccess.open("res://data/hero.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	speed = float(data["speed"])
	radius = float(data["radius"])
	sprite.scale = Vector2.ONE * float(data["scale"])


func setup(map_data: MapData, battle: Battle) -> void:
	map = map_data
	var slot_of := {}
	for a in data["archetypes"]:
		slot_of[a] = battle.db.slots[battle.db.type_index(battle.db.unit_id(data["faction"], a))]
	store.configure(data, slot_of)
	launcher.setup(self, battle, map_data, data, store)
	var size := map.size_px()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(size.x)
	camera.limit_bottom = int(size.y)


func _physics_process(delta: float) -> void:
	var v := Vector2.ZERO
	if input_enabled:
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v != Vector2.ZERO:
		last_dir = v.normalized()
		var step := v * speed * delta
		_try_move(Vector2(step.x, 0.0))
		_try_move(Vector2(0.0, step.y))
		_anim_t += delta
		sprite.region_rect.position.x = 16.0 * (int(_anim_t * 8.0) & 1)
		if v.x != 0.0:
			sprite.flip_h = v.x < 0.0
	else:
		sprite.region_rect.position.x = 0.0
	if map != null:
		store.at_base = position.distance_to(map.spawn) <= store.refill_radius
	var z := map.zone_at(position) if map != null else -1
	if z != zone:
		zone = z
		zone_changed.emit(zone)


func _try_move(d: Vector2) -> void:
	if d == Vector2.ZERO or map == null:
		position += d
		return
	var np := position + d
	for c in [Vector2(radius, radius), Vector2(-radius, radius), Vector2(radius, -radius), Vector2(-radius, -radius)]:
		if not map.is_walkable(np + c):
			return
	position = np

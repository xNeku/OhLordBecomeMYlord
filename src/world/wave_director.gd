class_name WaveDirector
extends Node
## Oleadas enemigas simples (propuesta mínima de la sección 9 del GDD): un temporizador lanza
## grupos crecientes que entran por `raid_point` y atacan lo más cercano (ayuntamiento, casas...).

signal wave_started(number: int, size: int)

var battle: Battle
var map: MapData
var params: Dictionary
var enabled := false
var wave_number := 0
var _timer := 0.0
var _mix_types: Array = []
var _mix_weights: Array = []


func setup(b: Battle, m: MapData, world_params: Dictionary) -> void:
	battle = b
	map = m
	params = world_params["waves"]
	_timer = float(params["start_s"])
	for type in params["mix"]:
		_mix_types.append(type)
		_mix_weights.append(float(params["mix"][type]))
	enabled = true


func seconds_to_next() -> float:
	return maxf(_timer, 0.0)


func _process(delta: float) -> void:
	if not enabled or battle == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer += float(params["interval_s"])
		_launch()


func _launch() -> void:
	wave_number += 1
	var size := mini(int(params["base_size"]) + int(params["growth"]) * (wave_number - 1), int(params["max_size"]))
	var total := 0.0
	for w in _mix_weights:
		total += w
	var zone := maxi(map.zone_at(map.raid_point), 0)
	for n in size:
		var roll := randf() * total
		var pick := 0
		for k in _mix_weights.size():
			roll -= _mix_weights[k]
			if roll <= 0.0:
				pick = k
				break
		var p := map.raid_point + Vector2(randf_range(-28.0, 28.0), randf_range(-28.0, 28.0))
		if not map.is_walkable(p):
			p = map.raid_point
		battle.sim.spawn(_mix_types[pick], UnitDB.ENEMY, p.x, p.y, true, -1, zone)
	wave_started.emit(wave_number, size)

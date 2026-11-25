class_name UnitDB
extends RefCounted
## Tabla de tipos de unidad/estructura cargada de data/units.json.
## Guarda los datos en arrays empaquetados indexados por "type index" para que
## el bucle caliente de la simulación no toque diccionarios.

const PLAYER := 0
const ENEMY := 1
const NEUTRAL := 2

var ids: PackedStringArray = PackedStringArray()
var index_of: Dictionary = {}
var raw: Array[Dictionary] = []

var hp := PackedFloat32Array()
var damage := PackedFloat32Array()
var cooldown := PackedFloat32Array()
var attack_range := PackedFloat32Array()
var speed := PackedFloat32Array()
var radius := PackedFloat32Array()
var aggro := PackedFloat32Array()
var splash := PackedFloat32Array()
var sprite_row := PackedInt32Array()
var projectile_row := PackedInt32Array()  ## fila del proyectil en units.png
var draw_scale := PackedFloat32Array()
var tint := PackedColorArray()
var is_structure := PackedByteArray()
var is_suicide := PackedByteArray()

## hostile_mask[team] = bits de equipos a los que ese equipo ataca.
var hostile_mask := PackedInt32Array([0, 0, 0, 0])


static func load_from(path: String = "res://data/units.json") -> UnitDB:
	var db := UnitDB.new()
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "No se pudo abrir " + path)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	for team_key in data.get("hostility", {}):
		var mask := 0
		for t in data["hostility"][team_key]:
			mask |= 1 << int(t)
		db.hostile_mask[int(team_key)] = mask
	var types: Dictionary = data["types"]
	for id in types:
		db._add(id, types[id])
	return db


func _add(id: String, d: Dictionary) -> void:
	index_of[id] = ids.size()
	ids.append(id)
	raw.append(d)
	hp.append(d.get("hp", 1))
	damage.append(d.get("damage", 0))
	cooldown.append(d.get("cooldown", 1.0))
	attack_range.append(d.get("range", 0))
	speed.append(d.get("speed", 0))
	radius.append(d.get("radius", 4))
	aggro.append(d.get("aggro", 0))
	splash.append(d.get("splash", 0))
	sprite_row.append(d.get("sprite", 0))
	projectile_row.append(d.get("projectile_sprite", d.get("sprite", 0)))
	draw_scale.append(d.get("scale", 1.0))
	tint.append(Color(d.get("tint", "#FFFFFF")))
	is_structure.append(1 if d.get("structure", false) else 0)
	is_suicide.append(1 if d.get("suicide", false) else 0)


func type_index(id: String) -> int:
	return index_of[id]


func info(id: String) -> Dictionary:
	return raw[index_of[id]]


## Id del tipo de unidad móvil para (facción, arquetipo), p.ej. ("goblin","brute").
func unit_id(faction: String, archetype: String) -> String:
	return "%s_%s" % [faction, archetype]

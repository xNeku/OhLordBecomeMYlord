class_name UnitDB
extends RefCounted
## Tabla de tipos de unidad/estructura cargada de data/units.json.
## Guarda los datos en arrays empaquetados indexados por "type index" para que
## el bucle caliente de la simulación no toque diccionarios.

const PLAYER := 0
const ENEMY := 1
const NEUTRAL := 2

## Atlas en el que se dibuja cada tipo (ver data/units.json "atlas")
const ATLAS_FOOT := 0
const ATLAS_MOUNTED := 1
const ATLAS_BEAST := 2
const ATLAS_STRUCTURE := 3
const ATLAS_NAMES := {"foot": ATLAS_FOOT, "mounted": ATLAS_MOUNTED, "beast": ATLAS_BEAST, "structure": ATLAS_STRUCTURE}
const MANIFEST_SECTION := {ATLAS_FOOT: "units_foot", ATLAS_MOUNTED: "units_mounted", ATLAS_BEAST: "beasts"}

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
var projectile_row := PackedInt32Array()  ## fila en projectiles.png, -1 = sin proyectil visual
var projectile_tint := PackedColorArray()
var atlas := PackedByteArray()            ## ATLAS_*
var fx_row := PackedInt32Array()          ## fila en units_foot.png para la partícula de muerte, -1 = ninguna
var fx_melee_row := PackedInt32Array()    ## fila en fx.png del golpe cuerpo a cuerpo, -1 = ninguno
var fx_impact_row := PackedInt32Array()   ## fila en fx.png del impacto de la magia, -1 = ninguno
var level := PackedInt32Array()           ## nivel visual 1..3 (sufijo _nN de los sprites)
var draw_scale := PackedFloat32Array()
var tint := PackedColorArray()
var is_structure := PackedByteArray()
var is_suicide := PackedByteArray()
var slots := PackedInt32Array()          ## huecos de capacidad del héroe que ocupa
var base_hp := PackedFloat32Array()      ## valores sin mejoras (para recalcular)
var base_damage := PackedFloat32Array()

## hostile_mask[team] = bits de equipos a los que ese equipo ataca.
var hostile_mask := PackedInt32Array([0, 0, 0, 0])


var _art: Dictionary = {}
var _proj: Dictionary = {}
var _structs: Dictionary = {}
var _fx: Dictionary = {}


static func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "No se pudo abrir " + path)
	return JSON.parse_string(f.get_as_text())


static func load_from(path: String = "res://data/units.json") -> UnitDB:
	var db := UnitDB.new()
	db._art = _json("res://assets/atlas/art_manifest.json")
	db._proj = _json("res://assets/atlas/projectiles_manifest.json")["filas"]
	db._structs = _json("res://assets/atlas/structures_manifest.json")
	db._fx = _json("res://assets/atlas/fx_manifest.json")
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
	var at: int = ATLAS_NAMES.get(d.get("atlas", "structure" if d.get("structure", false) else "foot"), ATLAS_FOOT)
	atlas.append(at)
	sprite_row.append(0)
	projectile_row.append(-1)
	fx_row.append(-1)
	fx_melee_row.append(-1)
	fx_impact_row.append(-1)
	level.append(1)
	projectile_tint.append(Color(d.get("projectile_tint", "#FFFFFF")))
	_resolve_visuals(ids.size() - 1)
	draw_scale.append(d.get("scale", 1.0))
	tint.append(Color(d.get("tint", "#FFFFFF")))
	is_structure.append(1 if d.get("structure", false) else 0)
	is_suicide.append(1 if d.get("suicide", false) else 0)
	slots.append(int(d.get("slots", 1)))
	base_hp.append(d.get("hp", 1))
	base_damage.append(d.get("damage", 0))


func type_index(id: String) -> int:
	return index_of[id]


func info(id: String) -> Dictionary:
	return raw[index_of[id]]


## Id del tipo de unidad móvil para (facción, arquetipo), p.ej. ("goblin","brute").
func unit_id(faction: String, archetype: String) -> String:
	return "%s_%s" % [faction, archetype]


## Aplica multiplicadores de mejora a un tipo (afecta a las unidades que se generen después).
func set_multipliers(id: String, hp_mult: float, damage_mult: float) -> void:
	var t: int = index_of[id]
	hp[t] = base_hp[t] * hp_mult
	damage[t] = base_damage[t] * damage_mult


## Convierte un id de sprite del manifest de arte en su fila (o deja la fila numérica tal cual).
func _resolve(at: int, sprite, id: String) -> int:
	if typeof(sprite) != TYPE_STRING:
		return int(sprite)
	var filas: Dictionary = _structs["filas"] if at == ATLAS_STRUCTURE else _art[MANIFEST_SECTION[at]]["filas"]
	if not filas.has(sprite):
		push_warning("Sprite '%s' (tipo %s) no está en art_manifest.json" % [sprite, id])
		return 0
	return int(filas[sprite])


## Id del tipo montado de un arquetipo, o "" si no existe.
func mounted_id(faction: String, archetype: String) -> String:
	var k := "%s_%s_mounted" % [faction, archetype]
	return k if index_of.has(k) else ""


## Fila en structures.png de un id del manifest de estructuras (decoración, andamio...).
func structure_row(sprite_id: String) -> int:
	return _resolve(ATLAS_STRUCTURE, sprite_id, sprite_id)


static func _lv(sprite_id: String, lvl: int) -> String:
	var re := RegEx.create_from_string("_n[0-9]+$")
	return re.sub(sprite_id, "_n%d" % lvl) if re.search(sprite_id) != null else sprite_id


## Recalcula las filas de sprite, proyectil y efectos de un tipo según su nivel visual.
func _resolve_visuals(t: int) -> void:
	var d: Dictionary = raw[t]
	var at: int = atlas[t]
	var lv := level[t]
	var id := ids[t]
	var spr = d.get("sprite", 0)
	sprite_row[t] = _resolve(at, _lv(spr, lv) if typeof(spr) == TYPE_STRING else spr, id)
	projectile_row[t] = int(_proj.get(_lv(d.get("projectile", ""), lv), -1))
	fx_melee_row[t] = int(_fx["filas"].get(_lv(d.get("fx_melee", ""), lv), -1))
	fx_impact_row[t] = int(_fx["filas"].get(_lv(d.get("fx_impact", ""), lv), -1))
	if d.has("fx_sprite"):
		fx_row[t] = _resolve(ATLAS_FOOT, _lv(d["fx_sprite"], lv), id)
	elif at == ATLAS_FOOT:
		fx_row[t] = sprite_row[t]
	else:
		fx_row[t] = -1


## Cambia el nivel visual (1..3) de un tipo: sprite, proyectil y efectos pasan a los _nN.
func set_level(id: String, lvl: int) -> void:
	var t: int = index_of[id]
	level[t] = clampi(lvl, 1, 3)
	_resolve_visuals(t)

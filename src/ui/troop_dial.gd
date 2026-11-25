class_name TroopDial
extends Control
## Dial radial de tropas (4 arquetipos). Solo visible mientras se mantiene dial_open.

const UNITS_ATLAS := preload("res://assets/atlas/units.png")
const FACTION_ROW := {"goblin": 0, "orc": 1, "dwarf": 2, "elf": 3}

@onready var slots: Array[DialSlot] = [
	$Ring/SlotUp, $Ring/SlotRight, $Ring/SlotDown, $Ring/SlotLeft]
@onready var hint: Label = $Ring/Hint

var launcher: TroopLauncher
var store: TroopStore


func bind(l: TroopLauncher, s: TroopStore, db: UnitDB, faction: String) -> void:
	launcher = l
	store = s
	for i in slots.size():
		var arch: String = l.archetypes[i]
		var info := db.info(db.unit_id(faction, arch))
		var tex := AtlasTexture.new()
		tex.atlas = UNITS_ATLAS
		tex.region = Rect2(0, 16 * FACTION_ROW[faction], 16, 16)
		slots[i].setup(tex, "%s  [%s]" % [info["name"], arch], float(info["scale"]))
	l.dial_toggled.connect(func(on: bool): visible = on)
	l.selection_changed.connect(_on_selection)
	s.changed.connect(_refresh_counts)
	visible = false
	_refresh_counts()
	_on_selection(l.selected)


func _on_selection(index: int) -> void:
	for i in slots.size():
		slots[i].set_selected(i == index)


func _refresh_counts() -> void:
	for i in slots.size():
		var a: String = launcher.archetypes[i]
		slots[i].set_count(store.count_of(a), store.max_of(a), store.is_unlocked(a))
	hint.text = "huecos %d / %d" % [store.carried_slots(), store.capacity]

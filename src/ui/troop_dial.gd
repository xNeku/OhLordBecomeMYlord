class_name TroopDial
extends Control
## Dial radial de tropas (4 arquetipos). Solo visible mientras se mantiene dial_open.

const UNITS_ATLAS := preload("res://assets/atlas/units_foot.png")

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
		var id := db.unit_id(faction, arch)
		var t := db.type_index(id)
		var tex := AtlasTexture.new()
		tex.atlas = UNITS_ATLAS
		tex.region = Rect2(0, 16 * db.sprite_row[t], 16, 16)
		slots[i].setup(tex, db.info(id)["name"], 1.0)
		slots[i].icon.modulate = db.tint[t]
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

class_name BuildRow
extends HBoxContainer
## Fila "construir X": el id del edificio se fija en la escena (data/buildings.json > construibles).

signal build_requested(id: String)

@export var building_id := "house"

@onready var name_label: Label = $Info/Name
@onready var effect_label: Label = $Info/Effect
@onready var cost_label: Label = $Cost
@onready var button: Button = $Build


func show_state(info: Dictionary, built: int, queued: int, block_reason: String) -> void:
	name_label.text = "%s  (%d/%d%s)" % [info["name"], built, int(info["max"]), (" +%d en obra" % queued) if queued > 0 else ""]
	effect_label.text = info.get("effect", "")
	cost_label.text = Economy.cost_text(info["cost"])
	button.disabled = block_reason != ""
	button.tooltip_text = block_reason


func _on_build_pressed() -> void:
	build_requested.emit(building_id)

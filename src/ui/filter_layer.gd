extends CanvasLayer
## Autoload "Filters": filtro de visión retro a pantalla completa (post-proceso).
## Orden y shaders en assets/atlas/filtros.json (entregado por arte). Se guarda la elección.

signal changed(display_name: String)

const LIST := "res://assets/atlas/filtros.json"
const SETTINGS := "user://ajustes.cfg"

@onready var rect: ColorRect = $Rect

var entries: Array = []
var index := 0


func _ready() -> void:
	var f := FileAccess.open(LIST, FileAccess.READ)
	entries = JSON.parse_string(f.get_as_text())["orden"]
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		index = clampi(int(cfg.get_value("video", "filtro", 0)), 0, entries.size() - 1)
	_apply()


func current_name() -> String:
	return entries[index]["nombre"]


func cycle() -> void:
	index = (index + 1) % entries.size()
	_apply()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("video", "filtro", index)
	cfg.save(SETTINGS)


func _apply() -> void:
	var e: Dictionary = entries[index]
	if e.get("shader") == null:
		rect.visible = false
		rect.material = null
	else:
		var mat := ShaderMaterial.new()
		mat.shader = load(e["shader"])
		rect.material = mat
		rect.visible = true
	changed.emit(current_name())

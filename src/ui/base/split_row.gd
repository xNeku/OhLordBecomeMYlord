class_name SplitRow
extends HBoxContainer
## Barra de porcentaje de una tarea del ayuntamiento (construir / madera / minería).

signal value_requested(key: String, value: int)

@export var key := "build"
@export var title := "Construir"

@onready var name_label: Label = $Name
@onready var slider: HSlider = $Slider
@onready var value_label: Label = $Value


func _ready() -> void:
	name_label.text = title


func show_value(v: int) -> void:
	slider.set_value_no_signal(v)
	value_label.text = "%d %%" % v


func _on_slider_value_changed(v: float) -> void:
	value_requested.emit(key, int(v))

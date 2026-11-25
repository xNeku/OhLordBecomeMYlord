class_name LoadoutRow
extends HBoxContainer
## Fila del menú de tropas: nombre, [-], cantidad elegida, [+].

signal delta_requested(arch: String, delta: int)

@onready var name_label: Label = $Name
@onready var value_label: Label = $Value
@onready var minus: Button = $Minus
@onready var plus: Button = $Plus

var arch := ""


func setup(archetype: String, display_name: String) -> void:
	arch = archetype
	name_label.text = display_name


func show_value(n: int, carried: int, unlocked: bool) -> void:
	value_label.text = ("%d  (llevas %d)" % [n, carried]) if unlocked else "bloqueado"
	minus.disabled = not unlocked
	plus.disabled = not unlocked


func _on_minus_pressed() -> void:
	delta_requested.emit(arch, -5)


func _on_plus_pressed() -> void:
	delta_requested.emit(arch, 5)

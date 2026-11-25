class_name DialSlot
extends Control
## Una casilla del dial de tropas: icono, nombre y cantidad.

@onready var icon: TextureRect = $Panel/Icon
@onready var count_label: Label = $Panel/Count
@onready var name_label: Label = $Name
@onready var panel: Panel = $Panel


func setup(texture: Texture2D, display_name: String, icon_scale: float) -> void:
	icon.texture = texture
	var s := 32.0 * icon_scale
	icon.custom_minimum_size = Vector2(s, s)
	icon.size = Vector2(s, s)
	icon.position = (panel.size - icon.size) * 0.5 + Vector2(0, -4)
	name_label.text = display_name


func set_count(n: int, max_n: int, unlocked: bool = true) -> void:
	count_label.text = ("%d/%d" % [n, max_n]) if unlocked else "bloq."
	modulate.a = 1.0 if n > 0 else 0.45


func set_selected(on: bool) -> void:
	scale = Vector2.ONE * (1.18 if on else 1.0)
	panel.self_modulate = Color(0.65, 1.0, 0.18, 1.0) if on else Color(1, 1, 1, 0.7)
	name_label.visible = on

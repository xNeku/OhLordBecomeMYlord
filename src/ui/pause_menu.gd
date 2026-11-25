class_name PauseMenu
extends CanvasLayer
## Menú de pausa (Esc): continuar, rotar filtro de visión, volver al menú principal.

@onready var root_ctl: Control = $Root
@onready var filter_button: Button = $Root/Center/Panel/Box/Filter


func _ready() -> void:
	root_ctl.visible = false
	Filters.changed.connect(func(_n): _refresh())
	_refresh()


func _refresh() -> void:
	filter_button.text = "Filtro: %s" % Filters.current_name()


func toggle() -> void:
	root_ctl.visible = not root_ctl.visible
	get_tree().paused = root_ctl.visible
	if root_ctl.visible:
		$Root/Center/Panel/Box/Continue.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back_to_menu"):
		toggle()
		get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	toggle()


func _on_filter_pressed() -> void:
	Filters.cycle()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

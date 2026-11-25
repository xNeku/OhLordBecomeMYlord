class_name Hud
extends Control
## HUD de la campaña: recursos, zona, objetivo, mensajes, prompt de interacción y pantalla final.

signal retry_pressed
signal menu_pressed

@onready var res_label: Label = $Top/Resources
@onready var zone_label: Label = $Top/Zone
@onready var objective: Label = $Top/Objective
@onready var banner: Label = $Banner
@onready var prompt: Label = $Prompt
@onready var end_panel: PanelContainer = $EndPanel
@onready var end_title: Label = $EndPanel/Box/Title
@onready var wave_label: Label = $Top/Wave

var _banner_t := 0.0


func _ready() -> void:
	banner.visible = false
	prompt.visible = false
	end_panel.visible = false
	GameState.resources_changed.connect(_refresh_resources)
	_refresh_resources()


func _refresh_resources() -> void:
	res_label.text = "Madera %d    Mineral %d" % [GameState.wood, GameState.mineral]


func set_zone(text: String) -> void:
	zone_label.text = text


func set_objective(text: String) -> void:
	objective.text = text


func set_wave_text(text: String) -> void:
	wave_label.text = text


func show_banner(text: String, secs: float = 3.0) -> void:
	banner.text = text
	banner.visible = true
	_banner_t = secs


func set_prompt(text: String, affordable: bool = true) -> void:
	prompt.visible = text != ""
	prompt.text = text
	prompt.modulate = Color(1, 1, 1, 1) if affordable else Color(1, 0.45, 0.4, 1)


func show_end(victory: bool) -> void:
	end_title.text = "¡VICTORIA!" if victory else "DERROTA"
	end_title.modulate = Color(0.65, 1, 0.18) if victory else Color(1, 0.35, 0.3)
	end_panel.visible = true
	$EndPanel/Box/Retry.grab_focus()


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			banner.visible = false


func _on_retry_pressed() -> void:
	retry_pressed.emit()


func _on_menu_pressed() -> void:
	menu_pressed.emit()

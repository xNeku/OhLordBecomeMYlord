class_name UpgradeRow
extends HBoxContainer
## Fila del cuartel para un arquetipo: desbloquear o subir nivel de stats.

signal action_requested(archetype: String)

@export var archetype := "base"

@onready var name_label: Label = $Info/Name
@onready var detail_label: Label = $Info/Detail
@onready var cost_label: Label = $Cost
@onready var button: Button = $Action


func show_state(display_name: String, slots: int, unlocked: bool, level: int, max_level: int, cost: Dictionary, bonus_pct: int, ready: bool) -> void:
	name_label.text = "%s  · ocupa %d" % [display_name, slots]
	if not unlocked:
		detail_label.text = "Bloqueada"
		button.text = "Desbloquear"
	elif level >= max_level:
		detail_label.text = "Nivel %d (máximo) · +%d %% vida y daño" % [level, bonus_pct]
		button.text = "Máximo"
	else:
		detail_label.text = "Nivel %d · +%d %% vida y daño" % [level, bonus_pct]
		button.text = "Mejorar"
	cost_label.text = "" if (unlocked and level >= max_level) else Economy.cost_text(cost)
	button.disabled = not ready or (unlocked and level >= max_level) or not GameState.can_afford(cost)


func _on_action_pressed() -> void:
	action_requested.emit(archetype)

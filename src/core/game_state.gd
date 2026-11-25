extends Node
## Estado global mínimo (autoload "GameState"): semilla elegida, recursos y modo.

signal resources_changed

var seed_value: int = 12345
var mode: String = "campaign"  ## "campaign" | "benchmark"
var wood: int = 0
var mineral: int = 0


func reset_run() -> void:
	wood = 0
	mineral = 0
	resources_changed.emit()


func add_resources(w: int, m: int) -> void:
	wood += w
	mineral += m
	resources_changed.emit()


func can_afford(cost: Dictionary) -> bool:
	return wood >= int(cost.get("wood", 0)) and mineral >= int(cost.get("mineral", 0))


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	wood -= int(cost.get("wood", 0))
	mineral -= int(cost.get("mineral", 0))
	resources_changed.emit()
	return true

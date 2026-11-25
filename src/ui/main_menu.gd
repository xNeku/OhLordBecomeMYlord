extends Control
## Menú principal del prototipo.

@onready var seed_box: SpinBox = $Center/Panel/Box/SeedRow/Seed


func _ready() -> void:
	seed_box.value = GameState.seed_value
	$Center/Panel/Box/Campaign.grab_focus()
	_refresh_filter()


func _refresh_filter() -> void:
	$Center/Panel/Box/Filter.text = "Filtro: %s" % Filters.current_name()


func _on_filter_pressed() -> void:
	Filters.cycle()
	_refresh_filter()


func _on_campaign_pressed() -> void:
	GameState.seed_value = int(seed_box.value)
	GameState.mode = "campaign"
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/world/World.tscn")


func _on_random_seed_pressed() -> void:
	seed_box.value = randi() % 1000000


func _on_benchmark_pressed() -> void:
	GameState.mode = "benchmark"
	get_tree().change_scene_to_file("res://scenes/benchmark/Benchmark.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()

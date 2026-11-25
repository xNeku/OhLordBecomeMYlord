class_name BarracksTab
extends VBoxContainer
## Pestaña Cuartel: desbloquear tropas, mejorar sus stats y subir la capacidad del héroe.

@onready var status: Label = $Status
@onready var rows: Array[UpgradeRow] = [$RowBase, $RowBrute, $RowRanged, $RowSpecial]
@onready var cap_label: Label = $Capacity/Info
@onready var cap_cost: Label = $Capacity/Cost
@onready var cap_button: Button = $Capacity/Action

var eco: Economy


func bind(e: Economy) -> void:
	eco = e
	for r in rows:
		r.action_requested.connect(_on_row_action)
	eco.changed.connect(refresh)
	eco.store.changed.connect(refresh)
	GameState.resources_changed.connect(refresh)
	refresh()


func _on_row_action(arch: String) -> void:
	if eco.store.is_unlocked(arch):
		eco.upgrade_stats(arch)
	else:
		eco.unlock_archetype(arch)


func refresh() -> void:
	if eco == null:
		return
	var ready := eco.barracks_ready()
	status.text = "Cuartel listo: desbloquea y mejora tus tropas." if ready else "Construye el Cuartel de tropas (pestaña Ayuntamiento) para usar estas mejoras."
	var st: Dictionary = eco.upgrades["stats"]
	var db := eco.battle.db
	for r in rows:
		var a := r.archetype
		var unlocked := eco.store.is_unlocked(a)
		var lvl: int = eco.stat_level[a]
		var cost := eco.stat_cost(a) if unlocked else eco.unlock_cost(a)
		r.show_state(db.info(db.unit_id(eco.faction, a))["name"], eco.store.slots_of(a), unlocked, lvl,
			int(st["max_level"]), cost, int(round(float(st["hp_per_level"]) * 100.0 * lvl)), ready)
	var cp: Dictionary = eco.upgrades["capacity"]
	var maxed := eco.capacity_level >= int(cp["max_level"])
	cap_label.text = "Capacidad del héroe: %d huecos  (nivel %d/%d, +%d por nivel)" % [eco.store.capacity, eco.capacity_level, int(cp["max_level"]), int(cp["per_level"])]
	cap_cost.text = "" if maxed else Economy.cost_text(eco.capacity_cost())
	cap_button.disabled = not ready or maxed or not GameState.can_afford(eco.capacity_cost())


func _on_capacity_pressed() -> void:
	eco.upgrade_capacity()

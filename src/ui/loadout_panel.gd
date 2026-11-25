class_name LoadoutPanel
extends PanelContainer
## Menú "qué tropas llevo" (Tab / botón Back del mando). Las tropas son gratis:
## solo repartes la capacidad del héroe entre los arquetipos desbloqueados.

@onready var rows: Array[LoadoutRow] = [$Box/RowBase, $Box/RowBrute, $Box/RowRanged, $Box/RowSpecial]
@onready var footer: Label = $Box/Footer

var store: TroopStore


func bind(s: TroopStore, db: UnitDB, faction: String) -> void:
	store = s
	for i in rows.size():
		var arch: String = s.archetypes[i]
		rows[i].setup(arch, db.info(db.unit_id(faction, arch))["name"])
		rows[i].delta_requested.connect(_on_delta)
	s.changed.connect(_refresh)
	visible = false
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("base_menu"):
		visible = not visible
		if visible:
			rows[0].plus.grab_focus()
		get_viewport().set_input_as_handled()


func _on_delta(arch: String, d: int) -> void:
	store.set_allocation(arch, store.max_of(arch) + d)


func _refresh() -> void:
	if store == null:
		return
	for r in rows:
		r.show_value(store.max_of(r.arch), store.count_of(r.arch), store.is_unlocked(r.arch))
	footer.text = "Capacidad usada %d / %d   ·   el cuartel repone gratis %.0f tropas/s" % [
		store.allocated_total(), store.capacity, store.refill_per_second]


func _on_close_pressed() -> void:
	visible = false

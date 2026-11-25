class_name TroopsTab
extends VBoxContainer
## Pestaña Tropas: eliges cuántas llevas de cada tipo. Cada tipo ocupa sus huecos de capacidad.

@onready var rows: Array[LoadoutRow] = [$RowBase, $RowBrute, $RowRanged, $RowSpecial]
@onready var footer: Label = $Footer

var store: TroopStore


func bind(s: TroopStore, db: UnitDB, faction: String) -> void:
	store = s
	for i in rows.size():
		var arch: String = s.archetypes[i]
		rows[i].setup(arch, "%s (ocupa %d)" % [db.info(db.unit_id(faction, arch))["name"], s.slots_of(arch)])
		rows[i].delta_requested.connect(func(a: String, d: int): store.set_allocation(a, store.max_of(a) + d))
	s.changed.connect(refresh)
	refresh()


func refresh() -> void:
	for r in rows:
		r.show_value(store.max_of(r.arch), store.count_of(r.arch), store.is_unlocked(r.arch))
	footer.text = "Huecos usados %d / %d   ·   Se reponen gratis descansando en tu base (%.0f/s)" % [
		store.used_slots(), store.capacity, store.refill_per_second]

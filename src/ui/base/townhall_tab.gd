class_name TownhallTab
extends VBoxContainer
## Pestaña Ayuntamiento: reparto de trabajadores y construcción.

@onready var workers_label: Label = $Workers
@onready var rates_label: Label = $Rates
@onready var queue_label: Label = $Queue
@onready var split_rows: Array[SplitRow] = [$SplitBuild, $SplitWood, $SplitMining]
@onready var build_rows: Array[BuildRow] = [$BuildHouse, $BuildBarracks, $BuildLumber, $BuildMiners, $BuildBeasts]

var eco: Economy


func bind(e: Economy) -> void:
	eco = e
	for r in split_rows:
		r.value_requested.connect(func(k: String, v: int): eco.set_split(k, v))
	for b in build_rows:
		b.build_requested.connect(func(id: String): eco.order_building(id))
	eco.changed.connect(refresh)
	GameState.resources_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if eco == null or not is_visible_in_tree():
		return
	workers_label.text = "Trabajadores: %d   (cada casa añade %d)" % [eco.workers(), int(eco.params["workers_per_house"])]
	for r in split_rows:
		r.show_value(int(eco.split[r.key]))
	rates_label.text = "Madera +%.1f/s   ·   Mineral +%.1f/s   ·   Obra %.1f trabajo/s" % [eco.wood_per_s(), eco.mineral_per_s(), eco.build_per_s()]
	for b in build_rows:
		var id := b.building_id
		b.show_state(eco.catalog[id], eco.counts[id], eco.queued_of(id), eco.build_block_reason(id))
	if eco.queue.is_empty():
		queue_label.text = "Sin obras en marcha."
	else:
		var q: Dictionary = eco.queue[0]
		var pct := int(100.0 * (1.0 - q["work"] / q["total"]))
		queue_label.text = "En obra: %s %d %%%s%s" % [eco.catalog[q["id"]]["name"], pct,
			("   (+%d en cola)" % (eco.queue.size() - 1)) if eco.queue.size() > 1 else "",
			"   ¡Pon gente a construir!" if eco.split["build"] == 0 else ""]


func _process(_d: float) -> void:
	if eco != null and is_visible_in_tree() and not eco.queue.is_empty():
		refresh()

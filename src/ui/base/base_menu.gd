class_name BaseMenu
extends PanelContainer
## Menú de base (Tab / Back del mando): pestañas Ayuntamiento, Cuartel y Tropas.

@onready var tabs: TabContainer = $Tabs
@onready var townhall: TownhallTab = $Tabs/Ayuntamiento
@onready var barracks: BarracksTab = $Tabs/Cuartel
@onready var troops: TroopsTab = $Tabs/Tropas


func bind(eco: Economy, store: TroopStore, db: UnitDB, faction: String) -> void:
	townhall.bind(eco)
	barracks.bind(eco)
	troops.bind(store, db, faction)
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		townhall.refresh()
		barracks.refresh()
		troops.refresh()
		tabs.get_tab_bar().grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("base_menu"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("cancel"):
		visible = false
		get_viewport().set_input_as_handled()

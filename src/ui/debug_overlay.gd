class_name DebugOverlay
extends CanvasLayer
## Pantalla de depuración (F3): FPS, ms de simulación por paso, unidades.
## Se enlaza con un Battle mediante `bind(battle)`.

@onready var label: Label = $Panel/Label

var battle: Battle
var _timer := 0.0


func bind(b: Battle) -> void:
	battle = b


func _ready() -> void:
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.25 or not visible:
		return
	_timer = 0.0
	var txt := "FPS %d   frame %.1f ms\n" % [Engine.get_frames_per_second(), 1000.0 / maxf(1.0, Engine.get_frames_per_second())]
	if battle != null and battle.sim != null:
		var s := battle.sim
		txt += "Sim: %.1f ms/paso (media)  pico(2s) %.1f ms   presupuesto %.0f ms @%d Hz\n" % [
			battle.avg_step_ms, battle.worst_recent_ms, 1000.0 / BattleSim.STEP_HZ, BattleSim.STEP_HZ]
		txt += "Unidades vivas: %d   (jugador %d, enemigo %d, neutral %d)   huecos %d\n" % [
			s.alive_count, s.team_count[0], s.team_count[1], s.team_count[2], s.high]
	txt += "Draw calls: %d   Objetos: %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_COUNT)]
	label.text = txt

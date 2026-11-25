extends SceneTree
## Captura de pantalla automática para verificar visualmente (requiere ventana: usar xvfb-run).
## godot --path . -s tools/screenshot.gd -- res://scenes/benchmark/Benchmark.tscn /tmp/out.png 120 [seed] [zoom]
var _n := 0
var _frames := 0
var _out := ""

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var scene: PackedScene = load(a[0])
	if a.size() > 3:
		root.get_node("GameState").seed_value = int(a[3])
	_out = a[1]
	_frames = int(a[2])
	var inst := scene.instantiate()
	root.add_child(inst)
	if a.size() > 4:
		var cam: Camera2D = inst.find_child("Camera2D", true, false)
		if cam:
			cam.zoom = Vector2.ONE * float(a[4])

func _process(_d: float) -> bool:
	_n += 1
	if _n == _frames:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("captura guardada ", _out)
		quit()
	return false

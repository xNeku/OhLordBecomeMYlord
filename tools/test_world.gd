extends SceneTree
## Prueba sin ventana del generador: determinismo y alcanzabilidad en muchas semillas.
## godot --headless --path . -s tools/test_world.gd -- 200
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 100
	var params := MapGenerator.load_params()
	var bad := 0
	for s in n:
		var m1 := MapGenerator.generate(s, params)
		var m2 := MapGenerator.generate(s, params)
		if m1.fingerprint() != m2.fingerprint():
			print("NO DETERMINISTA semilla ", s); bad += 1
		var pr := m1.validate()
		if not pr.is_empty():
			print("semilla %d: %s" % [s, "; ".join(pr)]); bad += 1
		if s == 0:
			var kinds := {}
			for e in m1.entities:
				var k := "%s:%s" % [e["kind"], e.get("type", "")]
				kinds[k] = kinds.get(k, 0) + 1
			print("mapa semilla 0: %dx%d celdas (%v px), zonas=%d barreras=%d campamentos=%d" % [m1.w, m1.h, m1.size_px(), m1.zones.size(), m1.barriers.size(), m1.camps.size()])
			print("  entidades: ", kinds)
	print("RESULTADO: %d semillas, %d con problemas" % [n, bad])
	quit(1 if bad > 0 else 0)

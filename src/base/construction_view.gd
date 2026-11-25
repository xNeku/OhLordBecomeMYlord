class_name ConstructionView
extends Node2D
## Dibuja las obras en marcha: andamio discontinuo y barra de progreso, en blanco.

var eco: Economy


func bind(e: Economy) -> void:
	eco = e
	eco.changed.connect(queue_redraw)


func _process(_d: float) -> void:
	if eco != null and not eco.queue.is_empty():
		queue_redraw()


func _draw() -> void:
	if eco == null:
		return
	for k in eco.queue.size():
		var q: Dictionary = eco.queue[k]
		var p: Vector2 = q["pos"]
		var r := Rect2(p - Vector2(13, 16), Vector2(26, 26))
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for i in 4:
			draw_dashed_line(pts[i], pts[i + 1], Color.WHITE, 1.0, 3.0)
		draw_line(r.position, r.end, Color.WHITE, 1.0)  # aspa de andamio
		var prog := 1.0 - float(q["work"]) / float(q["total"])
		if k == 0:
			draw_rect(Rect2(r.position.x, r.end.y + 3, r.size.x, 3), Color.WHITE, false, 1.0)
			draw_rect(Rect2(r.position.x, r.end.y + 3, r.size.x * prog, 3), Color.WHITE)

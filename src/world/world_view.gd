class_name WorldView
extends Node2D
## Dibuja el suelo. Regla de arte: fondo negro puro; solo los bordes de las islas,
## un punteado muy tenue y las barreras van en blanco. Solo lee MapData.

var map: MapData
var style: Dictionary = {"edge_color": "#FFFFFF", "edge_alpha": 0.45, "dot_alpha": 0.10, "dot_every": 4}


func setup(m: MapData, ground_style: Dictionary = {}) -> void:
	map = m
	style.merge(ground_style, true)
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var cs := map.cell
	var base := Color(style["edge_color"])
	var edge := Color(base, float(style["edge_alpha"]))
	var dot := Color(base, float(style["dot_alpha"]))
	var every := int(style["dot_every"])
	for cy in map.h:
		for cx in map.w:
			var i := map.idx(cx, cy)
			if map.zone_id[i] == MapData.VOID:
				continue
			var x := cx * cs
			var y := cy * cs
			# contorno: un lado por cada vecino vacío (las barreras cuentan como vacío)
			if not _ground(cx + 1, cy):
				draw_line(Vector2(x + cs - 0.5, y), Vector2(x + cs - 0.5, y + cs), edge, 1.0)
			if not _ground(cx - 1, cy):
				draw_line(Vector2(x + 0.5, y), Vector2(x + 0.5, y + cs), edge, 1.0)
			if not _ground(cx, cy + 1):
				draw_line(Vector2(x, y + cs - 0.5), Vector2(x + cs, y + cs - 0.5), edge, 1.0)
			if not _ground(cx, cy - 1):
				draw_line(Vector2(x, y + 0.5), Vector2(x + cs, y + 0.5), edge, 1.0)
			# punteado tenue para que se note el movimiento sobre el negro
			if (cx + (cy / every) * 2) % every == 0 and cy % every == 0:
				draw_rect(Rect2(x + cs * 0.5, y + cs * 0.5, 1, 1), dot)
	var font := ThemeDB.fallback_font
	for b in map.barriers:
		var r: Rect2 = b["rect"]
		if b["open"]:
			# puente/paso abierto: tablones blancos
			for c in b["cells"]:
				var bx: float = (int(c) % map.w) * cs
				var by: float = (int(c) / map.w) * cs
				draw_rect(Rect2(bx + 1, by + 2, cs - 2, cs - 4), Color(1, 1, 1, 0.55))
		else:
			# cerrado: contorno discontinuo
			_dashed_rect(r, Color(1, 1, 1, 0.35))
		var label := "%s%s" % [b["name"], " (abierto)" if b["open"] else ""]
		draw_string(font, b["pos"] + Vector2(-80, -r.size.y * 0.5 - 10), label, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 12, Color(1, 1, 1, 0.6))


func _ground(cx: int, cy: int) -> bool:
	return map.in_bounds(cx, cy) and map.zone_id[map.idx(cx, cy)] != MapData.VOID


func _dashed_rect(r: Rect2, col: Color) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for k in 4:
		draw_dashed_line(pts[k], pts[k + 1], col, 1.0, 4.0)

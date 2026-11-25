class_name WorldView
extends Node2D
## Dibuja el suelo con las piezas del director de arte (TerrainAtlas). El suelo se "hornea"
## una vez en texturas por trozos y luego solo se dibujan esas texturas. Encima se pintan las
## barreras (cambian al abrirse). Solo lee MapData.

const WHITE := Color(1, 1, 1, 1)

var map: MapData
var style: Dictionary = {"chunk_px": 512, "star_chance": 0.12, "coast_color": "#5fb7f3"}
var _chunks: Array[Dictionary] = []  ## {tex: ImageTexture, pos: Vector2}
var bake_ms := 0.0


func setup(m: MapData, ground_style: Dictionary = {}) -> void:
	map = m
	style.merge(ground_style, true)
	var t0 := Time.get_ticks_msec()
	_bake()
	bake_ms = Time.get_ticks_msec() - t0
	print("Suelo horneado en %d ms (%d trozos)" % [bake_ms, _chunks.size()])
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _h(cx: int, cy: int) -> int:
	# hash entero barato y estable para elegir variantes
	var v := (cx * 73856093) ^ (cy * 19349663) ^ (map.seed_value * 83492791)
	return absi(v)


func _is_land(cx: int, cy: int) -> bool:
	if not map.in_bounds(cx, cy):
		return false
	var t := map.terrain[map.idx(cx, cy)]
	return t == MapData.T_PLAIN or t == MapData.T_FOREST or t == MapData.T_ROAD or t == MapData.T_MOUNTAIN


static func _stamp(dst: Image, src: Image, at: Vector2i) -> void:
	if src != null:
		dst.blit_rect_mask(src, src, Rect2i(Vector2i.ZERO, src.get_size()), at)


func _bake() -> void:
	var ta := TerrainAtlas.new()
	var cs := int(map.cell)
	var img := Image.create_empty(map.w * cs, map.h * cs, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var star_chance: float = style["star_chance"]
	var coast := Color(style["coast_color"])
	# 1) suelo por celda
	for cy in map.h:
		for cx in map.w:
			var i := map.idx(cx, cy)
			var dst := Vector2i(cx * cs, cy * cs)
			var hv := _h(cx, cy)
			match map.terrain[i]:
				MapData.T_PLAIN, MapData.T_FOREST, MapData.T_MOUNTAIN:
					var z := map.zone_id[i]
					var pat: String = map.zones[z]["pattern"] if z != MapData.VOID else "inicio"
					_stamp(img, ta.pick("ground_" + pat, hv), dst)
				MapData.T_ROAD:
					_stamp(img, ta.pick("road", hv), dst)
				MapData.T_WATER, MapData.T_LAKE:
					_stamp(img, ta.pick("water", 0), dst)
				MapData.T_VOID:
					if float(hv % 1000) / 1000.0 < star_chance:
						_stamp(img, ta.pick("void_star", hv / 7), dst + Vector2i(hv % 10, (hv / 13) % 10))
	# 2) costa: línea continua donde la tierra toca agua o vacío
	for cy in map.h:
		for cx in map.w:
			if not _is_land(cx, cy):
				continue
			var x := cx * cs
			var y := cy * cs
			if not _is_land(cx + 1, cy):
				img.fill_rect(Rect2i(x + cs - 1, y, 1, cs), coast)
			if not _is_land(cx - 1, cy):
				img.fill_rect(Rect2i(x, y, 1, cs), coast)
			if not _is_land(cx, cy + 1):
				img.fill_rect(Rect2i(x, y + cs - 1, cs, 1), coast)
			if not _is_land(cx, cy - 1):
				img.fill_rect(Rect2i(x, y, cs, 1), coast)
	# 3) sellos de relieve, por filas para que lo de abajo tape a lo de arriba
	for cy in map.h:
		for cx in map.w:
			var t := map.terrain[map.idx(cx, cy)]
			var hv2 := _h(cx, cy)
			var base := Vector2i(cx * cs, cy * cs)
			if t == MapData.T_MOUNTAIN:
				var m := ta.pick("mountain", hv2)
				if m != null:
					_stamp(img, m, base + Vector2i((cs - m.get_width()) / 2 + hv2 % 5 - 2, cs - m.get_height() - 2 - (hv2 / 7) % 3))
			elif t == MapData.T_FOREST and hv2 % 3 != 0:
				var tr := ta.pick("forest_tree", hv2 / 3)
				if tr != null:
					_stamp(img, tr, base + Vector2i((hv2 >> 3) % 9, (hv2 >> 7) % 6))
	# 4) trocear en texturas (los móviles no aceptan texturas gigantes)
	var chunk := int(style["chunk_px"])
	_chunks.clear()
	for y0 in range(0, img.get_height(), chunk):
		for x0 in range(0, img.get_width(), chunk):
			var r := Rect2i(x0, y0, mini(chunk, img.get_width() - x0), mini(chunk, img.get_height() - y0))
			var part := img.get_region(r)
			if part.is_invisible():
				continue
			_chunks.append({"tex": ImageTexture.create_from_image(part), "pos": Vector2(x0, y0)})


func _draw() -> void:
	if map == null:
		return
	for c in _chunks:
		draw_texture(c["tex"], c["pos"])
	var cs := map.cell
	var font := ThemeDB.fallback_font
	for b in map.barriers:
		var r: Rect2 = b["rect"]
		if b["open"]:
			# paso abierto: tablones con juntas negras sobre el agua
			for c in b["cells"]:
				var bx: float = (int(c) % map.w) * cs
				var by: float = (int(c) / map.w) * cs
				draw_rect(Rect2(bx, by + 2, cs - 2, cs - 4), Color("#cc8e4c"))
		else:
			_dashed_rect(r)
		var label := "%s%s" % [b["name"], " (abierto)" if b["open"] else ""]
		var lp: Vector2 = b["pos"] + Vector2(-80, -r.size.y * 0.5 - 10)
		draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 12, 4, Color.BLACK)
		draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 12, WHITE)


func _dashed_rect(r: Rect2) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for k in 4:
		draw_dashed_line(pts[k], pts[k + 1], WHITE, 1.0, 4.0)

class_name WorldView
extends Node2D
## Dibuja el suelo. Regla de arte: SOLO blanco y negro puro; el color es para tropas,
## proyectiles y habilidades. Cada terreno se distingue por su trama (ver GroundTiles).
## El suelo se "hornea" una vez en texturas por trozos y luego solo se dibujan esas
## texturas. Encima se pintan las barreras (cambian al abrirse).

const WHITE := Color(1, 1, 1, 1)

var map: MapData
var style: Dictionary = {"chunk_px": 512, "star_chance": 0.12}
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


func _bake() -> void:
	var tiles := GroundTiles.new()
	var cs := int(map.cell)
	var img := GroundTiles._blank(map.w * cs, map.h * cs)
	var full := Rect2i(0, 0, cs, cs)
	var star_chance: float = style["star_chance"]
	# 1) tramas por celda
	for cy in map.h:
		for cx in map.w:
			var i := map.idx(cx, cy)
			var dst := Vector2i(cx * cs, cy * cs)
			var hv := _h(cx, cy)
			match map.terrain[i]:
				MapData.T_PLAIN, MapData.T_FOREST:
					var z := map.zone_id[i]
					var pat: String = map.zones[z]["pattern"] if z != MapData.VOID else "grass"
					img.blit_rect(tiles.plain_tile(pat, hv), full, dst)
				MapData.T_ROAD:
					img.blit_rect(tiles.road[hv % 2], full, dst)
				MapData.T_WATER, MapData.T_LAKE:
					img.blit_rect(tiles.water, full, dst)
				MapData.T_VOID:
					if float(hv % 1000) / 1000.0 < star_chance:
						img.blit_rect(tiles.stars[hv % tiles.stars.size()], full, dst)
	# 2) costa: línea blanca continua donde la tierra toca agua o vacío
	for cy in map.h:
		for cx in map.w:
			if not _is_land(cx, cy):
				continue
			var x := cx * cs
			var y := cy * cs
			if not _is_land(cx + 1, cy):
				img.fill_rect(Rect2i(x + cs - 1, y, 1, cs), WHITE)
			if not _is_land(cx - 1, cy):
				img.fill_rect(Rect2i(x, y, 1, cs), WHITE)
			if not _is_land(cx, cy + 1):
				img.fill_rect(Rect2i(x, y + cs - 1, cs, 1), WHITE)
			if not _is_land(cx, cy - 1):
				img.fill_rect(Rect2i(x, y, cs, 1), WHITE)
	# 3) sellos de relieve, por filas para que lo de abajo tape a lo de arriba
	var peak_r := Rect2i(Vector2i.ZERO, tiles.peak.get_size())
	var tree_r := Rect2i(Vector2i.ZERO, tiles.tree.get_size())
	for cy in map.h:
		for cx in map.w:
			var t := map.terrain[map.idx(cx, cy)]
			var hv2 := _h(cx, cy)
			if t == MapData.T_MOUNTAIN:
				var off := Vector2i(hv2 % 5 - 2, -4 - (hv2 / 7) % 3)
				img.blit_rect_mask(tiles.peak, tiles.peak, peak_r, Vector2i(cx * cs, cy * cs) + off)
			elif t == MapData.T_FOREST:
				for k in (1 if hv2 % 3 != 0 else 0):
					var o2 := Vector2i((hv2 >> (k * 3)) % 9, (hv2 >> (k * 5 + 2)) % 6)
					img.blit_rect_mask(tiles.tree, tiles.tree, tree_r, Vector2i(cx * cs, cy * cs) + o2)
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
			# paso abierto: tablones blancos con juntas negras sobre el agua
			for c in b["cells"]:
				var bx: float = (int(c) % map.w) * cs
				var by: float = (int(c) / map.w) * cs
				draw_rect(Rect2(bx, by + 2, cs - 2, cs - 4), WHITE)
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

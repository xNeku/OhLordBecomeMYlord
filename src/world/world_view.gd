class_name WorldView
extends Node2D
## Dibuja el suelo con las piezas del director de arte (TerrainAtlas), con autotiles de 4 vecinos. El suelo se "hornea"
## una vez en texturas por trozos y luego solo se dibujan esas texturas. Encima se pintan las
## barreras (cambian al abrirse). Solo lee MapData.

const WHITE := Color(1, 1, 1, 1)

var map: MapData
var style: Dictionary = {"chunk_px": 512, "star_chance": 0.12, "coast_color": "#3a6f9a"}
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


## Clase de autotile de una celda: piezas que "se unen" con vecinos de la misma clase.
const C_NONE := 0
const C_WATER := 1
const C_MOUNTAIN := 2
const C_ROAD := 3
const C_FOREST := 4


func _cls(cx: int, cy: int) -> int:
	if not map.in_bounds(cx, cy):
		return C_NONE
	match map.terrain[map.idx(cx, cy)]:
		MapData.T_WATER, MapData.T_LAKE, MapData.T_RIVER:
			return C_WATER
		MapData.T_BRIDGE:
			return C_WATER  # bajo el puente hay río (el puente se dibuja encima al repararlo)
		MapData.T_MOUNTAIN:
			return C_MOUNTAIN
		MapData.T_ROAD:
			return C_ROAD
		MapData.T_FOREST:
			return C_FOREST
	return C_NONE


## Máscara de 4 vecinos: N=1, E=2, S=4, O=8 (lados con vecino de la misma clase).
func _mask(cx: int, cy: int, c: int) -> int:
	var m := 0
	if _cls(cx, cy - 1) == c or (c == C_ROAD and _is_bridge(cx, cy - 1)): m |= 1
	if _cls(cx + 1, cy) == c or (c == C_ROAD and _is_bridge(cx + 1, cy)): m |= 2
	if _cls(cx, cy + 1) == c or (c == C_ROAD and _is_bridge(cx, cy + 1)): m |= 4
	if _cls(cx - 1, cy) == c or (c == C_ROAD and _is_bridge(cx - 1, cy)): m |= 8
	return m


## Tierra = zona asignada y no agua (el río y los puentes no cuentan como tierra).
func _land(cx: int, cy: int) -> bool:
	if not map.in_bounds(cx, cy):
		return false
	var i := map.idx(cx, cy)
	return map.zone_id[i] != MapData.VOID and _cls(cx, cy) != C_WATER


func _is_bridge(cx: int, cy: int) -> bool:
	return map.in_bounds(cx, cy) and map.terrain[map.idx(cx, cy)] == MapData.T_BRIDGE


static func _stamp(dst: Image, src: Image, at: Vector2i) -> void:
	if src != null:
		dst.blit_rect_mask(src, src, Rect2i(Vector2i.ZERO, src.get_size()), at)


var _bridge_h: ImageTexture
var _bridge_v: ImageTexture


func _bake() -> void:
	var ta := TerrainAtlas.new()
	_bridge_h = ImageTexture.create_from_image(ta.pick("bridge_h", 0))
	_bridge_v = ImageTexture.create_from_image(ta.pick("bridge_v", 0))
	var cs := int(map.cell)
	var img := Image.create_empty(map.w * cs, map.h * cs, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var star_chance: float = style["star_chance"]
	for cy in map.h:
		for cx in map.w:
			var i := map.idx(cx, cy)
			var dst := Vector2i(cx * cs, cy * cs)
			var hv := _h(cx, cy)
			var t := map.terrain[i]
			var z := map.zone_id[i]
			# suelo NEGRO (Neku): el bioma de la región se nota en montañas y árboles
			var biome: String = str(map.zones[z]["pattern"]) if z != MapData.VOID else "inicio"
			match _cls(cx, cy):
				C_WATER:
					_stamp(img, ta.pick("river_%d" % _mask(cx, cy, C_WATER), 0), dst)
				C_MOUNTAIN:
					if map.ore[i] == 1:
						_stamp(img, ta.pick("mountain_ore_" + biome, hv), dst)
					else:
						_stamp(img, ta.pick("mountain_wall_%s_%d" % [biome, _mask(cx, cy, C_MOUNTAIN)], 0), dst)
				C_ROAD:
					_stamp(img, ta.pick("road_%d" % _mask(cx, cy, C_ROAD), 0), dst)
				C_FOREST:
					if _mask(cx, cy, C_FOREST) == 15:
						_stamp(img, ta.pick("forest_fill_" + biome, hv), dst)
					else:
						var tr := ta.pick("forest_tree_" + biome, hv)
						if tr != null:
							_stamp(img, tr, dst + Vector2i((cs - tr.get_width()) / 2, (cs - tr.get_height()) / 2))
				_:
					if t == MapData.T_VOID and float(hv % 1000) / 1000.0 < star_chance:
						_stamp(img, ta.pick("void_star", hv / 7), dst + Vector2i(hv % 10, (hv / 13) % 10))
	# costa: línea donde la tierra toca agua o vacío
	var coast := Color(style["coast_color"])
	for cy in map.h:
		for cx in map.w:
			if not _land(cx, cy):
				continue
			var x := cx * cs
			var y := cy * cs
			if not _land(cx + 1, cy): img.fill_rect(Rect2i(x + cs - 1, y, 1, cs), coast)
			if not _land(cx - 1, cy): img.fill_rect(Rect2i(x, y, 1, cs), coast)
			if not _land(cx, cy + 1): img.fill_rect(Rect2i(x, y + cs - 1, cs, 1), coast)
			if not _land(cx, cy - 1): img.fill_rect(Rect2i(x, y, cs, 1), coast)
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
				var bcx: int = int(c) % map.w
				var bcy: int = int(c) / map.w
				var pos := Vector2(bcx, bcy) * cs
				if map.terrain[int(c)] == MapData.T_BRIDGE:
					var horiz := _cls(bcx - 1, bcy) != C_WATER or _cls(bcx + 1, bcy) != C_WATER or _is_bridge(bcx - 1, bcy) or _is_bridge(bcx + 1, bcy)
					draw_texture(_bridge_h if horiz else _bridge_v, pos)
				else:
					draw_rect(Rect2(pos.x, pos.y + 2, cs - 2, cs - 4), Color("#cc8e4c"))  # pasarela del barco
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

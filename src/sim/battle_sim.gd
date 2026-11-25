class_name BattleSim
extends RefCounted
## Simulación de combate masivo. NO conoce nodos ni escenas: se puede ejecutar sin ventana.
##
## - Una unidad (o estructura) es un índice en arrays empaquetados, nunca un nodo.
## - Paso fijo (STEP_HZ). El dibujado interpola entre (prev_x,prev_y) y (px,py).
## - Vecinos con SpatialGrid propia. Sin físicas de Godot.
## - Cada unidad reevalúa objetivo cada RETARGET_INTERVAL pasos, escalonado por índice.

signal structure_destroyed(type_id: String, team: int, pos: Vector2, tag: int)

const STEP_HZ := 20
const STEP_DT := 1.0 / STEP_HZ
const RETARGET_INTERVAL := 4
const FLASH_TIME := 0.12
const STRUCT_BIAS := 48.0  ## las estructuras "parecen" más lejos: se prefieren unidades como objetivo
const MAX_SEP_NEIGHBORS := 8
const MAX_CELL_SCAN := 24  ## máx. unidades revisadas por celda al buscar objetivo
const DEATH_STRIDE := 5
const SHOT_STRIDE := 5

var db: UnitDB
var grid := SpatialGrid.new()

var capacity := 0
var high := 0  ## marca de agua: índices >= high nunca se han usado
var alive_count := 0
var tick := 0
var next_uid := 1

# --- datos por unidad (estructura de arrays) ---
var px := PackedFloat32Array()
var py := PackedFloat32Array()
var prev_x := PackedFloat32Array()
var prev_y := PackedFloat32Array()
var hp := PackedFloat32Array()
var cd := PackedFloat32Array()
var flash := PackedFloat32Array()
var type := PackedInt32Array()
var team := PackedByteArray()
var alive := PackedByteArray()
var seek := PackedByteArray()
var zone := PackedByteArray()
var target := PackedInt32Array()
var target_uid := PackedInt32Array()
var uid := PackedInt32Array()
var tag := PackedInt32Array()  ## dato libre para la lógica del juego (id de campamento, etc.)

var free_list := PackedInt32Array()
var dead_queue := PackedInt32Array()
var struct_list := PackedInt32Array()
var structs_dirty := true
var team_rep := PackedInt32Array([-1, -1, -1, -1])
var team_count := PackedInt32Array([0, 0, 0, 0])

## Eventos de muerte para el dibujado: x, y, fila_fx (-1 = sin partícula), escala, es_estructura
var death_events := PackedFloat32Array()
## Disparos para el dibujado: x0, y0, x1, y1, tipo_que_dispara (el daño ya se aplicó; es solo visual)
var shot_events := PackedFloat32Array()

# --- mapa de celdas caminables (opcional) ---
var walk := PackedByteArray()
var walk_w := 0
var walk_h := 0
var walk_inv := 1.0

# variables de trabajo de la búsqueda (evitan asignaciones en el bucle caliente)
var _best := -1
var _best_d := 0.0
var _sep_x := 0.0
var _sep_y := 0.0


func setup(unit_db: UnitDB, world_w: float, world_h: float, initial_capacity: int = 4096) -> void:
	db = unit_db
	grid.setup(world_w, world_h, 32.0)
	capacity = 0
	_resize(initial_capacity)


func set_walk_grid(cells: PackedByteArray, w: int, h: int, cell_px: float) -> void:
	walk = cells
	walk_w = w
	walk_h = h
	walk_inv = 1.0 / cell_px


func _resize(new_cap: int) -> void:
	px.resize(new_cap); py.resize(new_cap); prev_x.resize(new_cap); prev_y.resize(new_cap)
	hp.resize(new_cap); cd.resize(new_cap); flash.resize(new_cap)
	type.resize(new_cap); team.resize(new_cap); alive.resize(new_cap); seek.resize(new_cap)
	zone.resize(new_cap); target.resize(new_cap); target_uid.resize(new_cap); uid.resize(new_cap)
	tag.resize(new_cap)
	capacity = new_cap


func clear_all() -> void:
	alive.fill(0)
	high = 0
	alive_count = 0
	free_list.clear()
	dead_queue.clear()
	death_events.clear()
	shot_events.clear()
	team_count.fill(0)
	structs_dirty = true


func spawn(type_id: String, team_id: int, x: float, y: float, do_seek: bool = false, tag_value: int = -1, zone_id: int = 0) -> int:
	return spawn_t(db.index_of[type_id], team_id, x, y, do_seek, tag_value, zone_id)


func spawn_t(t: int, team_id: int, x: float, y: float, do_seek: bool = false, tag_value: int = -1, zone_id: int = 0) -> int:
	var i: int
	if free_list.size() > 0:
		i = free_list[free_list.size() - 1]
		free_list.resize(free_list.size() - 1)
	else:
		if high >= capacity:
			_resize(capacity * 2)
		i = high
		high += 1
	px[i] = x; py[i] = y; prev_x[i] = x; prev_y[i] = y
	hp[i] = db.hp[t]
	cd[i] = randf() * db.cooldown[t]
	flash[i] = 0.0
	type[i] = t
	team[i] = team_id
	alive[i] = 1
	seek[i] = 1 if do_seek else 0
	zone[i] = zone_id
	target[i] = -1
	target_uid[i] = 0
	uid[i] = next_uid
	next_uid += 1
	tag[i] = tag_value
	alive_count += 1
	team_count[team_id] += 1
	if db.is_structure[t] == 1:
		structs_dirty = true
	return i


func drain_shot_events() -> PackedFloat32Array:
	var out := shot_events
	shot_events = PackedFloat32Array()
	return out


func drain_death_events() -> PackedFloat32Array:
	var out := death_events
	death_events = PackedFloat32Array()
	return out


# ============================ PASO DE SIMULACIÓN ============================

func step(dt: float = STEP_DT) -> void:
	tick += 1
	grid.rebuild(px, py, alive, high)
	if structs_dirty:
		_rebuild_struct_list()
	team_rep.fill(-1)

	for i in high:
		if alive[i] == 0:
			continue
		team_rep[team[i]] = i
		var t := type[i]
		var spd := db.speed[t]
		var dmg := db.damage[t]
		if flash[i] > 0.0:
			flash[i] -= dt
		if spd == 0.0 and dmg == 0.0:
			continue
		prev_x[i] = px[i]
		prev_y[i] = py[i]
		cd[i] -= dt

		# ---- objetivo ----
		var tg := target[i]
		var need := false
		if tg < 0:
			need = (tick + i) % RETARGET_INTERVAL == 0
		elif alive[tg] == 0 or uid[tg] != target_uid[i]:
			tg = -1
			need = true
		else:
			# con objetivo válido se reevalúa menos: más rara vez aún si ya está trabado en combate
			need = (tick + i) % (RETARGET_INTERVAL * 2) == 0
		if need:
			var ng := _acquire(i, t)
			if ng >= 0:
				tg = ng
			elif tg < 0 and seek[i] == 1:
				tg = _seek_goal(i)
			if tg >= 0:
				target[i] = tg
				target_uid[i] = uid[tg]
			else:
				target[i] = -1
		if tg < 0:
			continue

		# ---- actuar sobre el objetivo ----
		var tt := type[tg]
		var dx := px[tg] - px[i]
		var dy := py[tg] - py[i]
		var d := sqrt(dx * dx + dy * dy)
		var reach := db.attack_range[t] + db.radius[t] + db.radius[tt]
		if d <= reach:
			if dmg > 0.0 and cd[i] <= 0.0:
				cd[i] = db.cooldown[t]
				if db.is_suicide[t] == 1:
					_splash(px[tg], py[tg], db.splash[t], dmg, int(team[i]))
					_hit(i, 1.0e9)
				else:
					if db.splash[t] > 0.0:
						_splash(px[tg], py[tg], db.splash[t], dmg, int(team[i]))  # mago: daño en área
					else:
						_hit(tg, dmg)
					if db.projectile_row[t] >= 0:
						shot_events.append(px[i]); shot_events.append(py[i])
						shot_events.append(px[tg]); shot_events.append(py[tg])
						shot_events.append(float(t))
		elif spd > 0.0 and d > 0.001:
			var stp := spd * dt
			var room := d - reach
			if stp > room:
				stp = room
			var nx := px[i] + dx / d * stp
			var ny := py[i] + dy / d * stp
			_move_to(i, nx, ny)

		# ---- separación (cada 2 pasos por unidad, con vecinos acotados) ----
		if spd > 0.0 and ((tick + i) & 1) == 0:
			_separation(i, db.radius[t])
			if _sep_x != 0.0 or _sep_y != 0.0:
				_move_to(i, px[i] + _sep_x, py[i] + _sep_y)

	# ---- procesar muertes (los huecos se liberan al final del paso) ----
	for k in dead_queue.size():
		var j := dead_queue[k]
		var tj := type[j]
		alive_count -= 1
		team_count[team[j]] -= 1
		death_events.append(px[j]); death_events.append(py[j])
		death_events.append(float(db.fx_row[tj])); death_events.append(db.draw_scale[tj])
		death_events.append(float(db.is_structure[tj]))
		if db.is_structure[tj] == 1:
			structs_dirty = true
			structure_destroyed.emit(db.ids[tj], int(team[j]), Vector2(px[j], py[j]), tag[j])
		free_list.append(j)
	dead_queue.clear()


func _hit(j: int, amount: float) -> void:
	if alive[j] == 0:
		return
	hp[j] -= amount
	flash[j] = FLASH_TIME
	if hp[j] <= 0.0:
		alive[j] = 0
		dead_queue.append(j)


func _move_to(i: int, nx: float, ny: float) -> void:
	if walk_w == 0:
		px[i] = nx
		py[i] = ny
		return
	if _walkable(nx, ny):
		px[i] = nx
		py[i] = ny
	elif _walkable(nx, py[i]):
		px[i] = nx
	elif _walkable(px[i], ny):
		py[i] = ny


func _walkable(x: float, y: float) -> bool:
	if x < 0.0 or y < 0.0:
		return false
	var cx := int(x * walk_inv)
	var cy := int(y * walk_inv)
	if cx >= walk_w or cy >= walk_h:
		return false
	return walk[cy * walk_w + cx] != 0


func _rebuild_struct_list() -> void:
	struct_list.clear()
	for i in high:
		if alive[i] == 1 and db.is_structure[type[i]] == 1:
			struct_list.append(i)
	structs_dirty = false


## Objetivo lejano cuando no hay nadie al alcance: estructura hostil más cercana de la
## misma zona; si no hay, una unidad cualquiera de un bando hostil (modo "dos ejércitos").
func _seek_goal(i: int) -> int:
	var mask := db.hostile_mask[team[i]]
	var best := -1
	var best_d := 1.0e20
	var ix := px[i]
	var iy := py[i]
	var z := zone[i]
	for k in struct_list.size():
		var j := struct_list[k]
		if alive[j] == 0 or ((mask >> team[j]) & 1) == 0 or zone[j] != z:
			continue
		var dx := px[j] - ix
		var dy := py[j] - iy
		var d := dx * dx + dy * dy
		if d < best_d:
			best_d = d
			best = j
	if best >= 0:
		return best
	for tm in 4:
		if ((mask >> tm) & 1) == 1 and team_rep[tm] >= 0 and zone[team_rep[tm]] == z:
			return team_rep[tm]
	return -1


func _acquire(i: int, t: int) -> int:
	var r_px := db.aggro[t]
	if r_px <= 0.0:
		return -1
	var cols := grid.cols
	var rows := grid.rows
	var cx := clampi(int(px[i] * grid.inv), 0, cols - 1)
	var cy := clampi(int(py[i] * grid.inv), 0, rows - 1)
	var maxr := int(ceil(r_px * grid.inv))
	var mask := db.hostile_mask[team[i]]
	_best = -1
	_best_d = r_px * r_px
	var found_r := -1
	for r in maxr + 1:
		if found_r >= 0:  # se corta al terminar el anillo donde se encontró algo (aproximación)
			break
		var y0 := cy - r
		var y1 := cy + r
		var x0 := cx - r
		var x1 := cx + r
		var xa := maxi(x0, 0)
		var xb := mini(x1, cols - 1)
		for yy in range(maxi(y0, 0), mini(y1, rows - 1) + 1):
			var base := yy * cols
			if yy == y0 or yy == y1:
				for xx in range(xa, xb + 1):
					var c := base + xx
					if grid.cell_start[c + 1] != grid.cell_start[c]:
						_scan_cell(c, i, mask)
			else:
				if x0 >= 0 and grid.cell_start[base + x0 + 1] != grid.cell_start[base + x0]:
					_scan_cell(base + x0, i, mask)
				if x1 < cols and grid.cell_start[base + x1 + 1] != grid.cell_start[base + x1]:
					_scan_cell(base + x1, i, mask)
		if found_r < 0 and _best >= 0:
			found_r = r
	return _best


func _scan_cell(c: int, i: int, mask: int) -> void:
	var ix := px[i]
	var iy := py[i]
	var k0 := grid.cell_start[c]
	var cnt := grid.cell_start[c + 1] - k0
	var off := 0
	if cnt > MAX_CELL_SCAN:
		# celda muy densa: se revisa solo una ventana rotatoria (aproximación barata del "más cercano")
		off = (tick * 7 + i) % cnt
		cnt = MAX_CELL_SCAN
	var total := grid.cell_start[c + 1] - k0
	for n in cnt:
		var k := k0 + (off + n) % total
		var j := grid.items[k]
		if j == i or alive[j] == 0 or ((mask >> team[j]) & 1) == 0:
			continue
		var dx := px[j] - ix
		var dy := py[j] - iy
		var d := dx * dx + dy * dy
		var tj := type[j]
		if db.is_structure[tj] == 1:
			var e := maxf(sqrt(d) - db.radius[tj], 0.0) + STRUCT_BIAS
			d = e * e
		if d < _best_d:
			_best_d = d
			_best = j


func _separation(i: int, ri: float) -> void:
	_sep_x = 0.0
	_sep_y = 0.0
	var cols := grid.cols
	var rows := grid.rows
	var cx := clampi(int(px[i] * grid.inv), 0, cols - 1)
	var cy := clampi(int(py[i] * grid.inv), 0, rows - 1)
	var ix := px[i]
	var iy := py[i]
	var checked := 0
	for yy in range(maxi(cy - 1, 0), mini(cy + 1, rows - 1) + 1):
		for xx in range(maxi(cx - 1, 0), mini(cx + 1, cols - 1) + 1):
			var c := yy * cols + xx
			for k in range(grid.cell_start[c], grid.cell_start[c + 1]):
				var j := grid.items[k]
				if j == i or alive[j] == 0:
					continue
				var tj := type[j]
				if db.is_structure[tj] == 1:
					continue
				var dx := ix - px[j]
				var dy := iy - py[j]
				var md := ri + db.radius[tj]
				var d2 := dx * dx + dy * dy
				if d2 < md * md:
					var d := sqrt(d2)
					if d < 0.001:
						dx = randf() - 0.5
						dy = randf() - 0.5
						d = 0.5
					var push := (md - d) * 0.6 / d
					_sep_x += dx * push
					_sep_y += dy * push
				checked += 1
				if checked >= MAX_SEP_NEIGHBORS:
					return


func _splash(x: float, y: float, r: float, dmg: float, src_team: int) -> void:
	var mask := db.hostile_mask[src_team]
	var cols := grid.cols
	var rows := grid.rows
	var rc := int(ceil(r * grid.inv)) + 1
	var cx := clampi(int(x * grid.inv), 0, cols - 1)
	var cy := clampi(int(y * grid.inv), 0, rows - 1)
	var r2 := r * r
	for yy in range(maxi(cy - rc, 0), mini(cy + rc, rows - 1) + 1):
		for xx in range(maxi(cx - rc, 0), mini(cx + rc, cols - 1) + 1):
			var c := yy * cols + xx
			for k in range(grid.cell_start[c], grid.cell_start[c + 1]):
				var j := grid.items[k]
				if alive[j] == 0 or ((mask >> team[j]) & 1) == 0:
					continue
				var dx := px[j] - x
				var dy := py[j] - y
				var rad := db.radius[type[j]] if db.is_structure[type[j]] == 1 else 0.0
				var dd := maxf(sqrt(dx * dx + dy * dy) - rad, 0.0)
				if dd * dd <= r2:
					_hit(j, dmg)

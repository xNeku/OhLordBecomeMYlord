class_name SimRenderer
extends Node2D
## Dibuja una BattleSim con un MultiMesh por atlas. No contiene lógica de juego.
## Interpola entre el paso anterior y el actual con `alpha` (0..1).
## La rejilla (columnas x filas) de cada atlas se lee de los manifests de arte, así que
## añadir filas al atlas no obliga a tocar escenas.

const FX_MAX := 2048
const FX_LIFE := 0.30
const SHOT_MAX := 4096
const SHOT_SPEED := 340.0  ## px/s del proyectil visual
## Desplazamiento vertical de dibujo por atlas (para que "apoyen" en su posición)
const Y_OFFSET := {UnitDB.ATLAS_FOOT: -2.0, UnitDB.ATLAS_MOUNTED: -5.0, UnitDB.ATLAS_BEAST: -2.0, UnitDB.ATLAS_STRUCTURE: -4.0}

@onready var structures: SpriteBatch = $Structures
@onready var units: SpriteBatch = $Units
@onready var beasts: SpriteBatch = $Beasts
@onready var mounted: SpriteBatch = $Mounted
@onready var fx: SpriteBatch = $Fx
@onready var shots: SpriteBatch = $Projectiles

var sim: BattleSim
var alpha := 0.0
var _time := 0.0
var _facing := PackedByteArray()
var _batches: Array[SpriteBatch] = []
var _fx := PackedFloat32Array()   # x, y, fila, escala, edad
var _fx_n := 0
var _shots := PackedFloat32Array()  # x0, y0, x1, y1, tipo, edad, duración
var _shot_n := 0


func bind(s: BattleSim) -> void:
	sim = s
	_fx.resize(FX_MAX * 5)
	_shots.resize(SHOT_MAX * 7)
	_batches = [units, mounted, beasts, structures]  # indexado por UnitDB.ATLAS_*
	var art: Dictionary = sim.db._art
	_set_grid(units, art["units_foot"]["grid"])
	_set_grid(mounted, art["units_mounted"]["grid"])
	_set_grid(beasts, art["beasts"]["grid"])
	var pm := UnitDB._json("res://assets/atlas/projectiles_manifest.json")
	_set_grid(shots, pm["grid"])


static func _set_grid(b: SpriteBatch, grid: Array) -> void:
	(b.material as ShaderMaterial).set_shader_parameter("grid", Vector2(grid[0], grid[1]))


func _process(delta: float) -> void:
	if sim == null:
		return
	_time += delta
	_drain_deaths()
	_drain_shots()
	_draw_units()
	_draw_fx(delta)
	_draw_shots(delta)


func _draw_units() -> void:
	var n := sim.high
	if _facing.size() < n:
		_facing.resize(n + (n >> 1) + 64)
		_facing.fill(1)
	for b in _batches:
		b.reserve(n)
	var db := sim.db
	var anim := int(_time * 6.0)
	var a := alpha
	for i in n:
		if sim.alive[i] == 0:
			continue
		var t := sim.type[i]
		var at := db.atlas[t]
		var x := floorf(sim.prev_x[i] + (sim.px[i] - sim.prev_x[i]) * a + 0.5)
		var y := floorf(sim.prev_y[i] + (sim.py[i] - sim.prev_y[i]) * a + 0.5)
		var f := clampf(sim.flash[i] / BattleSim.FLASH_TIME, 0.0, 1.0)
		var sc := db.draw_scale[t]
		if at != UnitDB.ATLAS_STRUCTURE:
			var dx := sim.px[i] - sim.prev_x[i]
			if dx > 0.02:
				_facing[i] = 1
			elif dx < -0.02:
				_facing[i] = 0
			if _facing[i] == 0:
				sc = -sc
		_batches[at].put(x, y + Y_OFFSET[at], sc, float((anim + i) & 1), float(db.sprite_row[t]), f, db.tint[t])
	for b in _batches:
		b.commit()


func _drain_deaths() -> void:
	var ev := sim.drain_death_events()
	var k := 0
	while k + BattleSim.DEATH_STRIDE <= ev.size():
		if ev[k + 4] < 0.5 and ev[k + 2] >= 0.0 and _fx_n < FX_MAX:
			var o := _fx_n * 5
			for q in 4:
				_fx[o + q] = ev[k + q]
			_fx[o + 4] = 0.0
			_fx_n += 1
		k += BattleSim.DEATH_STRIDE


func _draw_fx(delta: float) -> void:
	fx.reserve(_fx_n)
	var i := 0
	while i < _fx_n:
		var o := i * 5
		_fx[o + 4] += delta
		var age := _fx[o + 4]
		if age >= FX_LIFE:
			var last := (_fx_n - 1) * 5
			for q in 5:
				_fx[o + q] = _fx[last + q]
			_fx_n -= 1
			continue
		var p := age / FX_LIFE
		fx.put(_fx[o], _fx[o + 1] - 2.0, _fx[o + 3] * (1.0 + p * 0.6), 0.0, _fx[o + 2], 1.0, Color(1, 1, 1, 1.0 - p))
		i += 1
	fx.commit()


func _drain_shots() -> void:
	var ev := sim.drain_shot_events()
	var k := 0
	while k + BattleSim.SHOT_STRIDE <= ev.size():
		if _shot_n < SHOT_MAX:
			var o := _shot_n * 7
			for q in 5:
				_shots[o + q] = ev[k + q]
			var dist := Vector2(ev[k + 2] - ev[k], ev[k + 3] - ev[k + 1]).length()
			_shots[o + 5] = 0.0
			_shots[o + 6] = clampf(dist / SHOT_SPEED, 0.06, 0.45)
			_shot_n += 1
		k += BattleSim.SHOT_STRIDE


func _draw_shots(delta: float) -> void:
	shots.reserve(_shot_n)
	var db := sim.db
	var anim := int(_time * 10.0)
	var i := 0
	while i < _shot_n:
		var o := i * 7
		_shots[o + 5] += delta
		var p := _shots[o + 5] / _shots[o + 6]
		if p >= 1.0:
			var last := (_shot_n - 1) * 7
			for q in 7:
				_shots[o + q] = _shots[last + q]
			_shot_n -= 1
			continue
		var t := int(_shots[o + 4])
		var x := lerpf(_shots[o], _shots[o + 2], p)
		var y := lerpf(_shots[o + 1], _shots[o + 3], p) - 4.0 - sin(p * PI) * 10.0  # pequeño arco
		var sc := 1.0 if _shots[o + 2] >= _shots[o] else -1.0
		shots.put(floorf(x + 0.5), floorf(y + 0.5), sc, float((anim + i) & 1), float(db.projectile_row[t]), 0.0, db.projectile_tint[t])
		i += 1
	shots.commit()

class_name SimRenderer
extends Node2D
## Dibuja una BattleSim con MultiMesh. No contiene lógica de juego.
## Interpola entre el paso anterior y el actual con `alpha` (0..1).

const FX_MAX := 2048
const FX_LIFE := 0.30

@onready var structures: SpriteBatch = $Structures
@onready var units: SpriteBatch = $Units
@onready var fx: SpriteBatch = $Fx

var sim: BattleSim
var alpha := 0.0
var _time := 0.0
var _facing := PackedByteArray()
# partículas de muerte (x, y, fila, escala, edad)
var _fx := PackedFloat32Array()
var _fx_n := 0


func bind(s: BattleSim) -> void:
	sim = s
	_fx.resize(FX_MAX * 5)


func _process(delta: float) -> void:
	if sim == null:
		return
	_time += delta
	_drain_deaths()
	_draw_units(delta)
	_draw_fx(delta)


func _draw_units(_delta: float) -> void:
	var n := sim.high
	if _facing.size() < n:
		_facing.resize(n + (n >> 1) + 64)
		_facing.fill(1)
	units.reserve(n)
	structures.reserve(n)
	var db := sim.db
	var anim := int(_time * 6.0)
	var a := alpha
	for i in n:
		if sim.alive[i] == 0:
			continue
		var t := sim.type[i]
		var x := sim.prev_x[i] + (sim.px[i] - sim.prev_x[i]) * a
		var y := sim.prev_y[i] + (sim.py[i] - sim.prev_y[i]) * a
		x = floorf(x + 0.5)
		y = floorf(y + 0.5)
		var f := minf(sim.flash[i] / BattleSim.FLASH_TIME, 1.0)
		if f < 0.0:
			f = 0.0
		if db.is_structure[t] == 1:
			structures.put(x, y - 4.0, db.draw_scale[t], float((anim + i) & 1), float(db.sprite_row[t]), f, db.tint[t])
		else:
			var dx := sim.px[i] - sim.prev_x[i]
			if dx > 0.02:
				_facing[i] = 1
			elif dx < -0.02:
				_facing[i] = 0
			var sc := db.draw_scale[t]
			if _facing[i] == 0:
				sc = -sc
			units.put(x, y - 2.0, sc, float((anim + i) & 1), float(db.sprite_row[t]), f, db.tint[t])
	units.commit()
	structures.commit()


func _drain_deaths() -> void:
	var ev := sim.drain_death_events()
	var k := 0
	while k + BattleSim.DEATH_STRIDE <= ev.size():
		if ev[k + 4] < 0.5 and _fx_n < FX_MAX:  # solo unidades (las estructuras no dejan partícula)
			var o := _fx_n * 5
			_fx[o] = ev[k]
			_fx[o + 1] = ev[k + 1]
			_fx[o + 2] = ev[k + 2]
			_fx[o + 3] = ev[k + 3]
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
			# intercambia con el último y no avanza
			var last := (_fx_n - 1) * 5
			for q in 5:
				_fx[o + q] = _fx[last + q]
			_fx_n -= 1
			continue
		var p := age / FX_LIFE
		var sc := _fx[o + 3] * (1.0 + p * 0.6)
		fx.put(_fx[o], _fx[o + 1] - 2.0, sc, 0.0, _fx[o + 2], 1.0, Color(1, 1, 1, 1.0 - p))
		i += 1
	fx.commit()

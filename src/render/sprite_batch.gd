class_name SpriteBatch
extends MultiMeshInstance2D
## Lote de sprites dibujado con un único MultiMesh (nunca un Sprite2D por unidad).
## Uso por frame:  reserve(n_max) -> put(...) varias veces -> commit()

@export var chunk: int = 1024  ## la capacidad crece en bloques de este tamaño

const STRIDE := 16  # transform 2D (8) + color (4) + datos custom (4)

var buf := PackedFloat32Array()
var count := 0
var _capacity := 0


func reserve(n_max: int) -> void:
	count = 0
	var need := (n_max / chunk + 1) * chunk
	if need > _capacity:
		_capacity = need
		multimesh.instance_count = need
		buf.resize(need * STRIDE)
		buf.fill(0.0)


func put(x: float, y: float, sc: float, col: float, row: float, flash: float, tint: Color) -> void:
	var o := count * STRIDE
	buf[o] = sc
	buf[o + 1] = 0.0
	buf[o + 2] = 0.0
	buf[o + 3] = x
	buf[o + 4] = 0.0
	buf[o + 5] = absf(sc)
	buf[o + 6] = 0.0
	buf[o + 7] = y
	buf[o + 8] = tint.r
	buf[o + 9] = tint.g
	buf[o + 10] = tint.b
	buf[o + 11] = tint.a
	buf[o + 12] = col
	buf[o + 13] = row
	buf[o + 14] = flash
	count += 1


func commit() -> void:
	multimesh.visible_instance_count = count
	if count > 0:
		multimesh.buffer = buf

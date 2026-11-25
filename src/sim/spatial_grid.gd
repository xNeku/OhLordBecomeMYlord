class_name SpatialGrid
extends RefCounted
## Cuadrícula espacial propia (counting sort). Se reconstruye cada paso.
## Sin Area2D ni físicas: solo arrays.

var cell_size: float = 32.0
var inv: float = 1.0 / 32.0
var cols: int = 1
var rows: int = 1
var cell_start := PackedInt32Array()  ## tamaño celdas+1; items de la celda c = items[cell_start[c] .. cell_start[c+1])
var cursor := PackedInt32Array()
var items := PackedInt32Array()
var cell_of := PackedInt32Array()


func setup(world_w: float, world_h: float, cs: float = 32.0) -> void:
	cell_size = cs
	inv = 1.0 / cs
	cols = maxi(1, int(ceil(world_w * inv)))
	rows = maxi(1, int(ceil(world_h * inv)))
	cell_start.resize(cols * rows + 1)
	cursor.resize(cols * rows)


func rebuild(px: PackedFloat32Array, py: PackedFloat32Array, alive: PackedByteArray, high: int) -> void:
	if cell_of.size() < high:
		cell_of.resize(high + (high >> 1) + 64)
	if items.size() < high:
		items.resize(high + (high >> 1) + 64)
	cell_start.fill(0)
	var maxc := cols - 1
	var maxr := rows - 1
	for i in high:
		if alive[i] == 0:
			cell_of[i] = -1
			continue
		var cx := int(px[i] * inv)
		var cy := int(py[i] * inv)
		if cx < 0: cx = 0
		elif cx > maxc: cx = maxc
		if cy < 0: cy = 0
		elif cy > maxr: cy = maxr
		var c := cy * cols + cx
		cell_of[i] = c
		cell_start[c + 1] += 1
	var ncells := cols * rows
	for c in ncells:
		cell_start[c + 1] += cell_start[c]
		cursor[c] = cell_start[c]
	for i in high:
		var c2 := cell_of[i]
		if c2 < 0:
			continue
		items[cursor[c2]] = i
		cursor[c2] += 1

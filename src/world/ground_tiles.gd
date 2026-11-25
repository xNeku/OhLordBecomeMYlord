class_name GroundTiles
extends RefCounted
## Tramas en blanco y negro puro para el suelo (una baldosa por celda de 16 px) y sellos
## para montañas y árboles. Cada terreno se distingue SOLO por su trama, nunca por color.
## Formato LA8: blanco opaco o transparente (el fondo de la escena es negro).

const S := 16
const ON := Color(1, 1, 1, 1)

var plain: Dictionary = {}   ## nombre_trama -> Array[Image] (variantes)
var water: Image
var road: Array[Image] = []
var stars: Array[Image] = []
var peak: Image             ## sello de montaña 16x16
var tree: Image             ## sello de árbol 8x10


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242  # las tramas son fijas: no dependen de la semilla del mapa
	for pname in ["grass", "dunes", "ash"]:
		var vs: Array[Image] = []
		for v in 4:
			vs.append(_plain_tile(pname, rng))
		plain[pname] = vs
	water = _blank(S, S)
	for y in S:
		for x in S:
			if (x - y + 64) % 16 == 0 or ((x - y + 72) % 16 == 0 and (x / 4) % 2 == 0):  # rayado diagonal (con olas discontinuas)
				water.set_pixel(x, y, ON)
	for v in 2:
		var r := _blank(S, S)
		for y in range(2, S - 2):
			for x in range(2, S - 2):
				if (x + v) % 3 == 0 and (y + v) % 3 == 0:
					r.set_pixel(x, y, ON)
		road.append(r)
	for v in 6:
		var st := _blank(S, S)
		if v < 4:
			var p := Vector2i(rng.randi_range(1, S - 2), rng.randi_range(1, S - 2))
			st.set_pixel(p.x, p.y, ON)
			if v == 0:  # estrella grande en cruz
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					st.set_pixel(p.x + d.x, p.y + d.y, ON)
		stars.append(st)
	peak = _make_peak()
	tree = _make_tree()


func plain_tile(pattern: String, variant: int) -> Image:
	var vs: Array = plain.get(pattern, plain["grass"])
	return vs[variant % vs.size()]


static func _blank(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_LA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _plain_tile(pname: String, rng: RandomNumberGenerator) -> Image:
	var img := _blank(S, S)
	match pname:
		"grass":  # matojos: dos píxeles en vertical, uno o dos por celda
			for k in rng.randi_range(1, 2):
				var x := rng.randi_range(1, S - 2)
				var y := rng.randi_range(2, S - 2)
				img.set_pixel(x, y, ON)
				img.set_pixel(x, y - 1, ON)
				if rng.randf() < 0.5:
					img.set_pixel(x + 1, y, ON)
		"dunes":  # ondas de arena: guion horizontal
			var x2 := rng.randi_range(1, S - 5)
			var y2 := rng.randi_range(1, S - 2)
			for d in 3:
				img.set_pixel(x2 + d, y2, ON)
			img.set_pixel(x2 + 3, y2 - 1, ON)
		"ash":  # ceniza: puntos sueltos
			for k in 3:
				img.set_pixel(rng.randi_range(0, S - 1), rng.randi_range(0, S - 1), ON)
	return img


func _make_peak() -> Image:
	# triángulo: cara izquierda blanca maciza, cara derecha en rayas (sombra en blanco y negro)
	var img := _blank(S, S)
	for y in range(1, S):
		var half := int((y - 1) * 7.0 / (S - 2))
		for x in range(7 - half, 8 + half):
			if x <= 7 or y % 2 == 0:
				img.set_pixel(x, y, ON)
	return img


func _make_tree() -> Image:
	var img := _blank(8, 10)
	for y in 7:
		for x in 8:
			if Vector2(x - 3.5, y - 3.2).length() <= 3.4:
				img.set_pixel(x, y, ON)
	img.set_pixel(2, 3, Color(0, 0, 0, 1))  # hueco negro para que no sea un borrón
	for y in range(7, 10):
		img.set_pixel(3, y, ON)
		img.set_pixel(4, y, ON)
	return img

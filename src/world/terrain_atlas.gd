class_name TerrainAtlas
extends RefCounted
## Piezas de terreno del director de arte: assets/atlas/terrain.png + terrain_manifest.json
## {nombre: [x, y, w, h]}. Agrupa las variantes por prefijo: "ground_inicio_3" -> grupo "ground_inicio".

const PNG := "res://assets/atlas/terrain.png"
const MANIFEST := "res://assets/atlas/terrain_manifest.json"

var groups: Dictionary = {}  ## prefijo -> Array[Image]
var exact: Dictionary = {}   ## nombre exacto -> Image (p.ej. "river_5" de los autotiles)


func _init() -> void:
	var tex: Texture2D = load(PNG)
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var f := FileAccess.open(MANIFEST, FileAccess.READ)
	var man: Dictionary = JSON.parse_string(f.get_as_text())
	var names: Array = man["piezas"].keys()
	names.sort()  # orden estable de variantes
	for name: String in names:
		var r: Array = man["piezas"][name]
		var piece := img.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		exact[name] = piece
		var prefix: String = name
		var us: int = name.rfind("_")
		if us > 0 and name.substr(us + 1).is_valid_int():
			prefix = name.substr(0, us)
		if not groups.has(prefix):
			groups[prefix] = []
		groups[prefix].append(piece)


## Pieza por nombre exacto si existe; si no, variante `v` del grupo con ese prefijo; o null.
func pick(prefix: String, v: int) -> Image:
	if exact.has(prefix):
		return exact[prefix]
	var g: Array = groups.get(prefix, [])
	if g.is_empty():
		return null
	return g[v % g.size()]

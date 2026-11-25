class_name TroopStore
extends Node
## Tropas que lleva el héroe. Diseño (Neku, 25-11-2026):
##  - Las tropas NO cuestan recursos.
##  - Hay una capacidad total (`capacity`) que se sube con mejoras.
##  - El jugador elige cuántas lleva de cada tipo (`allocation`, suma <= capacity).
##  - El cuartel repone gratis hasta lo elegido (`refill_per_second` tropas/s en total).
##  - Solo se pueden llevar arquetipos desbloqueados (`unlocked`).

signal changed

var archetypes: Array = []
var unlocked: Array = []
var capacity := 0
var allocation: Dictionary = {}
var counts: Dictionary = {}
var refill_per_second := 6.0
var _acc := 0.0
var _rr := 0  ## reparto por turnos al reponer


func configure(hero_data: Dictionary) -> void:
	var t: Dictionary = hero_data["troops"]
	archetypes = hero_data["archetypes"]
	unlocked = t["unlocked"]
	capacity = int(t["capacity"])
	refill_per_second = float(t["refill_per_second"])
	for a in archetypes:
		allocation[a] = 0
		counts[a] = 0
	for a in archetypes:
		set_allocation(a, int(t["allocation"].get(a, 0)))
	for a in archetypes:
		counts[a] = allocation[a]  # se empieza con el reparto lleno
	changed.emit()


func is_unlocked(arch: String) -> bool:
	return unlocked.has(arch)


func allocated_total() -> int:
	var s := 0
	for a in archetypes:
		s += int(allocation[a])
	return s


func total() -> int:
	var s := 0
	for a in archetypes:
		s += int(counts[a])
	return s


func count_of(arch: String) -> int:
	return counts.get(arch, 0)


func max_of(arch: String) -> int:
	return allocation.get(arch, 0)


## Cambia cuántas tropas de un tipo quieres llevar. Devuelve el valor aplicado.
func set_allocation(arch: String, n: int) -> int:
	if not is_unlocked(arch):
		n = 0
	var others := allocated_total() - int(allocation[arch])
	n = clampi(n, 0, capacity - others)
	allocation[arch] = n
	if counts[arch] > n:
		counts[arch] = n
	changed.emit()
	return n


func set_capacity(n: int) -> void:
	capacity = maxi(n, 0)
	# si baja la capacidad, se recorta empezando por el último arquetipo
	var over := allocated_total() - capacity
	for k in range(archetypes.size() - 1, -1, -1):
		if over <= 0:
			break
		var a: String = archetypes[k]
		var cut := mini(over, int(allocation[a]))
		set_allocation(a, int(allocation[a]) - cut)
		over -= cut
	changed.emit()


func take(arch: String, n: int) -> int:
	var k := mini(n, counts.get(arch, 0))
	if k > 0:
		counts[arch] -= k
		changed.emit()
	return k


func _process(delta: float) -> void:
	if archetypes.is_empty() or total() >= allocated_total():
		_acc = 0.0
		return
	_acc += refill_per_second * delta
	var dirty := false
	var guard := 0
	while _acc >= 1.0 and guard < archetypes.size() * 4:
		guard += 1
		var a: String = archetypes[_rr % archetypes.size()]
		_rr += 1
		if counts[a] < allocation[a]:
			counts[a] += 1
			_acc -= 1.0
			dirty = true
	if dirty:
		changed.emit()

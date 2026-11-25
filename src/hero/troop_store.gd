class_name TroopStore
extends Node
## Tropas que lleva el héroe. Diseño (Neku, 25-11-2026):
##  - Las tropas NO cuestan recursos.
##  - El héroe tiene una capacidad en huecos; cada tipo de tropa ocupa X huecos (`slots`).
##  - El jugador elige cuántas lleva de cada tipo (`allocation`).
##  - Se reponen SOLO en la base, tras un descanso (`rest_delay_s`), gratis.
##  - Solo se llevan arquetipos desbloqueados (se desbloquean en el cuartel).

signal changed
signal resting_changed(resting: bool)

var archetypes: Array = []
var unlocked: Array = []
var capacity := 0
var slots: Dictionary = {}       ## arquetipo -> huecos que ocupa cada tropa
var allocation: Dictionary = {}
var counts: Dictionary = {}
var refill_per_second := 8.0
var refill_radius := 140.0
var rest_delay := 2.0
var at_base := false
var resting := false             ## true mientras se están reponiendo tropas
var _rest_t := 0.0
var _acc := 0.0
var _rr := 0


func configure(hero_data: Dictionary, slot_of: Dictionary) -> void:
	var t: Dictionary = hero_data["troops"]
	archetypes = hero_data["archetypes"]
	unlocked = t["unlocked"].duplicate()
	capacity = int(t["capacity"])
	refill_per_second = float(t["refill_per_second"])
	refill_radius = float(t["refill_radius_px"])
	rest_delay = float(t["rest_delay_s"])
	for a in archetypes:
		slots[a] = int(slot_of.get(a, 1))
		allocation[a] = 0
		counts[a] = 0
	for a in archetypes:
		set_allocation(a, int(t["allocation"].get(a, 0)))
	for a in archetypes:
		counts[a] = allocation[a]  # se empieza con el reparto lleno
	changed.emit()


func is_unlocked(arch: String) -> bool:
	return unlocked.has(arch)


func unlock(arch: String) -> void:
	if not unlocked.has(arch):
		unlocked.append(arch)
		changed.emit()


func used_slots() -> int:
	var s := 0
	for a in archetypes:
		s += int(allocation[a]) * int(slots[a])
	return s


func carried_slots() -> int:
	var s := 0
	for a in archetypes:
		s += int(counts[a]) * int(slots[a])
	return s


func total() -> int:
	var s := 0
	for a in archetypes:
		s += int(counts[a])
	return s


func allocated_total() -> int:
	var s := 0
	for a in archetypes:
		s += int(allocation[a])
	return s


func count_of(arch: String) -> int:
	return counts.get(arch, 0)


func max_of(arch: String) -> int:
	return allocation.get(arch, 0)


func slots_of(arch: String) -> int:
	return slots.get(arch, 1)


## Cambia cuántas tropas de un tipo quieres llevar (limitado por los huecos libres). Devuelve el valor aplicado.
func set_allocation(arch: String, n: int) -> int:
	if not is_unlocked(arch):
		n = 0
	var others := used_slots() - int(allocation[arch]) * int(slots[arch])
	var max_n := (capacity - others) / int(slots[arch])
	n = clampi(n, 0, maxi(max_n, 0))
	allocation[arch] = n
	if counts[arch] > n:
		counts[arch] = n
	changed.emit()
	return n


func set_capacity(n: int) -> void:
	capacity = maxi(n, 0)
	var k := archetypes.size() - 1
	while used_slots() > capacity and k >= 0:
		var a: String = archetypes[k]
		if int(allocation[a]) > 0:
			allocation[a] = int(allocation[a]) - 1
			counts[a] = mini(int(counts[a]), int(allocation[a]))
		else:
			k -= 1
	changed.emit()


func take(arch: String, n: int) -> int:
	var k := mini(n, counts.get(arch, 0))
	if k > 0:
		counts[arch] -= k
		changed.emit()
	return k


func _process(delta: float) -> void:
	var want_rest := at_base and total() < allocated_total()
	if not want_rest:
		_rest_t = 0.0
		_acc = 0.0
		_set_resting(false)
		return
	_rest_t += delta
	if _rest_t < rest_delay:
		return
	_set_resting(true)
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


func _set_resting(on: bool) -> void:
	if on != resting:
		resting = on
		resting_changed.emit(on)

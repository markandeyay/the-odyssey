class_name PlayerHealth
extends Node
## Hearts (M6, ARCHITECTURE §7). Nau starts with 3 heart containers. Cairns
## yield heart pieces, 4 pieces make a container; 8 Cairns on Lanka = exactly
## 2 containers, so Nau leaves with 5 hearts. Amounts everywhere are in
## hearts (food heals in quarters: 0.25 .. 2.0). Damage-over-time sources
## pass fractional hearts per tick. Reaching zero emits `died` here and
## `player_died` on the EventBus; the SaveSystem answers with a hard reset
## to the last autosave.

signal health_changed(current_hearts: float, max_hearts: int)
signal heart_pieces_changed(containers: int, pieces: int)
signal died()

const START_CONTAINERS: int = 3
const PIECES_PER_CONTAINER: int = 4

var containers: int = START_CONTAINERS
var pieces: int = 0
var current_hearts: float = float(START_CONTAINERS)
var is_dead: bool = false


func max_hearts() -> int:
	return containers


## Damage in hearts. Sources: &"fire", &"heat", &"fall", &"drowning",
## &"drowned", &"hot_surface". The source tag is for feedback (M12 UI,
## audio), not for rules — all damage is equal.
func apply_damage(hearts: float, _source: StringName = &"") -> void:
	if is_dead or hearts <= 0.0:
		return
	current_hearts = maxf(0.0, current_hearts - hearts)
	health_changed.emit(current_hearts, containers)
	if current_hearts <= 0.0:
		is_dead = true
		died.emit()
		EventBus.player_died.emit()


func heal(hearts: float) -> void:
	if is_dead or hearts <= 0.0:
		return
	current_hearts = minf(float(containers), current_hearts + hearts)
	health_changed.emit(current_hearts, containers)


## One piece per Cairn (ARCHITECTURE §13). A completed container refills
## the hearts — the reward should never feel like a tease.
func add_heart_piece() -> void:
	pieces += 1
	if pieces >= PIECES_PER_CONTAINER:
		pieces -= PIECES_PER_CONTAINER
		containers += 1
		refill()
	heart_pieces_changed.emit(containers, pieces)


func refill() -> void:
	is_dead = false
	current_hearts = float(containers)
	health_changed.emit(current_hearts, containers)


func get_save_data() -> Dictionary:
	return {
		"containers": containers,
		"pieces": pieces,
		"current": current_hearts,
	}


func apply_save_data(data: Dictionary) -> void:
	containers = maxi(1, int(data.get("containers", START_CONTAINERS)))
	pieces = clampi(int(data.get("pieces", 0)), 0, PIECES_PER_CONTAINER - 1)
	current_hearts = clampf(float(data.get("current", containers)), 0.0, float(containers))
	is_dead = false
	if current_hearts <= 0.0:
		# A save can never legitimately hold a dead Nau; loading revives.
		current_hearts = float(containers)
	health_changed.emit(current_hearts, containers)
	heart_pieces_changed.emit(containers, pieces)

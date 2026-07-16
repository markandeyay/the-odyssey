class_name FireGrid
extends Node3D
## Cell-based fire (M7), the island's most important system and its
## biggest perf risk. One per level; WORLD instances the prefab and never
## opens it. Flammable components register their cells here; the grid owns
## spread, fuel drain, char, damage, updrafts, dousing, and the hard caps.
##
## Spread is deterministic heat accumulation, not randomness: every
## `spread_interval` each burning cell heats its 26 neighbors, faster
## upward, slower downward; a neighbor ignites when its accumulated heat
## reaches `ignition_time`. No physics queries anywhere in the loop —
## everything is dictionary lookups keyed by Vector3i cells, so cost
## scales with `max_burning_cells`, which is a hard cap, not a budget.
## `step()` is public and drives everything, so tests advance fire
## deterministically without wall-clock time.

const GROUP: StringName = &"fire_grid"

@export_group("Grid")
@export var cell_size: float = 1.0

@export_group("Spread")
## Seconds between spread ticks.
@export var spread_interval: float = 0.5
## Seconds of adjacent burning needed to ignite a neighbor cell.
@export var ignition_time: float = 3.0
## Fire spreads faster upward (M7). Applied to heating rate.
@export var upward_multiplier: float = 2.5
@export var downward_multiplier: float = 0.4
## Heat lost per second by cells no longer being heated.
@export var heat_decay: float = 1.0

@export_group("Hard caps")
## Simultaneously burning cells. A hard cap, not a budget (M7).
@export var max_burning_cells: int = 64
## Live pooled particle emitters (each carries one light).
@export var max_fire_emitters: int = 16
@export var max_updrafts: int = 4

@export_group("Damage")
@export var damage_interval: float = 0.25
## Hearts per second on contact with a burning cell.
@export var contact_damage_per_second: float = 0.5
@export var contact_radius: float = 1.2
## Hearts per second of radiated ambient heat near a burning cell.
@export var radiant_damage_per_second: float = 0.2
@export var radiant_radius: float = 3.0

@export_group("Updrafts")
## Burning cells a cluster needs before it vents an updraft.
@export var updraft_min_cells: int = 6
@export var updraft_interval: float = 1.0
@export var updraft_height: float = 12.0
@export var updraft_extra_radius: float = 1.0

static var NEIGHBOR_OFFSETS: Array[Vector3i] = _make_neighbor_offsets()

var _cells: Dictionary = {}      # Vector3i -> Flammable (ignition targets)
var _burning: Dictionary = {}    # Vector3i -> Flammable (active sources)
var _heat: Dictionary = {}       # Vector3i -> float accumulated heat
var _flammables: Array[Flammable] = []
var _emitters_by_cell: Dictionary = {}   # Vector3i -> CPUParticles3D
var _free_emitters: Array[CPUParticles3D] = []
var _emitter_count: int = 0
var _updrafts: Array[UpdraftVolume] = []
var _spread_accum: float = 0.0
var _damage_accum: float = 0.0
var _updraft_accum: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	step(delta)


## The whole simulation. Public so tests drive fire deterministically.
func step(delta: float) -> void:
	_update_mobile()
	_drain_fuel(delta)
	_spread_accum += delta
	while _spread_accum >= spread_interval:
		_spread_accum -= spread_interval
		_spread_tick(spread_interval)
		_refresh_emitters()
	_damage_accum += delta
	if _damage_accum >= damage_interval:
		_damage_tick(_damage_accum)
		_damage_accum = 0.0
	_updraft_accum += delta
	if _updraft_accum >= updraft_interval:
		_updraft_accum = 0.0
		_refresh_updrafts()


func world_to_cell(position: Vector3) -> Vector3i:
	return Vector3i((position / cell_size).floor())


func cell_center(cell: Vector3i) -> Vector3:
	return (Vector3(cell) + Vector3.ONE * 0.5) * cell_size


func burning_cell_count() -> int:
	return _burning.size()


func live_emitter_count() -> int:
	return _emitters_by_cell.size()


func active_updraft_count() -> int:
	var count: int = 0
	for updraft: UpdraftVolume in _updrafts:
		if updraft.is_active():
			count += 1
	return count


func is_burning_at(position: Vector3) -> bool:
	return _burning.has(world_to_cell(position))


## Lights the occupied cell at `position`, if any. Respects the hard cap,
## char, and dousing. Campfires (M10) and level scripting call this.
func ignite_at(position: Vector3) -> bool:
	var cell: Vector3i = world_to_cell(position)
	return _try_ignite(cell, _cells.get(cell) as Flammable)


func ignite_flammable(flammable: Flammable) -> bool:
	var preferred: Vector3i = world_to_cell(flammable.body.global_position + flammable.center_offset)
	if flammable.cells.has(preferred):
		return _try_ignite(preferred, flammable)
	if not flammable.cells.is_empty():
		return _try_ignite(flammable.cells[0], flammable)
	return false


## Extinguishes every flammable with a burning cell inside the radius and
## marks it doused (blocks re-ignition while wet). Cools heated cells too.
## Water (M8) calls this; fire dies in water and under a doused surface.
func douse_area(position: Vector3, radius: float) -> void:
	var radius_sq: float = radius * radius
	var hit: Array[Flammable] = []
	for cell: Vector3i in _burning:
		if cell_center(cell).distance_squared_to(position) <= radius_sq:
			var flammable: Flammable = _burning[cell]
			if not hit.has(flammable):
				hit.append(flammable)
	for flammable: Flammable in hit:
		for cell: Vector3i in flammable.burning_cells:
			_burning.erase(cell)
		flammable.on_extinguished(true)
	for cell: Vector3i in _heat.keys():
		if cell_center(cell).distance_squared_to(position) <= radius_sq:
			_heat.erase(cell)


## Extinguishes one whole flammable and marks it doused. Water volumes
## (M8) call this for burning bodies they swallow.
func douse_flammable(flammable: Flammable) -> void:
	if not flammable.is_burning():
		return
	for cell: Vector3i in flammable.burning_cells:
		_burning.erase(cell)
	flammable.on_extinguished(true)


func register_flammable(flammable: Flammable) -> void:
	if _flammables.has(flammable):
		return
	_flammables.append(flammable)
	flammable.cells = []
	if flammable.mobile:
		var base: Vector3i = world_to_cell(flammable.body.global_position)
		_claim(base, flammable)
		flammable.last_base_cell = base
		return
	var center: Vector3 = flammable.body.global_position + flammable.center_offset
	var half: Vector3 = flammable.size * 0.5 - Vector3.ONE * 0.001
	half = half.max(Vector3.ZERO)
	var lo: Vector3i = world_to_cell(center - half)
	var hi: Vector3i = world_to_cell(center + half)
	for x: int in range(lo.x, hi.x + 1):
		for y: int in range(lo.y, hi.y + 1):
			for z: int in range(lo.z, hi.z + 1):
				_claim(Vector3i(x, y, z), flammable)


func unregister_flammable(flammable: Flammable) -> void:
	_flammables.erase(flammable)
	for cell: Vector3i in flammable.cells:
		if _cells.get(cell) == flammable:
			_cells.erase(cell)
		_heat.erase(cell)
	for cell: Vector3i in flammable.burning_cells:
		_burning.erase(cell)
	flammable.cells = []
	flammable.burning_cells.clear()


func _claim(cell: Vector3i, flammable: Flammable) -> void:
	if _cells.has(cell):
		return
	_cells[cell] = flammable
	flammable.cells.append(cell)


func _try_ignite(cell: Vector3i, flammable: Flammable) -> bool:
	if flammable == null:
		return false
	if _burning.size() >= max_burning_cells:
		return false
	if flammable.is_charred() or flammable.is_doused():
		return false
	if _burning.has(cell) or flammable.burning_cells.has(cell):
		return false
	_burning[cell] = flammable
	_heat.erase(cell)
	flammable.on_cell_ignited(cell)
	return true


func _spread_tick(dt: float) -> void:
	var heated: Dictionary = {}
	for cell: Vector3i in _burning.keys():
		for offset: Vector3i in NEIGHBOR_OFFSETS:
			var neighbor: Vector3i = cell + offset
			if _burning.has(neighbor):
				continue
			var target: Flammable = _cells.get(neighbor) as Flammable
			if target == null or target.is_charred() or target.is_doused():
				continue
			var multiplier: float = 1.0
			if offset.y > 0:
				multiplier = upward_multiplier
			elif offset.y < 0:
				multiplier = downward_multiplier
			var heat: float = _heat.get(neighbor, 0.0) + dt * multiplier
			_heat[neighbor] = heat
			heated[neighbor] = true
			if heat >= ignition_time:
				_try_ignite(neighbor, target)
	for cell: Vector3i in _heat.keys():
		if heated.has(cell):
			continue
		var cooled: float = _heat[cell] - dt * heat_decay
		if cooled <= 0.0:
			_heat.erase(cell)
		else:
			_heat[cell] = cooled


func _drain_fuel(delta: float) -> void:
	for flammable: Flammable in _flammables:
		if flammable.is_burning():
			flammable.fuel -= maxi(1, flammable.burning_cells.size()) * delta
			if flammable.fuel <= 0.0:
				for cell: Vector3i in flammable.burning_cells:
					_burning.erase(cell)
				flammable.on_charred()
		elif flammable.doused_timer > 0.0:
			flammable.doused_timer = maxf(0.0, flammable.doused_timer - delta)


func _update_mobile() -> void:
	for flammable: Flammable in _flammables:
		if not flammable.mobile:
			continue
		var base: Vector3i = world_to_cell(flammable.body.global_position)
		if base == flammable.last_base_cell:
			continue
		var was_burning: bool = flammable.is_burning()
		for cell: Vector3i in flammable.cells:
			if _cells.get(cell) == flammable:
				_cells.erase(cell)
		for cell: Vector3i in flammable.burning_cells:
			_burning.erase(cell)
		flammable.cells = []
		flammable.burning_cells.clear()
		_claim(base, flammable)
		flammable.last_base_cell = base
		if was_burning:
			_burning[base] = flammable
			flammable.burning_cells[base] = true


## Fire damages on contact and radiates ambient heat (M7). Nearest burning
## cell decides; effects do not stack across cells, so a bonfire is not an
## instant kill.
func _damage_tick(dt: float) -> void:
	if _burning.is_empty():
		return
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	var target: Vector3 = player.global_position + Vector3.UP * 0.9
	var nearest_sq: float = INF
	for cell: Vector3i in _burning:
		var flammable: Flammable = _burning[cell]
		if not flammable.contact_damage:
			continue
		nearest_sq = minf(nearest_sq, cell_center(cell).distance_squared_to(target))
	if nearest_sq <= contact_radius * contact_radius:
		player.apply_damage(contact_damage_per_second * dt, &"fire")
	elif nearest_sq <= radiant_radius * radiant_radius:
		player.apply_damage(radiant_damage_per_second * dt, &"heat")


func _refresh_emitters() -> void:
	for cell: Vector3i in _emitters_by_cell.keys():
		if _burning.has(cell):
			continue
		var emitter: CPUParticles3D = _emitters_by_cell[cell]
		emitter.emitting = false
		emitter.visible = false
		_free_emitters.append(emitter)
		_emitters_by_cell.erase(cell)
	for cell: Vector3i in _burning:
		if _emitters_by_cell.size() >= max_fire_emitters:
			break
		if _emitters_by_cell.has(cell):
			continue
		if not (_burning[cell] as Flammable).pooled_vfx:
			continue
		var emitter: CPUParticles3D = _take_emitter()
		if emitter == null:
			break
		emitter.global_position = cell_center(cell)
		emitter.emitting = true
		emitter.visible = true
		_emitters_by_cell[cell] = emitter


func _take_emitter() -> CPUParticles3D:
	if not _free_emitters.is_empty():
		return _free_emitters.pop_back()
	if _emitter_count >= max_fire_emitters:
		return null
	_emitter_count += 1
	return _make_emitter()


func _make_emitter() -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.amount = 16
	particles.lifetime = 0.7
	particles.emitting = false
	particles.visible = false
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	particles.mesh = mesh
	particles.direction = Vector3.UP
	particles.spread = 25.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.2
	particles.gravity = Vector3(0.0, 2.5, 0.0)
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.0
	particles.color = Color(1.0, 0.45, 0.08)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.omni_range = 5.0
	light.light_energy = 1.4
	light.position = Vector3.UP * 0.4
	particles.add_child(light)
	add_child(particles)
	return particles


## An updraft vents above every burning cluster big enough (M7). Clusters
## are 26-connected components of burning cells.
func _refresh_updrafts() -> void:
	var used: int = 0
	for cluster: Array in _burning_clusters():
		if cluster.size() < updraft_min_cells or used >= max_updrafts:
			continue
		var lo: Vector3 = cell_center(cluster[0])
		var hi: Vector3 = lo
		for cell: Vector3i in cluster:
			var center: Vector3 = cell_center(cell)
			lo = lo.min(center)
			hi = hi.max(center)
		var radius: float = maxf(hi.x - lo.x, hi.z - lo.z) * 0.5 + cell_size * 0.5 + updraft_extra_radius
		var base_y: float = hi.y + cell_size * 0.5
		var center_pos: Vector3 = Vector3((lo.x + hi.x) * 0.5, base_y + updraft_height * 0.5, (lo.z + hi.z) * 0.5)
		_updraft(used).configure(center_pos, radius, updraft_height)
		used += 1
	for i: int in range(used, _updrafts.size()):
		_updrafts[i].deactivate()


func _updraft(index: int) -> UpdraftVolume:
	while _updrafts.size() <= index:
		var volume: UpdraftVolume = UpdraftVolume.new()
		add_child(volume)
		_updrafts.append(volume)
	return _updrafts[index]


func _burning_clusters() -> Array:
	var visited: Dictionary = {}
	var clusters: Array = []
	for cell: Vector3i in _burning:
		if visited.has(cell):
			continue
		visited[cell] = true
		var cluster: Array[Vector3i] = []
		var stack: Array[Vector3i] = [cell]
		while not stack.is_empty():
			var current: Vector3i = stack.pop_back()
			cluster.append(current)
			for offset: Vector3i in NEIGHBOR_OFFSETS:
				var neighbor: Vector3i = current + offset
				if _burning.has(neighbor) and not visited.has(neighbor):
					visited[neighbor] = true
					stack.append(neighbor)
		clusters.append(cluster)
	return clusters


static func _make_neighbor_offsets() -> Array[Vector3i]:
	var offsets: Array[Vector3i] = []
	for x: int in [-1, 0, 1]:
		for y: int in [-1, 0, 1]:
			for z: int in [-1, 0, 1]:
				if x == 0 and y == 0 and z == 0:
					continue
				offsets.append(Vector3i(x, y, z))
	return offsets

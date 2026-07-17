class_name GliderController
extends Node
## The glider (M13): a scrap of Setu's sail found in the Ember Quarter.
## A fall-management tool and the payoff for making a big fire — not a
## flight game (ARCHITECTURE §14). It caps descent and rides updrafts,
## limited by updraft availability and height, nothing else. No stamina
## cost, because there is no stamina. Gated on carrying the sailcloth key
## item; cannot glide while carrying (M4/M13). Child of Player; the player
## toggles it and calls airborne_step while in the air.

signal deployed()
signal stowed(reason: StringName)

const GLIDER_ITEM_ID: StringName = &"glider"

## Terminal descent while deployed. Well below the fall damage threshold:
## a glide landing never hurts.
@export var glide_fall_speed: float = 2.5
## Horizontal drift while deployed — a nudge over run speed, not flight.
@export var glide_speed: float = 6.5
## Steering response in the air while deployed.
@export var glide_acceleration: float = 6.0
## How quickly vertical speed approaches its target: the flare on deploy,
## the surge on entering an updraft.
@export var vertical_response: float = 4.0

var active: bool = false

@onready var _player: Player = get_parent() as Player
@onready var _updraft_sensor: Area3D = _player.get_node("UpdraftSensor") as Area3D


func can_deploy() -> bool:
	if active or not Inventory.has_key_item(GLIDER_ITEM_ID):
		return false
	if _player.is_on_floor() or _player.is_carrying:
		return false
	return not _player.is_climbing() and not _player.is_swimming()


func try_deploy() -> bool:
	if not can_deploy():
		return false
	active = true
	deployed.emit()
	return true


## No-op when not deployed.
func stow(reason: StringName = &"stowed") -> void:
	if not active:
		return
	active = false
	stowed.emit(reason)


## Called by the player every airborne physics frame. While deployed this
## replaces gravity: descent is capped, and overlapping updrafts lift.
func airborne_step(delta: float) -> void:
	if not active:
		return
	if _player.is_carrying:
		stow(&"carrying")
		return
	var lift: float = strongest_lift()
	var target: float = lift if lift > 0.0 else -glide_fall_speed
	_player.velocity.y = lerpf(_player.velocity.y, target, 1.0 - exp(-vertical_response * delta))


## The strongest updraft overlapping the sensor right now. Zero when clear
## of every updraft — including above a volume's top, which is how height
## limits the ride.
func strongest_lift() -> float:
	var lift: float = 0.0
	for area: Area3D in _updraft_sensor.get_overlapping_areas():
		var updraft: UpdraftVolume = area as UpdraftVolume
		if updraft != null:
			lift = maxf(lift, updraft.lift_strength)
	return lift

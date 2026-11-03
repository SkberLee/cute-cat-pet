# scripts/pet_stats.gd
class_name PetStats
extends Node

signal stats_changed

@export var mood: float = 70.0
@export var hunger: float = 30.0
@export var bond: float = 10.0

const HUNGER_PER_SEC := 0.4
const MOOD_DECAY_PER_SEC := 0.15

func _clamp_all() -> void:
	mood = clampf(mood, 0.0, 100.0)
	hunger = clampf(hunger, 0.0, 100.0)
	bond = clampf(bond, 0.0, 100.0)

func pet() -> void:
	mood += 8.0
	bond += 3.0
	_clamp_all()
	stats_changed.emit()

func feed() -> void:
	hunger -= 25.0
	mood += 4.0
	_clamp_all()
	stats_changed.emit()

func play() -> void:
	mood += 10.0
	bond += 5.0
	hunger += 5.0
	_clamp_all()
	stats_changed.emit()

func tick(delta: float) -> void:
	hunger += HUNGER_PER_SEC * delta
	mood -= MOOD_DECAY_PER_SEC * delta
	_clamp_all()
	stats_changed.emit()

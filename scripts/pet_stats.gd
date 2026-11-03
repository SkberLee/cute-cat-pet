# scripts/pet_stats.gd
class_name PetStats
extends Node

signal stats_changed
signal milestone_unlocked(threshold: int, title: String)

@export var mood: float = 70.0
@export var hunger: float = 30.0
@export var bond: float = 10.0

## Bond thresholds that unlock sweeter lines / cosmetics.
const MILESTONES := [25, 50, 75, 100]
const MILESTONE_TITLES := {
	25: "小猫开始黏你了",
	50: "成为心肝宝贝",
	75: "房间都为你变好看",
	100: "永远的小搭档",
}

var unlocked_milestones: Array = []

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
	_check_milestones()
	stats_changed.emit()

func feed() -> void:
	hunger -= 25.0
	mood += 4.0
	_clamp_all()
	_check_milestones()
	stats_changed.emit()

func feed_with(hunger_delta: float, mood_delta: float) -> void:
	hunger -= hunger_delta
	mood += mood_delta
	_clamp_all()
	_check_milestones()
	stats_changed.emit()

func play_with(mood_delta: float, bond_delta: float, hunger_delta: float) -> void:
	mood += mood_delta
	bond += bond_delta
	hunger += hunger_delta
	_clamp_all()
	_check_milestones()
	stats_changed.emit()

func play() -> void:
	mood += 10.0
	bond += 5.0
	hunger += 5.0
	_clamp_all()
	_check_milestones()
	stats_changed.emit()

func tick(delta: float) -> void:
	hunger += HUNGER_PER_SEC * delta
	mood -= MOOD_DECAY_PER_SEC * delta
	_clamp_all()
	stats_changed.emit()

func _check_milestones() -> void:
	for th in MILESTONES:
		if bond >= float(th) and th not in unlocked_milestones:
			unlocked_milestones.append(th)
			var title := str(MILESTONE_TITLES.get(th, "亲密升级"))
			milestone_unlocked.emit(int(th), title)

func to_save() -> Dictionary:
	return {
		"mood": mood,
		"hunger": hunger,
		"bond": bond,
		"unlocked_milestones": unlocked_milestones.duplicate(),
	}

func from_save(data: Dictionary) -> void:
	if data.has("mood"):
		mood = float(data["mood"])
	if data.has("hunger"):
		hunger = float(data["hunger"])
	if data.has("bond"):
		bond = float(data["bond"])
	if data.has("unlocked_milestones"):
		unlocked_milestones = []
		for v in data["unlocked_milestones"]:
			unlocked_milestones.append(int(v))
	_clamp_all()
	# Re-fire any already unlocked without spam: just ensure list consistent
	for th in MILESTONES:
		if bond >= float(th) and th not in unlocked_milestones:
			unlocked_milestones.append(th)
	stats_changed.emit()

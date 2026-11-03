# scripts/cat_controller.gd
extends Node3D

@onready var stats: PetStats = %PetStats
@onready var body: Node3D = %CatBody
@onready var feedback_label: Label = %FeedbackLabel

var _cooldown := 0.0
const COOLDOWN := 0.9

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if stats:
		stats.tick(delta)

func do_pet() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	stats.pet()
	_bounce()
	_say("呼噜～再摸摸")

func do_feed() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	stats.feed()
	_bounce()
	_say("喵，好吃！")

func do_play() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	stats.play()
	_bounce()
	_say("逗我！还要～")

func _say(t: String) -> void:
	if feedback_label:
		feedback_label.text = t

func _bounce() -> void:
	if body == null:
		return
	var tw := create_tween()
	tw.tween_property(body, "scale", Vector3(1.15, 0.9, 1.15), 0.08)
	tw.tween_property(body, "scale", Vector3.ONE, 0.12)

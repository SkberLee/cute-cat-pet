# scripts/cat_controller.gd
extends Node3D

@onready var stats: PetStats = %PetStats
@onready var body: Node3D = %CatBody
@onready var feedback_label: Label = %FeedbackLabel
@onready var anim: AnimationPlayer = %CatAnim

var _cooldown := 0.0
const COOLDOWN := 0.9

func _ready() -> void:
	_ensure_animations()
	if anim and anim.has_animation("idle"):
		anim.play("idle")

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
	_play_oneshot("pet")
	_say("呼噜～再摸摸")

func do_feed() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	stats.feed()
	_play_oneshot("feed")
	_say("喵，好吃！")

func do_play() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	stats.play()
	_play_oneshot("play")
	_say("逗我！还要～")

func _say(t: String) -> void:
	if feedback_label:
		feedback_label.text = t

func _play_oneshot(anim_name: String) -> void:
	if anim == null:
		_soft_tween_fallback(anim_name)
		return
	if not anim.has_animation(anim_name):
		_soft_tween_fallback(anim_name)
		return
	anim.play(anim_name)

func _soft_tween_fallback(kind: String) -> void:
	# Softer than the old squash-bounce if AnimationPlayer is missing.
	if body == null:
		return
	var tw := create_tween()
	match kind:
		"feed":
			tw.tween_property(body, "position:y", 0.04, 0.12)
			tw.tween_property(body, "position:y", 0.0, 0.18)
		"play":
			tw.tween_property(body, "position", Vector3(0.0, 0.12, -0.08), 0.12)
			tw.tween_property(body, "position", Vector3.ZERO, 0.18)
		_:
			tw.tween_property(body, "rotation_degrees:z", -6.0, 0.1)
			tw.tween_property(body, "rotation_degrees:z", 6.0, 0.12)
			tw.tween_property(body, "rotation_degrees:z", 0.0, 0.12)

func _ensure_animations() -> void:
	if anim == null or body == null:
		return
	anim.root_node = NodePath("..")
	# Rebuild library each run so scene edits stay simple (no baked .tres needed).
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _make_idle())
	lib.add_animation("pet", _make_pet())
	lib.add_animation("feed", _make_feed())
	lib.add_animation("play", _make_play())
	if anim.has_animation_library(""):
		anim.remove_animation_library("")
	anim.add_animation_library("", lib)
	if not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)

func _on_anim_finished(anim_name: StringName) -> void:
	if String(anim_name) == "idle":
		return
	if anim and anim.has_animation("idle"):
		anim.play("idle")

func _make_idle() -> Animation:
	var a := Animation.new()
	a.length = 2.4
	a.loop_mode = Animation.LOOP_LINEAR
	var i_s := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i_s, NodePath("CatBody:scale"))
	a.track_insert_key(i_s, 0.0, Vector3.ONE)
	a.track_insert_key(i_s, 1.2, Vector3(1.015, 0.985, 1.015))
	a.track_insert_key(i_s, 2.4, Vector3.ONE)
	var i_r := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i_r, NodePath("CatBody:rotation_degrees"))
	a.track_insert_key(i_r, 0.0, Vector3(0, 0, 0))
	a.track_insert_key(i_r, 1.2, Vector3(0, 2.5, 0))
	a.track_insert_key(i_r, 2.4, Vector3(0, 0, 0))
	return a

func _make_pet() -> Animation:
	# Happy lean / head-bob toward the camera.
	var a := Animation.new()
	a.length = 0.7
	var i_r := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i_r, NodePath("CatBody:rotation_degrees"))
	a.track_insert_key(i_r, 0.0, Vector3(0, 0, 0))
	a.track_insert_key(i_r, 0.15, Vector3(-8, 8, -4))
	a.track_insert_key(i_r, 0.35, Vector3(-4, -6, 4))
	a.track_insert_key(i_r, 0.7, Vector3(0, 0, 0))
	var i_s := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i_s, NodePath("CatBody:scale"))
	a.track_insert_key(i_s, 0.0, Vector3.ONE)
	a.track_insert_key(i_s, 0.2, Vector3(1.04, 0.97, 1.04))
	a.track_insert_key(i_s, 0.7, Vector3.ONE)
	return a

func _make_feed() -> Animation:
	# Dip down as if eating, then settle.
	var a := Animation.new()
	a.length = 0.85
	var i_r := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i_r, NodePath("CatBody:rotation_degrees"))
	a.track_insert_key(i_r, 0.0, Vector3(0, 0, 0))
	a.track_insert_key(i_r, 0.25, Vector3(18, 0, 0))
	a.track_insert_key(i_r, 0.55, Vector3(12, 0, 0))
	a.track_insert_key(i_r, 0.85, Vector3(0, 0, 0))
	var i_p := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i_p, NodePath("CatBody:position"))
	a.track_insert_key(i_p, 0.0, Vector3.ZERO)
	a.track_insert_key(i_p, 0.25, Vector3(0, -0.02, 0.04))
	a.track_insert_key(i_p, 0.85, Vector3.ZERO)
	return a

func _make_play() -> Animation:
	# Soft pounce hop toward camera then back.
	var a := Animation.new()
	a.length = 0.75
	var i_p := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i_p, NodePath("CatBody:position"))
	a.track_insert_key(i_p, 0.0, Vector3.ZERO)
	a.track_insert_key(i_p, 0.18, Vector3(0, 0.14, 0.12))
	a.track_insert_key(i_p, 0.4, Vector3(0, 0.02, 0.18))
	a.track_insert_key(i_p, 0.75, Vector3.ZERO)
	var i_r := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i_r, NodePath("CatBody:rotation_degrees"))
	a.track_insert_key(i_r, 0.0, Vector3(0, 0, 0))
	a.track_insert_key(i_r, 0.18, Vector3(-12, 0, 0))
	a.track_insert_key(i_r, 0.4, Vector3(6, 0, 0))
	a.track_insert_key(i_r, 0.75, Vector3(0, 0, 0))
	var i_s := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i_s, NodePath("CatBody:scale"))
	a.track_insert_key(i_s, 0.0, Vector3.ONE)
	a.track_insert_key(i_s, 0.18, Vector3(0.96, 1.08, 0.96))
	a.track_insert_key(i_s, 0.75, Vector3.ONE)
	return a

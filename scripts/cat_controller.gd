# scripts/cat_controller.gd
extends Node3D

@onready var stats: PetStats = %PetStats
@onready var body: Node3D = %CatBody
@onready var feedback_label: Label = %FeedbackLabel

## Logical action -> skeletal clip on the Vuena cat AnimationPlayer.
const CLIP_IDLE := "sit"
const CLIP_PET := "call"
const CLIP_FEED := "eat"
const CLIP_PLAY := "jump"

var anim: AnimationPlayer
var _cooldown := 0.0
var _idle_clip := CLIP_IDLE

func _ready() -> void:
	anim = _resolve_anim_player()
	if anim:
		_ensure_idle_loops()
		if not anim.animation_finished.is_connected(_on_anim_finished):
			anim.animation_finished.connect(_on_anim_finished)
		# Prefer sit loop for a calm room pet; fall back to idle.
		if anim.has_animation(CLIP_IDLE):
			_idle_clip = CLIP_IDLE
		elif anim.has_animation("idle"):
			_idle_clip = "idle"
		_play_idle()
	else:
		push_warning("CatController: no AnimationPlayer found on cat model")

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if stats:
		stats.tick(delta)

func do_pet() -> void:
	if _cooldown > 0.0:
		return
	stats.pet()
	_play_oneshot(CLIP_PET)
	_say("呼噜～再摸摸")

func do_feed() -> void:
	if _cooldown > 0.0:
		return
	stats.feed()
	_play_oneshot(CLIP_FEED)
	_say("喵，好吃！")

func do_play() -> void:
	if _cooldown > 0.0:
		return
	stats.play()
	_play_oneshot(CLIP_PLAY)
	_say("逗我！还要～")

func _say(t: String) -> void:
	if feedback_label:
		feedback_label.text = t

func _resolve_anim_player() -> AnimationPlayer:
	if body:
		var found := body.find_child("AnimationPlayer", true, false)
		if found is AnimationPlayer:
			return found as AnimationPlayer
	var legacy := get_node_or_null("%CatAnim")
	if legacy is AnimationPlayer:
		return legacy as AnimationPlayer
	return null

func _ensure_idle_loops() -> void:
	# glTF often omits loop flags; force calm loops for room idle.
	for clip in ["sit", "idle", "idle_alt", "sleep"]:
		if not anim.has_animation(clip):
			continue
		var a: Animation = anim.get_animation(clip)
		if a:
			a.loop_mode = Animation.LOOP_LINEAR

func _play_idle() -> void:
	if anim == null:
		return
	if not anim.has_animation(_idle_clip):
		return
	anim.play(_idle_clip)

func _play_oneshot(clip: String) -> void:
	if anim == null or not anim.has_animation(clip):
		_soft_tween_fallback(clip)
		_cooldown = 0.9
		return
	anim.play(clip)
	var length := anim.current_animation_length
	_cooldown = maxf(0.9, length * 0.85)

func _soft_tween_fallback(kind: String) -> void:
	if body == null:
		return
	var tw := create_tween()
	match kind:
		CLIP_FEED, "feed":
			tw.tween_property(body, "position:y", 0.04, 0.12)
			tw.tween_property(body, "position:y", 0.0, 0.18)
		CLIP_PLAY, "play":
			tw.tween_property(body, "position", Vector3(0.0, 0.12, -0.08), 0.12)
			tw.tween_property(body, "position", Vector3.ZERO, 0.18)
		_:
			tw.tween_property(body, "rotation_degrees:z", -6.0, 0.1)
			tw.tween_property(body, "rotation_degrees:z", 6.0, 0.12)
			tw.tween_property(body, "rotation_degrees:z", 0.0, 0.12)

func _on_anim_finished(anim_name: StringName) -> void:
	_play_idle()

# scripts/cat_controller.gd
extends Node3D

signal interaction_started(action: String)
signal interaction_ready
signal save_requested
signal cat_tapped

@onready var stats: PetStats = %PetStats
@onready var body: Node3D = %CatBody
@onready var feedback_label: Label = %FeedbackLabel
@onready var speech_bubble: Node = get_node_or_null("%SpeechBubble")

## Logical action -> skeletal clip on the Vuena cat AnimationPlayer.
const CLIP_IDLE := "sit"
const CLIP_PET := "call"
const CLIP_FEED := "eat"
const CLIP_PLAY := "jump"

const LINES_PET := [
	"呼噜～再摸摸",
	"嗯…好舒服呀",
	"贴贴～喜欢你",
	"轻轻的…再来一下",
]
const LINES_PET_SWEET := [
	"只准你摸哦～",
	"心心都给你了",
	"再贴紧一点…",
	"你的手好暖呀",
]
const LINES_FEED := [
	"喵，好吃！",
	"嚼嚼～谢谢你",
	"饱饱的，幸福",
	"今天也好好吃饭啦",
]
const LINES_FEED_SWEET := [
	"你喂的最好吃",
	"为你多吃两口～",
	"吃饭也要想你",
]
const LINES_PLAY := [
	"逗我！还要～",
	"跳！再玩一会儿",
	"呜哇，好开心",
	"陪我玩嘛～",
]
const LINES_PLAY_SWEET := [
	"和你玩最开心",
	"一辈子都陪你跳",
	"扑进你怀里～",
]
const LINES_BUSY := [
	"等一下下…",
	"喵？稍等我",
	"呼…缓一缓",
]
const LINES_AUTO := [
	"自己玩一会儿～",
	"蹦！",
	"走走停停…",
	"晒晒太阳喵",
]
const LINES_MILESTONE := {
	25: "亲密度提升～我更黏你了",
	50: "你是我的心肝宝贝呀",
	75: "房间也想为你打扮一下",
	100: "永远和你在一起，好不好",
}

## Keep wander inside the soft rug / floor play area.
const FLOOR_MIN := Vector3(-1.15, 0.0, -0.55)
const FLOOR_MAX := Vector3(1.15, 0.0, 1.05)

var anim: AnimationPlayer
var _cooldown := 0.0
var _idle_clip := CLIP_IDLE
var _rng := RandomNumberGenerator.new()
var _sfx_pet: AudioStream
var _sfx_feed: AudioStream
var _sfx_play: AudioStream
var _sfx_milestone: AudioStream
var _player: AudioStreamPlayer
var _bgm: AudioStreamPlayer
var _heart: MeshInstance3D
var _save_timer := 0.0

# Autonomy
var _auto_timer := 3.5
var _wandering := false
var _wander_target := Vector3.ZERO
var _auto_busy := false
var _home_y := 0.0
var _hit_body: StaticBody3D

func _ready() -> void:
	_rng.randomize()
	_home_y = position.y
	_setup_audio()
	_setup_heart_cosmetic()
	_setup_tap_collider()
	anim = _resolve_anim_player()
	if anim:
		_ensure_idle_loops()
		if not anim.animation_finished.is_connected(_on_anim_finished):
			anim.animation_finished.connect(_on_anim_finished)
		if anim.has_animation(CLIP_IDLE):
			_idle_clip = CLIP_IDLE
		elif anim.has_animation("idle"):
			_idle_clip = "idle"
		_play_idle()
	else:
		push_warning("CatController: no AnimationPlayer found on cat model")
	if stats:
		if not stats.milestone_unlocked.is_connected(_on_milestone):
			stats.milestone_unlocked.connect(_on_milestone)
		_apply_cosmetics_for_bond(stats.bond)
	# Defer so SpeechBubble can finish setup / resolve camera.
	call_deferred("_say", "来摸摸我吧～", false)
	_auto_timer = _rng.randf_range(2.8, 5.0)

func _process(delta: float) -> void:
	var was_busy := _cooldown > 0.0
	if _cooldown > 0.0:
		_cooldown -= delta
		if was_busy and _cooldown <= 0.0:
			_cooldown = 0.0
			interaction_ready.emit()
	if stats:
		stats.tick(delta)
	_save_timer += delta
	if _save_timer >= 8.0:
		_save_timer = 0.0
		save_requested.emit()
	_tick_autonomy(delta)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_requested.emit()

func can_interact() -> bool:
	return _cooldown <= 0.0

func do_pet() -> void:
	if not _begin("pet"):
		return
	_cancel_autonomy()
	stats.pet()
	_play_oneshot(CLIP_PET)
	_say(_pick(_lines_for("pet")))
	_play_sfx(_sfx_pet)
	_apply_cosmetics_for_bond(stats.bond)
	save_requested.emit()

func do_feed() -> void:
	if not _begin("feed"):
		return
	_cancel_autonomy()
	stats.feed()
	_play_oneshot(CLIP_FEED)
	_say(_pick(_lines_for("feed")))
	_play_sfx(_sfx_feed)
	save_requested.emit()

func do_play() -> void:
	if not _begin("play"):
		return
	_cancel_autonomy()
	stats.play()
	_play_oneshot(CLIP_PLAY)
	_say(_pick(_lines_for("play")))
	_play_sfx(_sfx_play)
	_apply_cosmetics_for_bond(stats.bond)
	save_requested.emit()

func face_world_point(world_pos: Vector3) -> void:
	var flat := Vector3(world_pos.x - global_position.x, 0.0, world_pos.z - global_position.z)
	if flat.length_squared() < 0.0001:
		return
	# Cute cat rest pose faces +Z (toward camera). Rotate Y so +Z follows target.
	var dir := flat.normalized()
	rotation = Vector3(0.0, atan2(dir.x, dir.z), 0.0)

func get_focus_point() -> Vector3:
	# Approximate cat face for close-up framing.
	return global_position + Vector3(0.0, 0.72, 0.08)

func get_mouth_point() -> Vector3:
	# Local muzzle: slightly low + forward (+Z rest pose faces camera).
	return to_global(Vector3(0.06, 0.48, 0.26))

func _lines_for(kind: String) -> Array:
	match kind:
		"pet":
			if stats and stats.bond >= 25.0:
				return LINES_PET + LINES_PET_SWEET
			return LINES_PET
		"feed":
			if stats and stats.bond >= 50.0:
				return LINES_FEED + LINES_FEED_SWEET
			return LINES_FEED
		"play":
			if stats and stats.bond >= 75.0:
				return LINES_PLAY + LINES_PLAY_SWEET
			return LINES_PLAY
	return LINES_PET

func _begin(action: String) -> bool:
	if _cooldown > 0.0:
		_say(_pick(LINES_BUSY), true)
		return false
	interaction_started.emit(action)
	return true

func _pick(lines: Array) -> String:
	return lines[_rng.randi_range(0, lines.size() - 1)]

func _say(t: String, soft: bool = true) -> void:
	if speech_bubble and speech_bubble.has_method("show_line"):
		speech_bubble.show_line(t, soft)
		return
	if feedback_label == null:
		return
	feedback_label.text = t
	if not soft:
		feedback_label.modulate.a = 1.0
		return
	feedback_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(feedback_label, "modulate:a", 1.0, 0.18)

func _on_milestone(threshold: int, title: String) -> void:
	var line := str(LINES_MILESTONE.get(threshold, title))
	_say("✨ %s" % line)
	_play_sfx(_sfx_milestone)
	_apply_cosmetics_for_bond(stats.bond if stats else float(threshold))
	save_requested.emit()

func _setup_audio() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "SoftSfx"
	_player.volume_db = -6.0
	add_child(_player)
	_sfx_pet = load("res://assets/sfx/pet.wav")
	_sfx_feed = load("res://assets/sfx/feed.wav")
	_sfx_play = load("res://assets/sfx/play.wav")
	_sfx_milestone = load("res://assets/sfx/milestone.wav")
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "SoftBgm"
	_bgm.volume_db = -16.0
	add_child(_bgm)
	var bgm_stream = load("res://assets/sfx/bgm_soft.wav")
	if bgm_stream is AudioStreamWAV:
		var looped: AudioStreamWAV = (bgm_stream as AudioStreamWAV).duplicate()
		looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_bgm.stream = looped
	else:
		_bgm.stream = bgm_stream
	_bgm.play()

func _play_sfx(stream: AudioStream) -> void:
	if _player == null or stream == null:
		return
	_player.stream = stream
	_player.pitch_scale = _rng.randf_range(0.96, 1.05)
	_player.play()

func _setup_heart_cosmetic() -> void:
	_heart = MeshInstance3D.new()
	_heart.name = "BondHeart"
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	_heart.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.65)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.55)
	mat.emission_energy_multiplier = 1.4
	_heart.material_override = mat
	_heart.position = Vector3(0.12, 0.55, 0.18)
	_heart.visible = false
	if body:
		body.add_child(_heart)

func _setup_tap_collider() -> void:
	_hit_body = StaticBody3D.new()
	_hit_body.name = "CatTapBody"
	_hit_body.collision_layer = 1
	_hit_body.collision_mask = 0
	_hit_body.input_ray_pickable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Covers sitting chibi cat after ×2 scale.
	box.size = Vector3(0.95, 1.05, 0.95)
	shape.shape = box
	shape.position = Vector3(0.0, 0.52, 0.05)
	_hit_body.add_child(shape)
	add_child(_hit_body)

func _apply_cosmetics_for_bond(bond: float) -> void:
	if _heart:
		_heart.visible = bond >= 50.0

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
	for clip in ["sit", "idle", "idle_alt", "sleep", "walk"]:
		if not anim.has_animation(clip):
			continue
		var a: Animation = anim.get_animation(clip)
		if a and clip != "walk":
			a.loop_mode = Animation.LOOP_LINEAR
		elif a and clip == "walk":
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
		_cooldown = 0.85
		return
	anim.play(clip)
	var length := anim.current_animation_length
	_cooldown = clampf(length * 0.75, 0.7, 1.35)

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

func _on_anim_finished(_anim_name: StringName) -> void:
	if _wandering:
		return
	if _auto_busy:
		_auto_busy = false
		_play_idle()
		_auto_timer = _rng.randf_range(3.2, 6.5)
		return
	_play_idle()

func _tick_autonomy(delta: float) -> void:
	if _cooldown > 0.0:
		return
	if _wandering:
		_update_wander(delta)
		return
	if _auto_busy:
		return
	_auto_timer -= delta
	if _auto_timer > 0.0:
		return
	_choose_autonomy()

func _choose_autonomy() -> void:
	_auto_timer = _rng.randf_range(3.5, 7.0)
	var roll := _rng.randi_range(0, 5)
	match roll:
		0, 1:
			_play_idle()
		2:
			_play_auto_clip("idle_alt")
		3:
			_play_auto_clip("jump")
			_say(_pick(LINES_AUTO), true)
		4:
			_play_auto_clip("idle")
		_:
			_start_wander()

func _play_auto_clip(clip: String) -> void:
	if anim == null or not anim.has_animation(clip):
		_play_idle()
		return
	_auto_busy = true
	anim.play(clip)
	# Safety unlock if finished signal is late.
	var length := maxf(anim.current_animation_length, 0.6)
	get_tree().create_timer(length + 0.05).timeout.connect(func ():
		if _auto_busy and _cooldown <= 0.0 and not _wandering:
			_auto_busy = false
			_play_idle()
	)

func _start_wander() -> void:
	var target := Vector3(
		_rng.randf_range(FLOOR_MIN.x, FLOOR_MAX.x),
		_home_y,
		_rng.randf_range(FLOOR_MIN.z, FLOOR_MAX.z)
	)
	if target.distance_to(position) < 0.35:
		_play_auto_clip("idle_alt")
		return
	_wander_target = target
	_wandering = true
	_auto_busy = true
	face_world_point(target)
	if anim and anim.has_animation("walk"):
		anim.play("walk")
	elif anim and anim.has_animation("run"):
		anim.play("run")
	_say(_pick(LINES_AUTO), true)

func _update_wander(delta: float) -> void:
	var flat_pos := Vector3(position.x, _home_y, position.z)
	var flat_tgt := Vector3(_wander_target.x, _home_y, _wander_target.z)
	var to := flat_tgt - flat_pos
	var dist := to.length()
	if dist < 0.08:
		_finish_wander()
		return
	var step := minf(0.85 * delta, dist)
	position = flat_pos + to.normalized() * step
	position.y = _home_y
	face_world_point(_wander_target)
	# Soft clamp inside play AABB.
	position.x = clampf(position.x, FLOOR_MIN.x, FLOOR_MAX.x)
	position.z = clampf(position.z, FLOOR_MIN.z, FLOOR_MAX.z)

func _finish_wander() -> void:
	_wandering = false
	_auto_busy = false
	# Face roughly toward camera / room front.
	rotation = Vector3.ZERO
	_play_idle()
	_auto_timer = _rng.randf_range(3.5, 6.5)

func _cancel_autonomy() -> void:
	_wandering = false
	_auto_busy = false
	_auto_timer = _rng.randf_range(4.0, 7.5)

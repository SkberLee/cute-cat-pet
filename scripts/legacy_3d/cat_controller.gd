# scripts/cat_controller.gd
extends Node3D

signal interaction_started(action: String)
signal interaction_ready
signal save_requested
signal cat_tapped
## Emitted when the pet reaction starts, with the reaction clip length (UI shows the stroking hand).
signal pet_stroke(duration: float)
## Emitted when a feed / play choreography ends.
signal action_finished(kind: String)

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

## Free roaming bounds: whole room floor with wall / furniture margins.
## Room floor is x[-3.1, 3.1], z[-2.55, 2.6].
const FLOOR_MIN := Vector3(-2.3, 0.0, -1.55)
const FLOOR_MAX := Vector3(2.3, 0.0, 1.55)
## Furniture the cat should walk around: (x, z, radius incl. cat body margin).
const OBSTACLES := [
	Vector3(1.7, 0.55, 0.75),   # side table + lamp
	Vector3(1.55, -0.9, 0.8),   # cushion
	Vector3(-1.85, -1.7, 0.6),  # plant
	Vector3(-0.85, 0.55, 0.3),  # food bowl
]
const MOUTH_DY := 0.0
const MOUTH_DZ := 0.0
const WALK_SPEED := 0.95
const TURN_SPEED := 9.0

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
var _autonomy_paused := false
var _rest_timer := 0.0
var _face_tween: Tween
var _jaw_skel: Skeleton3D
var _jaw_bone := -1
var _home_y := 0.0
var _hit_body: StaticBody3D
var _head_bone := -1
## While a feed / play sequence runs, the camera frames the cat and this point together.
var action_anchor := Vector3.ZERO
var has_anchor := false

# Feed / play choreography state
var action_phase := ""            # "", "walk", "eat", "chase", "wand" ...
var action_kind := ""
var _action_id := 0
var _props: Array = []
const EAT_REACH := 0.64           # cat origin -> muzzle distance along facing
const CHASE_STOP := 0.72
const RUN_SPEED := 1.9

func _ready() -> void:
	_rng.randomize()
	_home_y = position.y
	_setup_audio()
	_setup_heart_cosmetic()
	_setup_tap_collider()
	anim = _resolve_anim_player()
	_resolve_jaw()
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
	_auto_timer = _rng.randf_range(1.5, 2.8)

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
	pet_stroke.emit(maxf(_cooldown, 1.2))
	_say(_pick(_lines_for("pet")))
	_play_sfx(_sfx_pet)
	_apply_cosmetics_for_bond(stats.bond)
	save_requested.emit()

func do_feed(food_id: String = "") -> void:
	if not _begin("feed"):
		return
	if CatProps.FOODS.has(food_id):
		_run_feed(food_id)
		return
	_cancel_autonomy()
	stats.feed()
	_play_oneshot(CLIP_FEED)
	_say(_pick(_lines_for("feed")))
	_play_sfx(_sfx_feed)
	save_requested.emit()

func do_play(toy_id: String = "") -> void:
	if not _begin("play"):
		return
	if CatProps.TOYS.has(toy_id):
		_run_play(toy_id)
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

func _resolve_jaw() -> void:
	if body == null:
		return
	var sk := body.find_child("Skeleton3D", true, false)
	if sk is Skeleton3D:
		_jaw_skel = sk as Skeleton3D
		_jaw_bone = _jaw_skel.find_bone("Jaw")
		_head_bone = _jaw_skel.find_bone("Head")
		CatPaws.build(_jaw_skel)

func get_mouth_point() -> Vector3:
	# Follows the animated Jaw bone (so walking / eating / jumping stay anchored).
	if _jaw_skel and _jaw_bone >= 0:
		var jaw: Vector3 = _jaw_skel.global_transform * _jaw_skel.get_bone_global_pose(_jaw_bone).origin
		return jaw + global_transform.basis * Vector3(0.0, MOUTH_DY, MOUTH_DZ)
	return to_global(Vector3(0.0, 0.45, 0.3))

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
	for clip in ["sit", "idle", "idle_alt", "sleep", "walk", "run"]:
		if not anim.has_animation(clip):
			continue
		var a: Animation = anim.get_animation(clip)
		if a and clip != "walk":
			a.loop_mode = Animation.LOOP_LINEAR
		elif a and clip == "walk":
			a.loop_mode = Animation.LOOP_LINEAR
		if a and clip == "run":
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
	if action_phase != "" or _wandering:
		return
	if _auto_busy:
		_auto_busy = false
		_play_idle()
		_auto_timer = _rng.randf_range(1.5, 3.2)
		return
	_play_idle()

func set_autonomy_paused(paused: bool) -> void:
	_autonomy_paused = paused
	if action_phase != "":
		return
	if paused:
		_cancel_autonomy()
		_play_idle()

func is_wandering() -> bool:
	return _wandering

func _tick_autonomy(delta: float) -> void:
	if _cooldown > 0.0 or _autonomy_paused:
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
	# More wandering than standing around: roam most of the time.
	_auto_timer = _rng.randf_range(1.5, 3.5)
	_idle_clip = CLIP_IDLE
	var roll := _rng.randi_range(0, 9)
	if roll <= 5:
		_start_wander()
	elif roll == 6:
		_play_auto_clip("idle_alt")
	elif roll == 7:
		_play_auto_clip("jump")
		_say(_pick(LINES_AUTO), true)
	else:
		_play_idle()

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

func _segment_hits_obstacle(a: Vector3, b: Vector3) -> bool:
	for o in OBSTACLES:
		var c := Vector2(o.x, o.y)
		var p0 := Vector2(a.x, a.z)
		var p1 := Vector2(b.x, b.z)
		var d := p1 - p0
		var len2 := d.length_squared()
		var t := 0.0
		if len2 > 0.0001:
			t = clampf((c - p0).dot(d) / len2, 0.0, 1.0)
		if (p0 + d * t).distance_to(c) < o.z:
			return true
	return false

func _pick_wander_target() -> Vector3:
	var best := Vector3.INF
	for i in 24:
		var t := Vector3(
			_rng.randf_range(FLOOR_MIN.x, FLOOR_MAX.x),
			_home_y,
			_rng.randf_range(FLOOR_MIN.z, FLOOR_MAX.z)
		)
		if t.distance_to(position) < 0.9:
			continue
		if _segment_hits_obstacle(position, t):
			continue
		return t
	return best

func _start_wander(forced_target: Vector3 = Vector3.INF) -> void:
	var target := forced_target
	if target == Vector3.INF:
		target = _pick_wander_target()
	if target == Vector3.INF:
		_play_auto_clip("idle_alt")
		return
	target.x = clampf(target.x, FLOOR_MIN.x, FLOOR_MAX.x)
	target.z = clampf(target.z, FLOOR_MIN.z, FLOOR_MAX.z)
	target.y = _home_y
	if _face_tween and _face_tween.is_valid():
		_face_tween.kill()
	_wander_target = target
	_wandering = true
	_auto_busy = true
	var walk_clip := "walk" if anim and anim.has_animation("walk") else "run"
	if anim and anim.has_animation(walk_clip):
		anim.play(walk_clip)
	if _rng.randf() < 0.45:
		_say(_pick(LINES_AUTO), true)

func _update_wander(delta: float) -> void:
	var flat_pos := Vector3(position.x, _home_y, position.z)
	var to := Vector3(_wander_target.x, _home_y, _wander_target.z) - flat_pos
	var dist := to.length()
	if dist < 0.06:
		_finish_wander()
		return
	var dir := to / dist
	# Turn smoothly toward the walking direction (rest pose faces +Z).
	var want_yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, want_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))
	var step := minf(WALK_SPEED * delta, dist)
	position = flat_pos + dir * step
	position.y = _home_y
	position.x = clampf(position.x, FLOOR_MIN.x, FLOOR_MAX.x)
	position.z = clampf(position.z, FLOOR_MIN.z, FLOOR_MAX.z)

func _finish_wander() -> void:
	_wandering = false
	_auto_busy = false
	_face_front(0.3)
	# At the destination do something cute for a bit.
	var roll := _rng.randi_range(0, 9)
	_auto_timer = _rng.randf_range(1.5, 3.0)
	if roll <= 3:
		_idle_clip = CLIP_IDLE
		_play_idle()
	elif roll == 4 or roll == 5:
		_idle_clip = "idle" if anim and anim.has_animation("idle") else CLIP_IDLE
		_play_idle()
	elif roll == 6:
		_play_auto_clip("idle_alt")
	elif roll == 7:
		_play_auto_clip("jump")
	else:
		# Nap: loop sleep for a few seconds, then wake up.
		if anim and anim.has_animation("sleep"):
			_idle_clip = "sleep"
			_auto_timer = _rng.randf_range(4.0, 6.5)
		_play_idle()

func _face_front(duration: float, jitter: float = 0.5) -> void:
	# Turn toward the camera side with a small random yaw for variety.
	var target_yaw := _rng.randf_range(-jitter, jitter)
	if _face_tween and _face_tween.is_valid():
		_face_tween.kill()
	var start := rotation.y
	var end := start + wrapf(target_yaw - start, -PI, PI)
	_face_tween = create_tween()
	_face_tween.tween_property(self, "rotation:y", end, duration).set_trans(Tween.TRANS_SINE)

func _cancel_autonomy() -> void:
	if action_phase != "":
		return
	var was_wandering := _wandering
	_wandering = false
	_auto_busy = false
	_idle_clip = CLIP_IDLE
	_auto_timer = _rng.randf_range(3.0, 5.5)
	if was_wandering or absf(wrapf(rotation.y, -PI, PI)) > 0.05:
		_face_front(0.25, 0.0)


# ==================================================================
# Head anchor (pet hand), feed + play choreography
# ==================================================================

func get_head_point() -> Vector3:
	if _jaw_skel and _head_bone >= 0:
		var h: Vector3 = _jaw_skel.global_transform * _jaw_skel.get_bone_global_pose(_head_bone).origin
		return h + Vector3(0.0, 0.34, 0.0)
	return global_position + Vector3(0.0, 0.9, 0.3)

func is_busy_action() -> bool:
	return action_phase != ""

const FOOD_LINES := {
	"fish": {
		"start": ["是小鱼干！我来啦", "闻到鱼香味了～"],
		"eat": ["咔嚓咔嚓～香香的", "小鱼干最好吃啦", "鱼干鱼干，喵！"],
	},
	"kibble": {
		"start": ["开饭啦～", "猫粮的声音！"],
		"eat": ["嘎吱嘎吱，脆脆的", "吃饱饱才有力气玩", "饱饱的，幸福"],
	},
	"can": {
		"start": ["罐罐！好香呀～", "是罐头吗？快快快"],
		"eat": ["软软的，好满足", "罐罐最好吃了", "呼噜呼噜…太幸福"],
	},
	"milk": {
		"start": ["有牛奶喝～", "甜甜的奶香味"],
		"eat": ["舔舔～甜甜的奶", "喝完嘴巴白白的", "温温的，好舒服"],
	},
}
const TOY_LINES := {
	"wand": {
		"start": ["羽毛！看我扑", "逗猫棒～抓住你"],
		"end": ["差一点点就抓到了", "再来一次嘛"],
	},
	"yarn": {
		"start": ["毛线球滚起来啦", "球球别跑！"],
		"end": ["抓到球球啦", "咕噜咕噜，好好玩"],
	},
	"laser": {
		"start": ["红点点！哪里跑", "盯住盯住…"],
		"end": ["红点点怎么没啦？", "喵？它躲起来了"],
	},
	"mouse": {
		"start": ["小老鼠！别跑", "吱吱吱？抓你！"],
		"end": ["抓到小老鼠啦", "我是捕鼠小能手"],
	},
}

func _new_action(kind: String) -> int:
	_action_id += 1
	action_kind = kind
	return _action_id

func _spawn_prop(n: Node3D) -> void:
	var parent := get_parent()
	if parent == null:
		parent = get_tree().root
	parent.add_child(n)
	_props.append(n)

func _clear_props() -> void:
	for n in _props:
		if is_instance_valid(n):
			n.queue_free()
	_props.clear()

func _pop_in(n: Node3D, dur := 0.35) -> void:
	n.scale = Vector3.ONE * 0.01
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _pop_out_free(n: Node3D, dur := 0.25) -> void:
	if not is_instance_valid(n):
		return
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 0.01, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(n.queue_free)

func _inside_obstacle(p: Vector3, margin := 0.0) -> bool:
	for o in OBSTACLES:
		if Vector2(p.x, p.z).distance_to(Vector2(o.x, o.y)) < o.z + margin:
			return true
	return false

func _push_out_of_obstacles(p: Vector3) -> Vector3:
	for o in OBSTACLES:
		var c := Vector2(o.x, o.y)
		var d := Vector2(p.x, p.z) - c
		var r: float = o.z * 0.85
		if d.length() < r:
			var n := d.normalized() if d.length() > 0.001 else Vector2(0, 1)
			var q := c + n * r
			p.x = q.x
			p.z = q.y
	return p

func _clamp_floor(p: Vector3) -> Vector3:
	p.x = clampf(p.x, FLOOR_MIN.x, FLOOR_MAX.x)
	p.z = clampf(p.z, FLOOR_MIN.z, FLOOR_MAX.z)
	p.y = _home_y
	return p

func _in_floor(p: Vector3) -> bool:
	return p.x >= FLOOR_MIN.x and p.x <= FLOOR_MAX.x and p.z >= FLOOR_MIN.z and p.z <= FLOOR_MAX.z

func _clip_for(name: String) -> String:
	if anim and anim.has_animation(name):
		return name
	if name == "run" and anim and anim.has_animation("walk"):
		return "walk"
	return _idle_clip

var _loco_clip := ""
func _loco(name: String) -> void:
	var c := _clip_for(name)
	if anim == null:
		return
	if anim.current_animation != c or not anim.is_playing():
		anim.play(c)
	_loco_clip = c

func _turn_toward(dir: Vector3, delta: float, speed := TURN_SPEED) -> void:
	if dir.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(speed * delta, 0.0, 1.0))

func _facing() -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y))

## Walk (or run) the cat to `target`. Returns false if the action was cancelled.
func _walk_to(target: Vector3, token: int, clip := "walk", speed := WALK_SPEED) -> bool:
	_loco(clip)
	var guard := 0.0
	while true:
		await get_tree().process_frame
		if token != _action_id:
			return false
		var delta := get_process_delta_time()
		guard += delta
		var flat := Vector3(position.x, _home_y, position.z)
		var to := Vector3(target.x, _home_y, target.z) - flat
		var dist := to.length()
		if dist < 0.05 or guard > 12.0:
			return true
		var dir := to / dist
		_turn_toward(dir, delta)
		position = _clamp_floor(_push_out_of_obstacles(flat + dir * minf(speed * delta, dist)))
	return true

func _wait(sec: float, token: int) -> bool:
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		if token != _action_id:
			return false
		t += get_process_delta_time()
	return true

func _pick_food_spot() -> Array:
	# Returns [bowl_position, cat_stop_position]. The cat walks ~0.6-0.9 and stops EAT_REACH short.
	# Prefer bowls toward the camera / sideways so the meal is easy to watch.
	var best: Array = []
	var best_score := -99.0
	for i in 120:
		var ang := _rng.randf_range(-PI, PI)
		var r := _rng.randf_range(1.25, 1.55)
		var dir := Vector3(sin(ang), 0.0, cos(ang))
		# Never send the cat away from the camera: we want to see the bowl and her face.
		if dir.z < -0.35 and i < 90:
			continue
		var stop := Vector3(position.x, _home_y, position.z) + dir * (r - EAT_REACH)
		var bowl := Vector3(position.x, 0.0, position.z) + dir * r
		if not _in_floor(stop) or bowl.z > 1.45 or absf(bowl.x) > 2.2 or _inside_obstacle(stop, 0.1) or _inside_obstacle(bowl, -0.1):
			continue
		if _segment_hits_obstacle(position, stop):
			continue
		var score := absf(dir.x) + dir.z * 0.25 + _rng.randf() * 0.3
		if score > best_score:
			best_score = score
			best = [bowl, stop]
	if not best.is_empty():
		return best
	var d := _facing()
	var st := _clamp_floor(position - d * 0.4)
	return [st + d * EAT_REACH, st]

func _run_feed(food_id: String) -> void:
	var token := _new_action("feed")
	_cancel_autonomy_force()
	_cooldown = 999.0
	var spec: Dictionary = CatProps.FOODS[food_id]
	var lines: Dictionary = FOOD_LINES[food_id]
	var spot := _pick_food_spot()
	var bowl: Vector3 = spot[0]
	var stop: Vector3 = spot[1]
	var food := CatProps.make_food(food_id)
	action_anchor = bowl
	has_anchor = true
	food.position = bowl
	_spawn_prop(food)
	_pop_in(food)
	action_phase = "walk"
	_say(_pick(lines["start"]), true)
	if not await _walk_to(stop, token):
		return
	# Face the bowl, then eat.
	action_phase = "eat"
	var want := atan2(bowl.x - position.x, bowl.z - position.z)
	var tw := create_tween()
	tw.tween_property(self, "rotation:y", rotation.y + wrapf(want - rotation.y, -PI, PI), 0.25).set_trans(Tween.TRANS_SINE)
	if not await _wait(0.3, token):
		return
	stats.feed_with(float(spec["hunger"]), float(spec["mood"]))
	_say(_pick(lines["eat"]), true)
	_play_sfx(_sfx_feed)
	var eat_clip := _clip_for(CLIP_FEED)
	var eat_len := 1.2
	if anim and anim.has_animation(eat_clip):
		eat_len = maxf(anim.get_animation(eat_clip).length, 0.8)
	var content := food.get_node_or_null("Content") as Node3D
	var total := eat_len * 2.0
	if content:
		var sh := create_tween()
		sh.tween_property(content, "scale", Vector3(0.75, 0.04, 0.75), total * 0.95).set_trans(Tween.TRANS_SINE)
	for rep in 2:
		if anim:
			anim.play(eat_clip)
		if not await _wait(eat_len, token):
			return
	_pop_out_free(food)
	_finish_action("feed")

func _finish_action(kind: String) -> void:
	has_anchor = false
	action_phase = ""
	action_kind = ""
	_loco_clip = ""
	_idle_clip = CLIP_IDLE
	_play_idle()
	_face_front(0.3, 0.2)
	_auto_timer = _rng.randf_range(2.5, 4.5)
	_cooldown = 0.5
	_props.clear()
	_apply_cosmetics_for_bond(stats.bond)
	save_requested.emit()
	action_finished.emit(kind)

func _cancel_autonomy_force() -> void:
	var saved := action_phase
	action_phase = ""
	_cancel_autonomy()
	action_phase = saved

func _run_play(toy_id: String) -> void:
	var token := _new_action("play")
	_cancel_autonomy_force()
	_cooldown = 999.0
	var spec: Dictionary = CatProps.TOYS[toy_id]
	var lines: Dictionary = TOY_LINES[toy_id]
	var toy := CatProps.make_toy(toy_id)
	_spawn_prop(toy)
	_pop_in(toy)
	action_phase = toy_id
	stats.play_with(float(spec["mood"]), float(spec["bond"]), float(spec["hunger"]))
	_play_sfx(_sfx_play)
	_say(_pick(lines["start"]), true)
	var ok := true
	if toy_id == "wand":
		ok = await _play_wand(toy, token)
	else:
		ok = await _play_chase(toy_id, toy, token)
	if not ok:
		return
	_say(_pick(lines["end"]), true)
	_pop_out_free(toy)
	_finish_action("play")

func _pounce(clip: String, token: int) -> bool:
	var c := _clip_for(clip)
	if anim:
		anim.play(c)
	var len := anim.get_animation(c).length if anim and anim.has_animation(c) else 0.8
	return await _wait(clampf(len, 0.5, 1.4), token)

func _play_wand(toy: Node3D, token: int) -> bool:
	# Feather swishes in front of the cat; the cat sits, tracks it, and pounces twice.
	var base := Vector3(position.x, 0.0, position.z)
	var fwd := _facing()
	if fwd.z < 0.2:
		fwd = Vector3(sin(0.0), 0.0, 1.0)
	var centre := base + fwd * 0.75
	var rod: Node3D = toy.get_node("Rod")
	rod.basis = Basis.looking_at(-Vector3(0.45, 0.7, 1.0).normalized(), Vector3.UP)
	var t := 0.0
	var pounce_at := [1.5, 3.2]
	var next := 0
	var dur := 5.0
	_loco(CLIP_IDLE)
	while t < dur:
		await get_tree().process_frame
		if token != _action_id:
			return false
		var delta := get_process_delta_time()
		t += delta
		var dip := 0.0
		if next < pounce_at.size() and t >= pounce_at[next]:
			next += 1
			_pounce_async(next == 1, token)
		# wand dips low near each pounce time
		for pa in pounce_at:
			dip = maxf(dip, clampf(1.0 - absf(t - pa - 0.15) / 0.5, 0.0, 1.0))
		var p := centre + Vector3(sin(t * 2.3) * 0.5, 0.0, cos(t * 1.6) * 0.22)
		p.y = lerpf(0.55 + 0.12 * sin(t * 4.6), 0.2, dip)
		toy.position = p
		action_anchor = p
		has_anchor = true
		var tip := toy.get_node("Tip") as Node3D
		tip.rotation.z = sin(t * 7.0) * 0.35
		_turn_toward(Vector3(p.x - position.x, 0.0, p.z - position.z), delta, 4.0)
	_loco(CLIP_IDLE)
	return true

func _pounce_async(first: bool, token: int) -> void:
	await _pounce("jump" if first else "attack", token)
	if token == _action_id and action_phase != "":
		_loco(CLIP_IDLE)

func _make_waypoints(count: int, start: Vector3, min_step: float) -> Array:
	# Mostly sideways hops so the chase stays in profile for the camera.
	var pts: Array = []
	var prev := start
	var side := -1.0 if start.x > 0.0 else 1.0
	for i in count:
		var best := prev
		for k in 40:
			var q := prev + Vector3(side * _rng.randf_range(min_step, min_step + 0.7), 0.0, _rng.randf_range(-0.45, 0.45))
			if not _in_floor(q) or _inside_obstacle(q, 0.05):
				side = -side
				continue
			best = q
			break
		pts.append(best)
		prev = best
		side = -side if _rng.randf() < 0.75 else side
	return pts

func _play_chase(toy_id: String, toy: Node3D, token: int) -> bool:
	var cfg: Dictionary = {
		"yarn": {"n": 3, "speed": 1.5, "pause": 0.7, "cat": 1.5, "step": 1.4},
		"mouse": {"n": 5, "speed": 1.7, "pause": 0.0, "cat": RUN_SPEED, "step": 1.0},
		"laser": {"n": 6, "speed": 2.3, "pause": 0.0, "cat": 2.2, "step": 1.0},
	}[toy_id]
	var fwd := _facing()
	var lat := Vector3(-1.0 if position.x > 0.0 else 1.0, 0.0, 0.25)
	var start := _clamp_floor(Vector3(position.x, 0.0, position.z) + lat.normalized() * 1.1)
	if _inside_obstacle(start, 0.05):
		start = _clamp_floor(Vector3(position.x, 0.0, position.z) + fwd * 1.1)
	toy.position = Vector3(start.x, 0.0, start.z)
	var pts := _make_waypoints(int(cfg["n"]), start, float(cfg["step"]))
	var idx := 0
	var pause := 0.0
	_pounce_cd = 0.0
	_pouncing = false
	var done_t := 0.0
	var elapsed := 0.0
	var spin := toy.get_node_or_null("Spin") as Node3D
	var finished_path := false
	while true:
		await get_tree().process_frame
		if token != _action_id:
			return false
		var delta := get_process_delta_time()
		elapsed += delta
		_pounce_cd -= delta
		# --- toy motion
		var moving := false
		if not finished_path:
			if pause > 0.0:
				pause -= delta
			else:
				var target: Vector3 = pts[idx]
				var to := Vector3(target.x - toy.position.x, 0.0, target.z - toy.position.z)
				var d := to.length()
				if d < 0.05:
					idx += 1
					pause = float(cfg["pause"])
					if idx >= pts.size():
						finished_path = true
				else:
					var step := minf(float(cfg["speed"]) * delta, d)
					var dir := to / d
					toy.position += dir * step
					moving = true
					if toy_id == "mouse":
						toy.rotation.y = lerp_angle(toy.rotation.y, atan2(-dir.z, dir.x), clampf(14.0 * delta, 0.0, 1.0))
						toy.position.y = absf(sin(elapsed * 22.0)) * 0.015
					elif toy_id == "yarn" and spin:
						spin.rotate(Vector3(dir.z, 0.0, -dir.x).normalized(), step / 0.11)
					elif toy_id == "laser":
						toy.position.y = 0.0
		action_anchor = toy.position
		has_anchor = true
		# --- cat chase
		var tp := Vector3(toy.position.x, _home_y, toy.position.z)
		var cp := Vector3(position.x, _home_y, position.z)
		var dv := tp - cp
		var dist := dv.length()
		if not _pouncing:
			if dist > CHASE_STOP:
				var dirc := dv / dist
				_loco("run")
				_turn_toward(dirc, delta, 10.0)
				position = _clamp_floor(_push_out_of_obstacles(cp + dirc * minf(float(cfg["cat"]) * delta, dist - CHASE_STOP * 0.9)))
			else:
				_turn_toward(dv, delta, 10.0)
				if toy_id != "laser" and (toy_id == "mouse" or not moving or finished_path) and _pounce_cd <= 0.0:
					_pouncing = true
					_pounce_chase(token, toy_id)
				elif moving:
					_loco("walk")
					position = _clamp_floor(_push_out_of_obstacles(cp + dv.normalized() * minf(float(cfg["speed"]) * delta, maxf(dist - CHASE_STOP * 0.9, 0.0))))
				else:
					_loco(CLIP_IDLE)
		if finished_path:
			done_t += delta
			if toy_id == "laser" and done_t > 0.8:
				_loco("idle_alt" if anim and anim.has_animation("idle_alt") else CLIP_IDLE)
				toy.visible = false
				return await _wait(1.0, token)
			if toy_id != "laser" and done_t > 2.2:
				return true
			if elapsed > 14.0:
				return true
		if elapsed > 16.0:
			return true
	return true

var _pouncing := false
var _pounce_cd := 0.0

func _pounce_chase(token: int, toy_id: String) -> void:
	await _pounce("attack" if toy_id == "yarn" else "jump", token)
	if token != _action_id:
		return
	_pouncing = false
	_pounce_cd = 1.2
	_loco(CLIP_IDLE)

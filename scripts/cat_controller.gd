# scripts/cat_controller.gd
## 2D pixel cat: public API matches the v0.2.6 3D controller.
extends Node2D

signal interaction_started(action: String)
signal interaction_ready
signal save_requested
signal cat_tapped
signal pet_stroke(duration: float)
signal action_finished(kind: String)

const CLIP_IDLE := "sit"
const CLIP_PET := "call"
const CLIP_FEED := "eat"
const CLIP_PLAY := "jump"

const WALK_SPEED := 56.0
const RUN_SPEED := 110.0
const ACCEL_TIME := 0.28
const BRAKE_TIME := 0.30
const STOP_DIST := 2.5
const TURN_TIME := 0.11
const TURN_ABOUT_TIME := 0.16
const SETTLE_TIME := 0.12
const FACE_HYST := 1.40
const FLOOR_MIN := Vector2(36, 100)
const FLOOR_MAX := Vector2(284, 196)
const SPRITE_OFFSET := Vector2(-32, -62)

const LINES_PET := ["呼噜～再摸摸", "嗯…好舒服呀", "贴贴～喜欢你", "轻轻的…再来一下"]
const LINES_PET_SWEET := ["只准你摸哦～", "心心都给你了", "再贴紧一点…", "你的手好暖呀"]
const LINES_FEED := ["喵，好吃！", "嚼嚼～谢谢你", "饱饱的，幸福", "今天也好好吃饭啦"]
const LINES_FEED_SWEET := ["你喂的最好吃", "为你多吃两口～", "吃饭也要想你"]
const LINES_PLAY := ["逗我！还要～", "跳！再玩一会儿", "呜哇，好开心", "陪我玩嘛～"]
const LINES_PLAY_SWEET := ["和你玩最开心", "一辈子都陪你跳", "扑进你怀里～"]
const LINES_BUSY := ["等一下下…", "喵？稍等我", "呼…缓一缓"]
const LINES_AUTO := ["自己玩一会儿～", "蹦！", "走走停停…", "晒晒太阳喵"]
const LINES_MILESTONE := {
	25: "亲密度提升～我更黏你了",
	50: "你是我的心肝宝贝呀",
	75: "房间也想为你打扮一下",
	100: "永远和你在一起，好不好",
}
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

@onready var anim: AnimatedSprite2D = $CatBody
@onready var stats: PetStats = $PetStats
@onready var tap_body: Area2D = $CatTapBody
@onready var feedback_label: Label = %FeedbackLabel
@onready var speech_bubble: Node = get_node_or_null("%SpeechBubble")

var action_phase: String = ""
var action_kind: String = ""
var _cooldown: float = 0.0
var _idle_clip: String = CLIP_IDLE
var _props: Array = []
var _autonomy_paused: bool = false
var _wander_target: Vector2 = Vector2.ZERO
var _wandering: bool = false
var _wander_speed: float = WALK_SPEED
var _blink_timer: float = 2.4
var _auto_timer: float = 3.5
var _auto_busy: bool = false
var _facing: String = "down"  # down, up, left, right
var _facing_right: bool = false
var _move_speed: float = 0.0
var _move_dir: Vector2 = Vector2.ZERO
var _turning: bool = false
var _turn_timer: float = 0.0
var _pending_facing: String = ""
var _settling: bool = false
var _settle_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _save_timer := 0.0
var _player: AudioStreamPlayer
var _bgm: AudioStreamPlayer
var _sfx_pet: AudioStream
var _sfx_feed: AudioStream
var _sfx_play: AudioStream
var _sfx_milestone: AudioStream
var has_anchor := false
var action_anchor := Vector2.ZERO

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.randomize()
	_setup_audio()
	if anim:
		anim.sprite_frames = PixelUtil.cat_frames()
		anim.centered = false
		anim.offset = SPRITE_OFFSET
		anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if not anim.animation_finished.is_connected(_on_anim_finished):
			anim.animation_finished.connect(_on_anim_finished)
		_play_idle()
	if stats and stats.has_signal("milestone_unlocked"):
		if not stats.milestone_unlocked.is_connected(_on_milestone):
			stats.milestone_unlocked.connect(_on_milestone)
	_blink_timer = _rng.randf_range(2.2, 4.8)
	call_deferred("_say", "来摸摸我吧～", false)

func can_interact() -> bool:
	return _cooldown <= 0.0

func is_busy_action() -> bool:
	return action_phase != ""

func set_autonomy_paused(paused: bool) -> void:
	_autonomy_paused = paused
	if paused and action_phase == "":
		if _wandering or _move_speed > 1.0:
			_wandering = false
			_begin_settle()
		else:
			_wandering = false

func get_focus_point() -> Vector2:
	return get_head_point()

func get_head_point() -> Vector2:
	match _facing:
		"up":
			return global_position + Vector2(0.0, -50.0)
		"left":
			return global_position + Vector2(-8.0, -48.0)
		"right":
			return global_position + Vector2(8.0, -48.0)
		_:
			return global_position + Vector2(0.0, -52.0)

func get_mouth_point() -> Vector2:
	# Mouth is above the paws in 2D (smaller y). Back view has no muzzle, use the nape.
	match _facing:
		"up":
			return global_position + Vector2(0.0, -40.0)
		"left":
			return global_position + Vector2(-12.0, -30.0)
		"right":
			return global_position + Vector2(12.0, -30.0)
		_:
			return global_position + Vector2(0.0, -30.0)

func do_pet() -> void:
	if not _begin("pet"):
		return
	_cancel_autonomy()
	if stats:
		stats.pet()
	_play_oneshot(CLIP_PET)
	pet_stroke.emit(maxf(_cooldown, 1.2))
	_say(_pick(_lines_for("pet")))
	_play_sfx(_sfx_pet)
	_apply_cosmetics_for_bond(stats.bond if stats else 0.0)
	save_requested.emit()

func do_feed(food_id: String = "") -> void:
	if not _begin("feed"):
		return
	if CatProps.FOODS.has(food_id):
		_run_feed(food_id)
		return
	_cancel_autonomy()
	if stats:
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
	if stats:
		stats.play()
	_play_oneshot(CLIP_PLAY)
	_say(_pick(_lines_for("play")))
	_play_sfx(_sfx_play)
	_apply_cosmetics_for_bond(stats.bond if stats else 0.0)
	save_requested.emit()

func _process(delta: float) -> void:
	var was_busy := _cooldown > 0.0
	if _cooldown > 0.0:
		_cooldown -= delta
		if was_busy and _cooldown <= 0.0:
			_cooldown = 0.0
			if action_phase == "":
				interaction_ready.emit()
	if stats:
		stats.tick(delta)
		_save_timer += delta
		if _save_timer >= 20.0:
			_save_timer = 0.0
			save_requested.emit()
	if action_phase != "":
		return
	if _wandering:
		_update_wander(delta)
		return
	if _settling:
		_tick_settle(delta)
		return
	_blink_timer -= delta
	if _blink_timer <= 0.0 and anim and String(anim.animation) in [CLIP_IDLE, "idle", "idle_down"]:
		_play("sit_blink")
		_blink_timer = _rng.randf_range(2.6, 5.2)
	if _cooldown > 0.0 or _autonomy_paused:
		return
	if _auto_busy:
		return
	_auto_timer -= delta
	if _auto_timer <= 0.0:
		_choose_autonomy()

func _physics_process(_delta: float) -> void:
	pass

func _begin(action: String) -> bool:
	if _cooldown > 0.0:
		_say(_pick(LINES_BUSY), true)
		return false
	interaction_started.emit(action)
	return true

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

func _pick(lines: Array) -> String:
	if lines.is_empty():
		return ""
	return str(lines[_rng.randi_range(0, lines.size() - 1)])

func _say(t: String, soft: bool = true) -> void:
	if speech_bubble and speech_bubble.has_method("show_line"):
		speech_bubble.show_line(t, soft)
		return
	if feedback_label == null:
		return
	feedback_label.text = t

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
	elif bgm_stream:
		_bgm.stream = bgm_stream
	if _bgm.stream:
		_bgm.play()

func _play_sfx(stream: AudioStream) -> void:
	if _player and stream:
		_player.stream = stream
		_player.play()

func _apply_cosmetics_for_bond(_bond: float) -> void:
	pass

func _play(name: String) -> void:
	if anim == null:
		return
	if anim.has_method("has_animation") and anim.has_animation(name):
		anim.play(name)
	elif anim.sprite_frames and anim.sprite_frames.has_animation(name):
		anim.play(name)
	elif anim.sprite_frames and anim.sprite_frames.has_animation(CLIP_IDLE):
		anim.play(CLIP_IDLE)
	_apply_flip()

func _idle_clip_for_facing() -> String:
	match _facing:
		"up":
			return "idle_up"
		"left", "right":
			return "idle_side"
		_:
			return "idle_down"

func _walk_clip(fast: bool) -> String:
	var prefix := "run" if fast else "walk"
	match _facing:
		"up":
			return prefix + "_up"
		"left", "right":
			return prefix + "_side"
		_:
			return prefix + "_down"

func _apply_flip() -> void:
	if anim == null:
		return
	# Only flip the side sheet. Never flip front/back.
	var clip := String(anim.animation)
	var is_side := clip.ends_with("_side") or clip == "sit_side" or clip == "walk" or clip == "run"
	anim.flip_h = is_side and _facing == "left"

func _play_locomotion(fast: bool) -> void:
	var clip := _walk_clip(fast)
	if not _turning:
		if anim == null or String(anim.animation) != clip:
			_play(clip)
	_apply_flip()
	if anim:
		var cruise := RUN_SPEED if fast else WALK_SPEED
		anim.speed_scale = clampf(_move_speed / maxf(cruise, 1.0), 0.35, 1.15)

func _play_idle() -> void:
	_settling = false
	_turning = false
	_pending_facing = ""
	_move_speed = 0.0
	_idle_clip = _idle_clip_for_facing()
	if anim:
		anim.speed_scale = 1.0
	_play(_idle_clip)
	_apply_flip()

func _play_oneshot(clip: String) -> void:
	_play(clip)
	var length := PixelUtil.anim_len(anim, clip)
	_cooldown = clampf(length * 0.75, 0.7, 1.35)

func _on_anim_finished(_anim_name: StringName = &"") -> void:
	if action_phase != "" or _wandering:
		return
	if _auto_busy:
		_auto_busy = false
		_play_idle()
		_auto_timer = _rng.randf_range(1.5, 3.2)
		return
	_play_idle()

func _cancel_autonomy() -> void:
	_wandering = false
	_auto_busy = false
	_settling = false
	_turning = false
	_pending_facing = ""

func _choose_autonomy() -> void:
	_auto_timer = _rng.randf_range(1.5, 3.5)
	_idle_clip = CLIP_IDLE
	var roll := _rng.randi_range(0, 9)
	if roll <= 5:
		_start_wander()
	elif roll == 6:
		_play("happy")
		_auto_busy = true
		_say(_pick(LINES_AUTO), true)
	elif roll == 7:
		_play("sleep")
		_idle_clip = "sleep"
		_auto_timer = _rng.randf_range(6.0, 10.0)
	elif roll == 8:
		_play("call")
		_auto_busy = true
		_say(_pick(LINES_AUTO), true)
	else:
		_start_wander()

func _start_wander(target = null) -> void:
	var dest := Vector2.ZERO
	if target is Vector2:
		dest = target
	elif target is Vector3:
		# Map legacy 3D (x, z) into the pixel floor.
		var t3: Vector3 = target
		var nx := inverse_lerp(-2.3, 2.3, t3.x)
		var ny := inverse_lerp(-1.55, 1.55, t3.z)
		dest = Vector2(lerp(FLOOR_MIN.x, FLOOR_MAX.x, nx), lerp(FLOOR_MIN.y, FLOOR_MAX.y, ny))
	else:
		dest = _random_floor()
	dest = _clamp_floor(dest)
	if dest.distance_to(position) <= STOP_DIST:
		return
	_wander_target = dest
	_wandering = true
	_settling = false
	_wander_speed = WALK_SPEED if _rng.randf() > 0.25 else RUN_SPEED

func _update_wander(delta: float) -> void:
	if not _wandering:
		return
	if _locomote_step(_wander_target, _wander_speed, delta):
		_wandering = false
		_begin_settle()
		_auto_timer = _rng.randf_range(1.2, 2.8)

func _walk_to(dest: Vector2, speed: float) -> void:
	dest = _clamp_floor(dest)
	var frames := 0
	while is_inside_tree() and frames < 720:
		var dt := get_process_delta_time()
		# Headless / script smokes can emit tiny deltas; keep motion moving.
		if dt < 0.008:
			dt = 0.016 * maxf(Engine.time_scale, 1.0)
		if _locomote_step(dest, speed, dt):
			break
		frames += 1
		await get_tree().process_frame
	if is_inside_tree():
		await _await_settle()

func _locomote_step(dest: Vector2, cruise: float, delta: float) -> bool:
	# Returns true once the cat has arrived and is nearly still. Never teleports.
	var to := dest - position
	var dist := to.length()
	var accel := maxf(cruise / ACCEL_TIME, 160.0)
	var decel := maxf(cruise / BRAKE_TIME, 150.0)
	var brake := (_move_speed * _move_speed) / (2.0 * decel) + STOP_DIST
	var want := 0.0 if dist <= brake else cruise
	if _move_speed < want:
		_move_speed = minf(want, _move_speed + accel * delta)
	else:
		_move_speed = maxf(want, _move_speed - decel * delta)
	if dist <= STOP_DIST and _move_speed <= 8.0:
		if dist > 0.01:
			position = dest
		_move_speed = 0.0
		return true
	if dist > 0.001:
		_move_dir = to.normalized()
		position += _move_dir * minf(_move_speed * delta, dist)
	_queue_face(_move_dir)
	_tick_turn(delta)
	_play_locomotion(cruise > WALK_SPEED + 1.0)
	return false

func _queue_face(dir: Vector2) -> void:
	var next := _facing_from_dir(dir)
	if next == "":
		return
	if next == _facing:
		if not _turning:
			_pending_facing = ""
		return
	if _turning and _pending_facing == next:
		return
	_pending_facing = next
	_turning = true
	var about := (_facing == "left" and next == "right") or (_facing == "right" and next == "left") or (_facing == "up" and next == "down") or (_facing == "down" and next == "up")
	_turn_timer = TURN_ABOUT_TIME if about else TURN_TIME

func _tick_turn(delta: float) -> void:
	if not _turning:
		return
	_turn_timer -= delta
	if _turn_timer <= 0.0 and _pending_facing != "":
		_facing = _pending_facing
		_facing_right = _facing == "right"
		_turning = false
		_pending_facing = ""
		_apply_flip()

func _begin_settle() -> void:
	_settling = true
	_settle_timer = SETTLE_TIME
	_turning = false
	_pending_facing = ""
	if anim:
		anim.speed_scale = 0.4

func _tick_settle(delta: float) -> void:
	_settle_timer -= delta
	if _settle_timer <= 0.0:
		_play_idle()

func _await_settle() -> void:
	_begin_settle()
	var t0 := Time.get_ticks_msec()
	while is_inside_tree() and _settling and (Time.get_ticks_msec() - t0) / 1000.0 < 0.6:
		var dt := get_process_delta_time()
		if dt < 0.008:
			dt = 0.016 * maxf(Engine.time_scale, 1.0)
		_tick_settle(dt)
		await get_tree().process_frame

func _facing_from_dir(dir: Vector2) -> String:
	if dir.length() <= 0.4:
		return ""
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	var next := _facing
	# Stronger hysteresis: only change facing when the new axis is clearly dominant.
	if ay > ax * FACE_HYST:
		next = "down" if dir.y > 0.0 else "up"
	elif ax > ay * FACE_HYST:
		next = "right" if dir.x >= 0.0 else "left"
	else:
		var vert := "down" if dir.y > 0.0 else "up"
		var horz := "right" if dir.x >= 0.0 else "left"
		if _facing == vert or _facing == horz:
			next = _facing
		else:
			next = vert if ay >= ax else horz
	return next

func _face_dir(dir: Vector2) -> void:
	# Public/instant facing for tools and look-at; locomotion uses _queue_face.
	var next := _facing_from_dir(dir)
	if next == "":
		return
	_facing = next
	_facing_right = _facing == "right"
	_turning = false
	_pending_facing = ""
	_apply_flip()

func _face_point(p: Vector2) -> void:
	_face_dir(p - global_position)

func _random_floor() -> Vector2:
	for _i in 8:
		var p := Vector2(_rng.randf_range(FLOOR_MIN.x, FLOOR_MAX.x), _rng.randf_range(FLOOR_MIN.y, FLOOR_MAX.y))
		p = _clamp_floor(p)
		if p.distance_to(position) > 24.0:
			return p
	return _clamp_floor(Vector2(160, 150))

func _clamp_floor(p: Vector2) -> Vector2:
	p.x = clampf(p.x, FLOOR_MIN.x, FLOOR_MAX.x)
	p.y = clampf(p.y, FLOOR_MIN.y, FLOOR_MAX.y)
	if p.x < 70.0 and p.y > 166.0:
		p.x = 70.0
	if p.x > 260.0 and p.y > 154.0:
		p.x = 260.0
	return p

func _approach_point(target: Vector2) -> Vector2:
	var p := target + Vector2(-18.0 if target.x > position.x else 18.0, 2.0)
	return _clamp_floor(p)

func _place_food(item_id: String) -> Node2D:
	var n := CatProps.make_food_2d(item_id)
	_add_prop(n, _prop_drop())
	return n

func _place_toy(item_id: String) -> Node2D:
	var n := CatProps.make_toy_2d(item_id)
	_add_prop(n, _prop_drop())
	return n

func _prop_drop() -> Vector2:
	var off := Vector2(0.0, 16.0)
	match _facing:
		"up":
			off = Vector2(0.0, -18.0)
		"left":
			off = Vector2(-28.0, 4.0)
		"right":
			off = Vector2(28.0, 4.0)
		_:
			off = Vector2(0.0, 16.0)
	return _clamp_floor(position + off)

func _add_prop(n: Node2D, pos: Vector2) -> void:
	var holder := get_parent()
	if holder and holder.has_node("PropsHolder"):
		holder.get_node("PropsHolder").add_child(n)
	elif holder:
		holder.add_child(n)
	else:
		add_child(n)
	n.global_position = pos
	n.scale = Vector2(0.01, 0.01)
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_props.append(n)

func _cleanup_props() -> void:
	for n in _props:
		if is_instance_valid(n):
			var tw := create_tween()
			tw.tween_property(n, "scale", Vector2(0.01, 0.01), 0.18)
			tw.tween_callback(n.queue_free)
	_props.clear()

func _run_feed(food_id: String) -> void:
	_cancel_autonomy()
	_cooldown = 999.0
	action_kind = "feed"
	action_phase = "walk"
	var spec: Dictionary = CatProps.FOODS[food_id]
	var lines: Dictionary = FOOD_LINES[food_id]
	var dish := _place_food(food_id)
	_say(_pick(lines["start"]), true)
	_play_sfx(_sfx_feed)
	await _walk_to(_approach_point(dish.global_position), WALK_SPEED)
	if not is_inside_tree():
		return
	_face_point(dish.global_position)
	action_phase = "eat"
	_play(CLIP_FEED)
	if anim and anim.sprite_frames:
		anim.sprite_frames.set_animation_loop(CLIP_FEED, true)
	if stats:
		stats.feed_with(float(spec["hunger"]), float(spec["mood"]))
	_say(_pick(lines["eat"]), true)
	await get_tree().create_timer(PixelUtil.anim_len(anim, CLIP_FEED) * 2.0).timeout
	if anim and anim.sprite_frames:
		anim.sprite_frames.set_animation_loop(CLIP_FEED, false)
	_play("happy")
	await get_tree().create_timer(0.45).timeout
	_cleanup_props()
	_finish_sequence("feed")

func _run_play(toy_id: String) -> void:
	_cancel_autonomy()
	_cooldown = 999.0
	action_kind = "play"
	action_phase = toy_id
	var spec: Dictionary = CatProps.TOYS[toy_id]
	var lines: Dictionary = TOY_LINES[toy_id]
	if stats:
		stats.play_with(float(spec["mood"]), float(spec["bond"]), float(spec["hunger"]))
	var toy := _place_toy(toy_id)
	_say(_pick(lines["start"]), true)
	_play_sfx(_sfx_play)
	match toy_id:
		"wand":
			await _play_wand(toy)
		"yarn":
			await _play_yarn(toy)
		"laser":
			await _play_laser(toy)
		"mouse":
			await _play_mouse(toy)
		_:
			await _play_yarn(toy)
	if not is_inside_tree():
		return
	_say(_pick(lines["end"]), true)
	_cleanup_props()
	_play("happy")
	_apply_cosmetics_for_bond(stats.bond if stats else 0.0)
	await get_tree().create_timer(0.4).timeout
	_finish_sequence("play")

func _finish_sequence(kind: String) -> void:
	action_phase = ""
	action_kind = ""
	_cooldown = 0.0
	_play_idle()
	action_finished.emit(kind)
	interaction_ready.emit()
	save_requested.emit()
	_auto_timer = _rng.randf_range(2.0, 4.0)

func _play_wand(toy: Node2D) -> void:
	var base := toy.global_position
	for i in 3:
		var hop := base + Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-6, 6))
		toy.global_position = hop
		await _walk_to(_approach_point(hop), RUN_SPEED)
		_play(CLIP_PLAY)
		await get_tree().create_timer(PixelUtil.anim_len(anim, CLIP_PLAY)).timeout

func _play_yarn(toy: Node2D) -> void:
	var center := toy.global_position
	var spr := toy.get_node_or_null("Sprite")
	for i in 6:
		var ang := float(i) / 8.0 * TAU
		var p := center + Vector2(cos(ang), sin(ang) * 0.55) * 26.0
		if spr:
			spr.rotation = ang
		await _walk_to(_approach_point(p), WALK_SPEED)

func _play_laser(toy: Node2D) -> void:
	for i in 4:
		var p := _random_floor()
		toy.global_position = p
		await _walk_to(p, RUN_SPEED)
		_play(CLIP_PLAY)
		await get_tree().create_timer(0.28).timeout

func _play_mouse(toy: Node2D) -> void:
	var start := toy.global_position
	for i in 3:
		var scurries := _clamp_floor(start + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-16, 16)))
		var t := 0.0
		var from := toy.global_position
		while t < 0.35 and is_inside_tree():
			var dt := get_process_delta_time()
			if dt < 0.008:
				dt = 0.016 * maxf(Engine.time_scale, 1.0)
			t += dt
			toy.global_position = from.lerp(scurries, clampf(t / 0.35, 0.0, 1.0))
			await get_tree().process_frame
		await _walk_to(_approach_point(toy.global_position), RUN_SPEED)
		_play(CLIP_PLAY)
		await get_tree().create_timer(PixelUtil.anim_len(anim, CLIP_PLAY) * 0.7).timeout
		start = toy.global_position

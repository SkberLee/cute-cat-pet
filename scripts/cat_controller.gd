# scripts/cat_controller.gd
extends Node3D

signal interaction_started(action: String)
signal interaction_ready

@onready var stats: PetStats = %PetStats
@onready var body: Node3D = %CatBody
@onready var feedback_label: Label = %FeedbackLabel

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
const LINES_FEED := [
	"喵，好吃！",
	"嚼嚼～谢谢你",
	"饱饱的，幸福",
	"今天也好好吃饭啦",
]
const LINES_PLAY := [
	"逗我！还要～",
	"跳！再玩一会儿",
	"呜哇，好开心",
	"陪我玩嘛～",
]
const LINES_BUSY := [
	"等一下下…",
	"喵？稍等我",
	"呼…缓一缓",
]

var anim: AnimationPlayer
var _cooldown := 0.0
var _idle_clip := CLIP_IDLE
var _rng := RandomNumberGenerator.new()
var _sfx_pet: AudioStream
var _sfx_feed: AudioStream
var _sfx_play: AudioStream
var _player: AudioStreamPlayer

func _ready() -> void:
	_rng.randomize()
	_setup_audio()
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
	_say("来摸摸我吧～", false)

func _process(delta: float) -> void:
	var was_busy := _cooldown > 0.0
	if _cooldown > 0.0:
		_cooldown -= delta
		if was_busy and _cooldown <= 0.0:
			_cooldown = 0.0
			interaction_ready.emit()
	if stats:
		stats.tick(delta)

func can_interact() -> bool:
	return _cooldown <= 0.0

func do_pet() -> void:
	if not _begin("pet"):
		return
	stats.pet()
	_play_oneshot(CLIP_PET)
	_say(_pick(LINES_PET))
	_play_sfx(_sfx_pet)

func do_feed() -> void:
	if not _begin("feed"):
		return
	stats.feed()
	_play_oneshot(CLIP_FEED)
	_say(_pick(LINES_FEED))
	_play_sfx(_sfx_feed)

func do_play() -> void:
	if not _begin("play"):
		return
	stats.play()
	_play_oneshot(CLIP_PLAY)
	_say(_pick(LINES_PLAY))
	_play_sfx(_sfx_play)

func _begin(action: String) -> bool:
	if _cooldown > 0.0:
		_say(_pick(LINES_BUSY), true)
		return false
	interaction_started.emit(action)
	return true

func _pick(lines: Array) -> String:
	return lines[_rng.randi_range(0, lines.size() - 1)]

func _say(t: String, soft: bool = true) -> void:
	if feedback_label == null:
		return
	feedback_label.text = t
	if not soft:
		feedback_label.modulate.a = 1.0
		return
	feedback_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(feedback_label, "modulate:a", 1.0, 0.18)

func _setup_audio() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "SoftSfx"
	_player.volume_db = -6.0
	add_child(_player)
	_sfx_pet = load("res://assets/sfx/pet.wav")
	_sfx_feed = load("res://assets/sfx/feed.wav")
	_sfx_play = load("res://assets/sfx/play.wav")

func _play_sfx(stream: AudioStream) -> void:
	if _player == null or stream == null:
		return
	_player.stream = stream
	_player.pitch_scale = _rng.randf_range(0.96, 1.05)
	_player.play()

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
		_cooldown = 0.85
		return
	anim.play(clip)
	var length := anim.current_animation_length
	# Slightly snappier than full clip length so buttons feel responsive.
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
	_play_idle()

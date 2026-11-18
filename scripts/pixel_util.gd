# scripts/pixel_util.gd
class_name PixelUtil
extends RefCounted

const FONT_PATH := "res://assets/fonts/NotoSansCJK-Regular.ttc"
const NEAREST := CanvasItem.TEXTURE_FILTER_NEAREST

static func tex(path: String) -> Texture2D:
	var t := load(path) as Texture2D
	return t

static func apply_nearest(node: CanvasItem) -> void:
	if node:
		node.texture_filter = NEAREST

static func font() -> Font:
	var f := load(FONT_PATH)
	if f is Font:
		return f
	return ThemeDB.fallback_font

## v0.3 cat set: [png prefix, frame count, fps, loop]. Aliases keep the old clip names.
const CAT_CLIPS := {
	"walk_side": ["walk_side", 8, 10.0, true],
	"walk_down": ["walk_down", 8, 10.0, true],
	"walk_up": ["walk_up", 8, 10.0, true],
	"run_side": ["walk_side", 8, 15.0, true],
	"run_down": ["walk_down", 8, 15.0, true],
	"run_up": ["walk_up", 8, 15.0, true],
	"walk": ["walk_side", 8, 10.0, true],
	"run": ["walk_side", 8, 15.0, true],
	"idle_down": ["idle_down", 16, 6.0, true],
	"idle_up": ["idle_up", 16, 6.0, true],
	"idle_side": ["idle_side", 16, 6.0, true],
	"sit": ["sit", 4, 3.0, true],
	"idle": ["sit", 4, 3.0, true],
	"sit_blink": ["sit_blink", 3, 10.0, false],
	"sit_side": ["sit_side", 4, 3.0, true],
	"sit_up": ["sit_up", 4, 3.0, true],
	"eat_side": ["eat_side", 6, 7.0, false],
	"eat": ["eat_side", 6, 7.0, false],
	"happy": ["happy", 4, 6.0, true],
	"idle_alt": ["happy", 4, 6.0, false],
	"call": ["call", 4, 5.0, true],
	"play_side": ["play_side", 8, 11.0, false],
	"attack": ["play_side", 8, 11.0, false],
	"play_down": ["play_down", 6, 10.0, false],
	"jump": ["play_down", 6, 10.0, false],
	"sleep": ["sleep", 4, 2.0, true],
}
## Chewing loop = eat_side frames 2..5 (head already down in the bowl).
const CHEW_FRAMES := [2, 3, 4, 5]

static func cat_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	for clip in CAT_CLIPS.keys():
		var spec: Array = CAT_CLIPS[clip]
		var paths: Array = []
		for i in int(spec[1]):
			paths.append("res://assets/pixel/cat/%s_%d.png" % [spec[0], i])
		_add(sf, clip, paths, float(spec[2]), bool(spec[3]))
	var chew: Array = []
	for i in CHEW_FRAMES:
		chew.append("res://assets/pixel/cat/eat_side_%d.png" % i)
	_add(sf, "chew_side", chew, 7.0, true)
	return sf

static func _add(sf: SpriteFrames, name: String, paths: Array, fps: float, loop: bool) -> void:
	if sf.has_animation(name):
		sf.clear(name)
	else:
		sf.add_animation(name)
	sf.set_animation_speed(name, fps)
	sf.set_animation_loop(name, loop)
	for p in paths:
		var t := tex(str(p))
		if t:
			sf.add_frame(name, t)

static func anim_len(anim: AnimatedSprite2D, name: String) -> float:
	if anim == null or anim.sprite_frames == null or not anim.sprite_frames.has_animation(name):
		return 0.8
	var n := anim.sprite_frames.get_frame_count(name)
	var fps := anim.sprite_frames.get_animation_speed(name)
	return maxf(float(n) / maxf(fps, 1.0), 0.35)

static func sprite(path: String, centered := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(path)
	s.centered = centered
	s.texture_filter = NEAREST
	return s

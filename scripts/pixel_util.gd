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

static func cat_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	_add(sf, "sit", ["res://assets/pixel/cat/sit.png"], 1.0, true)
	_add(sf, "idle", ["res://assets/pixel/cat/sit.png"], 1.0, true)
	_add(sf, "idle_down", ["res://assets/pixel/cat/idle_down_0.png", "res://assets/pixel/cat/idle_down_1.png"], 2.0, true)
	_add(sf, "sit_blink", ["res://assets/pixel/cat/sit_blink.png"], 6.0, false)
	_add(sf, "call", ["res://assets/pixel/cat/call.png"], 4.0, false)
	_add(sf, "happy", ["res://assets/pixel/cat/happy.png"], 4.0, true)
	_add(sf, "idle_alt", ["res://assets/pixel/cat/happy.png"], 4.0, false)
	_add(sf, "sleep", ["res://assets/pixel/cat/sleep.png"], 2.0, true)
	_add(sf, "sit_side", ["res://assets/pixel/cat/sit_side.png"], 1.0, true)
	_add(sf, "idle_side", ["res://assets/pixel/cat/idle_side_0.png", "res://assets/pixel/cat/idle_side_1.png"], 2.0, true)
	_add(sf, "sit_up", ["res://assets/pixel/cat/sit_up.png"], 1.0, true)
	_add(sf, "idle_up", ["res://assets/pixel/cat/idle_up_0.png", "res://assets/pixel/cat/idle_up_1.png"], 2.0, true)
	var side := [
		"res://assets/pixel/cat/walk_side_0.png",
		"res://assets/pixel/cat/walk_side_1.png",
		"res://assets/pixel/cat/walk_side_2.png",
		"res://assets/pixel/cat/walk_side_3.png",
		"res://assets/pixel/cat/walk_side_4.png",
		"res://assets/pixel/cat/walk_side_5.png",
		"res://assets/pixel/cat/walk_side_6.png",
		"res://assets/pixel/cat/walk_side_7.png",
	]
	var down := [
		"res://assets/pixel/cat/walk_down_0.png",
		"res://assets/pixel/cat/walk_down_1.png",
		"res://assets/pixel/cat/walk_down_2.png",
		"res://assets/pixel/cat/walk_down_3.png",
		"res://assets/pixel/cat/walk_down_4.png",
		"res://assets/pixel/cat/walk_down_5.png",
		"res://assets/pixel/cat/walk_down_6.png",
		"res://assets/pixel/cat/walk_down_7.png",
	]
	var up := [
		"res://assets/pixel/cat/walk_up_0.png",
		"res://assets/pixel/cat/walk_up_1.png",
		"res://assets/pixel/cat/walk_up_2.png",
		"res://assets/pixel/cat/walk_up_3.png",
		"res://assets/pixel/cat/walk_up_4.png",
		"res://assets/pixel/cat/walk_up_5.png",
		"res://assets/pixel/cat/walk_up_6.png",
		"res://assets/pixel/cat/walk_up_7.png",
	]
	_add(sf, "walk", side, 10.0, true)
	_add(sf, "walk_side", side, 10.0, true)
	_add(sf, "walk_down", down, 10.0, true)
	_add(sf, "walk_up", up, 10.0, true)
	_add(sf, "run", side, 15.0, true)
	_add(sf, "run_side", side, 15.0, true)
	_add(sf, "run_down", down, 15.0, true)
	_add(sf, "run_up", up, 15.0, true)
	_add(sf, "eat", [
		"res://assets/pixel/cat/eat_0.png",
		"res://assets/pixel/cat/eat_1.png",
		"res://assets/pixel/cat/eat_2.png",
		"res://assets/pixel/cat/eat_3.png",
	], 6.0, false)
	_add(sf, "jump", [
		"res://assets/pixel/cat/jump_0.png",
		"res://assets/pixel/cat/jump_1.png",
		"res://assets/pixel/cat/jump_2.png",
		"res://assets/pixel/cat/jump_3.png",
	], 8.0, false)
	_add(sf, "attack", [
		"res://assets/pixel/cat/jump_1.png",
		"res://assets/pixel/cat/jump_2.png",
		"res://assets/pixel/cat/jump_3.png",
		"res://assets/pixel/cat/jump_0.png",
	], 9.0, false)
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

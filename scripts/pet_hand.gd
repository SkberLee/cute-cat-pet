# scripts/pet_hand.gd
class_name PetHand
extends Control

## 48px pixel palm that strokes the cat from forehead to nape in canvas space.

const HAND_PATH := "res://assets/pixel/fx/hand_48.png"
const HEART_PATH := "res://assets/pixel/fx/heart.png"

var _camera: Camera2D
var _cat: Node2D
var _playing := false
var _elapsed := 0.0
var _duration := 0.9
var _hand: TextureRect
var _hearts: Array[TextureRect] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hand = TextureRect.new()
	_hand.texture = PixelUtil.tex(HAND_PATH)
	_hand.stretch_mode = TextureRect.STRETCH_KEEP
	_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.visible = false
	_hand.size = Vector2(48, 48)
	add_child(_hand)
	for i in 3:
		var h := TextureRect.new()
		h.texture = PixelUtil.tex(HEART_PATH)
		h.stretch_mode = TextureRect.STRETCH_KEEP
		h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.visible = false
		h.size = Vector2(16, 16)
		add_child(h)
		_hearts.append(h)

func setup(camera, cat) -> void:
	if camera is Camera2D:
		_camera = camera
	_cat = cat as Node2D

func play(duration: float = 0.9) -> void:
	_duration = maxf(duration, 0.55)
	_elapsed = 0.0
	_playing = true
	visible = true
	if _hand:
		_hand.visible = true
	for h in _hearts:
		h.visible = false

func is_playing() -> bool:
	return _playing

func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	_place(t)
	if t >= 1.0:
		_playing = false
		if _hand:
			_hand.visible = false
		for h in _hearts:
			h.visible = false

func _head_canvas() -> Vector2:
	if _cat == null:
		return Vector2.ZERO
	var p: Vector2
	if _cat.has_method("get_head_point"):
		p = _cat.get_head_point()
	else:
		p = _cat.global_position + Vector2(0, -42)
	return _cat.get_canvas_transform() * p

func _world_scale() -> float:
	if _cat == null:
		return 2.25
	return maxf(_cat.get_canvas_transform().x.length(), 0.5)

func _place(t: float) -> void:
	var head := _head_canvas()
	var s := _world_scale()
	# Hand ~20 world px wide whatever the camera zoom, so it reads as a hand on the head.
	var k := clampf(24.0 * s / 48.0, 0.6, 3.0)
	# Two slow strokes: forehead (above head) down toward the nape.
	var cycle := fmod(t * 2.0, 1.0)
	var stroke := 1.0 - absf(cycle * 2.0 - 1.0)
	var start := head + Vector2(3.0, -14.0) * s
	var finish := head + Vector2(-1.0, -6.0) * s
	var pos := start.lerp(finish, stroke)
	if _hand:
		_hand.pivot_offset = Vector2(16, 28)
		_hand.scale = Vector2(k, k)
		_hand.position = pos - Vector2(16, 28)
		_hand.rotation_degrees = lerp(-18.0, 12.0, stroke)
		_hand.modulate.a = 1.0 if t < 0.9 else (1.0 - (t - 0.9) / 0.1)
	# Tiny hearts float up near the end of the first stroke.
	for i in _hearts.size():
		var ht := clampf((_elapsed - 0.15 - i * 0.12) / 0.55, 0.0, 1.0)
		var h: TextureRect = _hearts[i]
		if ht <= 0.0 or ht >= 1.0:
			h.visible = false
			continue
		h.visible = true
		h.scale = Vector2(k, k) * 0.8
		h.position = head + Vector2(-9.0 + i * 8.0, -16.0 - ht * 12.0) * s
		h.modulate.a = 1.0 - ht

func _draw() -> void:
	# Kept so older smokes that look for a Control overlay still find a node.
	pass

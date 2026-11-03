# scripts/speech_bubble.gd
extends Control
class_name SpeechBubble

## World-anchored cute speech bubble that follows the cat muzzle (3D→2D).

const HOLD_SEC := 2.75
const FADE_IN := 0.18
const FADE_OUT := 0.22

@onready var panel: PanelContainer = $Panel
@onready var label: Label = %FeedbackLabel
@onready var tail: Polygon2D = $Tail

var _camera: Camera3D
var _cat: Node3D
var _tween: Tween
var _hold := -1.0
var _showing := false
var _portrait := false
var _font_size := 30
var _max_w := 480.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	_style_panel()
	if label:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if tail:
		tail.color = Color(1.0, 0.96, 0.94, 1.0)
		tail.z_index = 1

func setup(camera: Camera3D, cat: Node3D) -> void:
	_camera = camera
	_cat = cat

func _ensure_refs() -> void:
	if _camera == null:
		_camera = get_viewport().get_camera_3d() if get_viewport() else null
	if _cat == null:
		_cat = get_tree().root.find_child("Cat", true, false) as Node3D

func set_metrics(font_size: int, max_width: float) -> void:
	_font_size = font_size
	_max_w = max_width
	if label:
		label.add_theme_font_size_override("font_size", font_size)
	if _showing:
		_update_follow()

func set_portrait(portrait: bool) -> void:
	set_metrics(34 if portrait else 30, 540.0 if portrait else 480.0)

func show_line(text: String, soft: bool = true) -> void:
	if label == null:
		return
	_ensure_refs()
	label.text = text
	_showing = true
	visible = true
	_hold = HOLD_SEC
	_update_follow()
	if _tween and _tween.is_valid():
		_tween.kill()
	if soft:
		modulate.a = 0.0
		scale = Vector2(0.86, 0.86)
		_tween = create_tween()
		_tween.set_parallel(true)
		_tween.tween_property(self, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector2.ONE, FADE_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		modulate.a = 1.0
		scale = Vector2.ONE

func _process(delta: float) -> void:
	if not _showing:
		return
	_update_follow()
	if _hold < 0.0:
		return
	_hold -= delta
	if _hold <= 0.0:
		_hold = -1.0
		_fade_out()

func _fade_out() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func ():
		_showing = false
		visible = false
	)

func _style_panel() -> void:
	if panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.96, 0.94, 0.98)
	sb.corner_radius_top_left = 30
	sb.corner_radius_top_right = 30
	sb.corner_radius_bottom_left = 30
	sb.corner_radius_bottom_right = 30
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.92, 0.72, 0.76, 0.85)
	sb.shadow_color = Color(0.45, 0.28, 0.32, 0.16)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", sb)

func _mouth_world() -> Vector3:
	if _cat and _cat.has_method("get_mouth_point"):
		return _cat.get_mouth_point()
	if _cat:
		return _cat.global_position + Vector3(0.0, 0.5, 0.2)
	return Vector3.ZERO

func _update_follow() -> void:
	_ensure_refs()
	if _camera == null or _cat == null or panel == null or label == null:
		return
	var mouth := _mouth_world()
	if _camera.is_position_behind(mouth):
		return
	# Camera3D.unproject_position returns coordinates in the viewport's visible
	# rect, i.e. the same stretched canvas space the UI is laid out in.
	var tip: Vector2 = _camera.unproject_position(mouth)
	var vp := get_viewport().get_visible_rect().size
	var font := label.get_theme_font("font")
	var pad_x := 26.0
	var pad_y := 16.0
	var max_text_w := maxf(_max_w - pad_x * 2.0, 120.0)
	var one_line := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size)
	var text_w := minf(one_line.x + 4.0, max_text_w)
	var text_sz := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, text_w, _font_size)
	text_sz.x = maxf(text_sz.x, 1.0)
	label.custom_minimum_size = Vector2(text_sz.x, text_sz.y)
	var bw := maxf(text_sz.x + pad_x * 2.0 + 8.0, 150.0)
	var bh := text_sz.y + pad_y * 2.0 + 6.0
	bh = maxf(bh, 70.0)
	panel.position = Vector2.ZERO
	panel.size = Vector2(bw, bh)
	size = Vector2(bw, bh)
	# Project a head-sized offset to pixels so the bubble clears the cat's eyes.
	var right := _camera.global_transform.basis.x
	var head_r := absf(_camera.unproject_position(mouth + right * 0.3).x - tip.x)
	head_r = clampf(head_r, 40.0, 260.0)
	var margin := 12.0
	var left := 0.0
	var top := 0.0
	var placed := false
	# 1) beside the head (right first, then left), bottom edge near mouth level.
	for side in [1.0, -1.0]:
		var l: float = tip.x + head_r * 0.85 if side > 0.0 else tip.x - head_r * 0.85 - bw
		if l >= margin and l + bw <= vp.x - margin:
			left = l
			top = tip.y - bh * 0.55
			placed = true
			break
	# 2) otherwise below the mouth (chest area, never covers the eyes).
	if not placed:
		left = tip.x - bw * 0.5
		top = tip.y + head_r * 0.55 + 14.0
	left = clampf(left, margin, maxf(margin, vp.x - bw - margin))
	top = clampf(top, margin, maxf(margin, vp.y - bh - margin))
	position = Vector2(left, top)
	# Tail: base on the bubble edge nearest the mouth, tip exactly on the mouth.
	var tip_local := tip - position
	if tail:
		tail.position = Vector2.ZERO
		var pts := PackedVector2Array()
		if tip_local.y > bh:
			var bx := clampf(tip_local.x, 34.0, bw - 34.0)
			pts = PackedVector2Array([Vector2(bx - 16.0, bh - 3.0), Vector2(bx + 16.0, bh - 3.0), tip_local])
		elif tip_local.y < 0.0:
			var bx2 := clampf(tip_local.x, 34.0, bw - 34.0)
			pts = PackedVector2Array([Vector2(bx2 - 16.0, 3.0), Vector2(bx2 + 16.0, 3.0), tip_local])
		else:
			var ex := 3.0 if tip_local.x < bw * 0.5 else bw - 3.0
			var ey := clampf(tip_local.y, 30.0, bh - 30.0)
			pts = PackedVector2Array([Vector2(ex, ey - 16.0), Vector2(ex, ey + 16.0), tip_local])
		tail.polygon = pts
	pivot_offset = tip_local

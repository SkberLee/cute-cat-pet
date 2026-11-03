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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	_style_panel()
	if label:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if tail:
		tail.color = Color(1.0, 0.96, 0.94, 1.0)
		tail.polygon = PackedVector2Array([
			Vector2(-10, 0),
			Vector2(10, 0),
			Vector2(0, 14),
		])

func setup(camera: Camera3D, cat: Node3D) -> void:
	_camera = camera
	_cat = cat

func _ensure_refs() -> void:
	if _camera == null:
		_camera = get_viewport().get_camera_3d() if get_viewport() else null
	if _cat == null:
		_cat = get_tree().root.find_child("Cat", true, false) as Node3D

func set_portrait(portrait: bool) -> void:
	_portrait = portrait
	if label:
		label.add_theme_font_size_override("font_size", 20 if portrait else 22)

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
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.92, 0.72, 0.76, 0.85)
	sb.shadow_color = Color(0.45, 0.28, 0.32, 0.16)
	sb.shadow_size = 6
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
	if _camera == null or _cat == null:
		return
	var mouth := _mouth_world()
	if _camera.is_position_behind(mouth):
		# Keep last on-screen spot; still fade on timer.
		return
	var screen: Vector2 = _camera.unproject_position(mouth)
	# Preferred: bubble sits above muzzle; tail tip points at mouth.
	var max_w := 260.0 if _portrait else 300.0
	var min_w := 128.0
	if label:
		label.custom_minimum_size = Vector2(min_w - 40.0, 0)
	if panel:
		panel.custom_minimum_size = Vector2(min_w, 40)
	# Let PanelContainer compute content size for current text.
	var ms := panel.get_combined_minimum_size() if panel else Vector2(min_w, 48)
	var bw: float = clampf(ms.x + 8.0, min_w, max_w)
	var bh: float = maxf(ms.y + 4.0, 44.0)
	size = Vector2(bw, bh + 12.0)
	# Tip of tail should sit on muzzle screen point.
	var tip_local := Vector2(bw * 0.42, bh + 10.0)
	var top_left := screen - tip_local
	var vp := get_viewport().get_visible_rect().size
	var pad := 10.0
	top_left.x = clampf(top_left.x, pad, maxf(pad, vp.x - bw - pad))
	top_left.y = clampf(top_left.y, pad, maxf(pad, vp.y - bh - 30.0))
	# Parent UI/Root is fullscreen; local position == viewport space.
	position = top_left
	if tail:
		tail.position = Vector2(bw * 0.42, bh - 1.0)

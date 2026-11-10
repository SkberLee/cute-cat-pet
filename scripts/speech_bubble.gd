# scripts/speech_bubble.gd
extends Control
class_name SpeechBubble

## Canvas-space bubble that follows the cat's mouth in the 2D world.

const HOLD_SEC := 2.75
const FADE_IN := 0.18
const FADE_OUT := 0.22

@onready var panel: PanelContainer = $Panel
@onready var label: Label = %FeedbackLabel
@onready var tail: TextureRect = get_node_or_null("Tail")
@onready var poly_tail: Polygon2D = get_node_or_null("PolyTail")

var _camera: Camera2D
var _cat: Node2D
var _tween: Tween
var _hold := -1.0
var _showing := false
var _font_size := 30
var _max_w := 480.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	_style_panel()
	if label:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var f := PixelUtil.font()
		if f:
			label.add_theme_font_override("font", f)
	if tail:
		tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tail.texture = PixelUtil.tex("res://assets/pixel/fx/bubble_tail.png")
		tail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tail.stretch_mode = TextureRect.STRETCH_KEEP
		tail.z_index = 1
	if poly_tail:
		poly_tail.visible = false

func setup(camera, cat) -> void:
	if camera is Camera2D:
		_camera = camera
	_cat = cat as Node2D

func _ensure_refs() -> void:
	if _camera == null:
		_camera = get_viewport().get_camera_2d() if get_viewport() else null
	if _cat == null:
		_cat = get_tree().root.find_child("Cat", true, false) as Node2D

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

func _process(_delta: float) -> void:
	if not _showing:
		return
	_update_follow()
	if _hold < 0.0:
		return
	_hold -= _delta
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
	var tex := PixelUtil.tex("res://assets/pixel/fx/bubble_9slice.png")
	if tex:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = 10
		sb.texture_margin_top = 10
		sb.texture_margin_right = 10
		sb.texture_margin_bottom = 10
		sb.content_margin_left = 10
		sb.content_margin_top = 8
		sb.content_margin_right = 10
		sb.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", sb)
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.96, 0.94, 0.98)
		sb.set_corner_radius_all(12)
		panel.add_theme_stylebox_override("panel", sb)

func _mouth_world() -> Vector2:
	if _cat and _cat.has_method("get_mouth_point"):
		return _cat.get_mouth_point()
	if _cat:
		return _cat.global_position + Vector2(0.0, -26.0)
	return Vector2.ZERO

func _world_to_canvas(world: Vector2) -> Vector2:
	if _cat and is_instance_valid(_cat):
		return _cat.get_canvas_transform() * world
	if _camera:
		return _camera.get_canvas_transform() * world
	return world

func _update_follow() -> void:
	_ensure_refs()
	if _cat == null or panel == null or label == null:
		return
	var mouth := _mouth_world()
	var tip := _world_to_canvas(mouth)
	var vp := get_viewport().get_visible_rect().size
	var font := label.get_theme_font("font")
	var pad_x := 18.0
	var pad_y := 12.0
	var max_text_w := maxf(_max_w - pad_x * 2.0, 120.0)
	var one_line := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size)
	var text_w := minf(one_line.x + 4.0, max_text_w)
	var text_sz := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, text_w, _font_size)
	text_sz.x = maxf(text_sz.x, 1.0)
	label.custom_minimum_size = Vector2(text_sz.x, text_sz.y)
	var bw := maxf(text_sz.x + pad_x * 2.0 + 8.0, 120.0)
	var bh := maxf(text_sz.y + pad_y * 2.0 + 6.0, 52.0)
	panel.position = Vector2.ZERO
	panel.size = Vector2(bw, bh)
	size = Vector2(bw, bh)
	# In 2D, mouth is above the feet (smaller y). Place bubble beside/above the mouth.
	var head_r := 72.0
	var margin := 12.0
	var left := 0.0
	var top := 0.0
	var placed := false
	for side in [1.0, -1.0]:
		var l: float = tip.x + head_r * 0.7 if side > 0.0 else tip.x - head_r * 0.7 - bw
		if l >= margin and l + bw <= vp.x - margin:
			left = l
			top = tip.y - bh * 0.95
			placed = true
			break
	if not placed:
		left = tip.x - bw * 0.5
		top = tip.y - bh - 18.0
		if str(_cat.get("action_phase")) == "feed":
			top = tip.y - bh - 28.0
	left = clampf(left, margin, maxf(margin, vp.x - bw - margin))
	top = clampf(top, margin, maxf(margin, vp.y - bh - margin))
	position = Vector2(left, top)
	var tip_local := tip - position
	if tail:
		# Point the 16px tail toward the mouth, sitting on the bubble edge.
		var tw := 16.0
		var th := 16.0
		var tx := clampf(tip_local.x - tw * 0.5, 8.0, bw - tw - 8.0)
		var ty := bh - 4.0
		if tip_local.y < 0.0:
			ty = -th + 4.0
			tail.flip_v = true
		else:
			tail.flip_v = false
		tail.position = Vector2(tx, ty)
		tail.size = Vector2(tw, th)
	pivot_offset = tip_local

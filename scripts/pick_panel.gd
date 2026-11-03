# scripts/pick_panel.gd
## Cute bottom-sheet picker (food / toy). Icons are drawn procedurally.
class_name PickPanel
extends PanelContainer

signal picked(id: String)

var _row: HBoxContainer
var _title: Label
var _buttons: Array = []
var _icons: Array = []

func setup(title: String, ids: Array, names: Array) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.965, 0.95, 0.97)
	sb.set_corner_radius_all(30)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 14
	sb.set_border_width_all(1)
	sb.border_color = Color(0.86, 0.72, 0.74, 0.55)
	sb.shadow_color = Color(0.45, 0.28, 0.32, 0.22)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	_title = Label.new()
	_title.text = title
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color(0.45, 0.3, 0.34))
	v.add_child(_title)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 12)
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_row)
	for i in ids.size():
		var b := Button.new()
		b.name = "Opt_" + str(ids[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		_style_btn(b)
		b.pressed.connect(func() -> void: picked.emit(str(ids[i])))
		_row.add_child(b)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(col)
		var icon := PickIcon.new()
		icon.kind = str(ids[i])
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(icon)
		var lab := Label.new()
		lab.text = str(names[i])
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.add_theme_color_override("font_color", Color(0.35, 0.25, 0.28))
		col.add_child(lab)
		_buttons.append(b)
		_icons.append(icon)

func _style_btn(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(1, 0.92, 0.9, 0.95)
	n.set_corner_radius_all(24)
	var h := n.duplicate()
	h.bg_color = Color(1, 0.86, 0.84, 0.98)
	var p := n.duplicate()
	p.bg_color = Color(0.95, 0.78, 0.76, 1)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_stylebox_override("disabled", n)

func set_metrics(font_size: int, height: float) -> void:
	custom_minimum_size.y = height
	_title.add_theme_font_size_override("font_size", font_size)
	for b in _buttons:
		for c in b.get_children():
			for l in c.get_children():
				if l is Label:
					l.add_theme_font_size_override("font_size", font_size)

func option_count() -> int:
	return _buttons.size()

func press_option(id: String) -> void:
	for b in _buttons:
		if b.name == "Opt_" + id:
			b.pressed.emit()
			return

## Procedural cute icons.
class PickIcon extends Control:
	var kind := ""

	func _draw() -> void:
		var s := minf(size.x, size.y)
		if s <= 4.0:
			return
		var c := size * 0.5
		var u := s / 78.0
		match kind:
			"fish":
				var body := Color(0.62, 0.74, 0.86)
				draw_set_transform(c, 0.0, Vector2.ONE)
				_ellipse(Vector2(-4, 0) * u, Vector2(32, 19) * u, body)
				draw_colored_polygon(PackedVector2Array([Vector2(24, 0) * u, Vector2(42, -17) * u, Vector2(42, 17) * u]), body)
				draw_circle(Vector2(-20, -4) * u, 3.6 * u, Color(0.2, 0.15, 0.18))
				draw_circle(Vector2(-12, 7) * u, 4.5 * u, Color(1.0, 0.7, 0.78, 0.7))
			"kibble":
				draw_set_transform(c, 0.0, Vector2.ONE)
				draw_colored_polygon(_bowl(u), Color(0.97, 0.6, 0.7))
				for p in [Vector2(-18, -10), Vector2(-4, -17), Vector2(12, -11), Vector2(0, -4), Vector2(-12, 0), Vector2(18, -2), Vector2(6, -22)]:
					draw_circle(p * u, 6.5 * u, Color(0.62, 0.4, 0.22))
				draw_colored_polygon(_bowl(u), Color(0.97, 0.6, 0.7))
			"can":
				draw_set_transform(c, 0.0, Vector2.ONE)
				draw_rect(Rect2(Vector2(-24, -24) * u, Vector2(48, 52) * u), Color(0.82, 0.85, 0.9))
				draw_rect(Rect2(Vector2(-24, -8) * u, Vector2(48, 20) * u), Color(0.98, 0.55, 0.64))
				_ellipse(Vector2(0, -24) * u, Vector2(24, 8) * u, Color(0.93, 0.95, 0.98))
				draw_circle(Vector2(0, 2) * u, 5 * u, Color(1, 0.95, 0.9))
			"milk":
				draw_set_transform(c, 0.0, Vector2.ONE)
				_ellipse(Vector2(0, 14) * u, Vector2(38, 14) * u, Color(0.78, 0.84, 0.96))
				_ellipse(Vector2(0, 10) * u, Vector2(30, 9) * u, Color(1.0, 0.99, 0.97))
				draw_circle(Vector2(-10, 6) * u, 3 * u, Color(1.0, 0.8, 0.86))
				draw_circle(Vector2(12, 8) * u, 2.4 * u, Color(1.0, 0.8, 0.86))
				draw_circle(Vector2(0, -22) * u, 9 * u, Color(1.0, 0.99, 0.97))
				draw_circle(Vector2(-8, -16) * u, 6 * u, Color(1.0, 0.99, 0.97))
			"wand":
				draw_set_transform(c, 0.0, Vector2.ONE)
				draw_line(Vector2(-34, 34) * u, Vector2(10, -14) * u, Color(0.82, 0.62, 0.4), 5.0 * u)
				_ellipse(Vector2(16, -22) * u, Vector2(10, 18) * u, Color(1.0, 0.62, 0.74))
				_ellipse(Vector2(28, -14) * u, Vector2(8, 15) * u, Color(1.0, 0.97, 0.94))
				_ellipse(Vector2(6, -14) * u, Vector2(8, 15) * u, Color(1.0, 0.97, 0.94))
			"yarn":
				draw_set_transform(c, 0.0, Vector2.ONE)
				draw_circle(Vector2.ZERO, 32 * u, Color(0.74, 0.62, 0.96))
				for a in [-0.6, 0.2, 0.9]:
					draw_arc(Vector2.ZERO, 26 * u, a, a + 1.6, 16, Color(0.97, 0.62, 0.82), 4.0 * u)
				draw_line(Vector2(20, 24) * u, Vector2(42, 34) * u, Color(0.97, 0.62, 0.82), 4.0 * u)
			"laser":
				draw_set_transform(c, 0.0, Vector2.ONE)
				draw_circle(Vector2.ZERO, 26 * u, Color(1.0, 0.3, 0.34, 0.25))
				draw_circle(Vector2.ZERO, 16 * u, Color(1.0, 0.3, 0.34, 0.5))
				draw_circle(Vector2.ZERO, 9 * u, Color(1.0, 0.2, 0.26))
				draw_circle(Vector2(-3, -3) * u, 3 * u, Color(1, 0.9, 0.9))
			"mouse":
				draw_set_transform(c, 0.0, Vector2.ONE)
				draw_line(Vector2(-26, 14) * u, Vector2(-44, 4) * u, Color(1.0, 0.7, 0.78), 4.0 * u)
				_ellipse(Vector2(-4, 8) * u, Vector2(30, 22) * u, Color(0.72, 0.7, 0.78))
				draw_circle(Vector2(8, -14) * u, 11 * u, Color(1.0, 0.7, 0.78))
				draw_circle(Vector2(-12, -12) * u, 11 * u, Color(1.0, 0.7, 0.78))
				draw_circle(Vector2(24, 8) * u, 4 * u, Color(1.0, 0.55, 0.65))
				draw_circle(Vector2(14, 2) * u, 3.2 * u, Color(0.2, 0.15, 0.18))

	func _ellipse(center: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)

	func _bowl(u: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 15:
			var a := PI * i / 14.0
			pts.append(Vector2(cos(a) * 36.0 * u, 2.0 * u + sin(a) * 26.0 * u))
		return pts

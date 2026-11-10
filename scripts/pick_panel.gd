# scripts/pick_panel.gd
## Pixel bottom-sheet picker (food / toy). Icons come from assets/pixel/ui.
class_name PickPanel
extends PanelContainer

signal picked(id: String)

const ICON_PATH := {
	"fish": "res://assets/pixel/ui/icon_fish.png",
	"kibble": "res://assets/pixel/ui/icon_kibble.png",
	"can": "res://assets/pixel/ui/icon_can.png",
	"milk": "res://assets/pixel/ui/icon_milk.png",
	"wand": "res://assets/pixel/ui/icon_wand.png",
	"yarn": "res://assets/pixel/ui/icon_yarn.png",
	"laser": "res://assets/pixel/ui/icon_laser.png",
	"mouse": "res://assets/pixel/ui/icon_mouse.png",
}

var _row: HBoxContainer
var _title: Label
var _buttons: Array = []
var _icons: Array = []

func setup(title: String, ids: Array, names: Array) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex := PixelUtil.tex("res://assets/pixel/ui/picker_panel.png")
	if tex:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = 12
		sb.texture_margin_top = 12
		sb.texture_margin_right = 12
		sb.texture_margin_bottom = 12
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 10
		sb.content_margin_bottom = 14
		add_theme_stylebox_override("panel", sb)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.965, 0.95, 0.97)
		sb.set_corner_radius_all(12)
		add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	_title = Label.new()
	_title.text = title
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color(0.45, 0.3, 0.34))
	var f := PixelUtil.font()
	if f:
		_title.add_theme_font_override("font", f)
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
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_style_btn(b)
		b.pressed.connect(func() -> void: picked.emit(str(ids[i])))
		_row.add_child(b)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(col)
		var icon := TextureRect.new()
		icon.texture = PixelUtil.tex(ICON_PATH.get(str(ids[i]), ""))
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(48, 48)
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		col.add_child(icon)
		var lab := Label.new()
		lab.text = str(names[i])
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.add_theme_color_override("font_color", Color(0.35, 0.25, 0.28))
		if f:
			lab.add_theme_font_override("font", f)
		col.add_child(lab)
		_buttons.append(b)
		_icons.append(icon)

func _style_btn(btn: Button) -> void:
	var tex := PixelUtil.tex("res://assets/pixel/ui/button.png")
	var tex_p := PixelUtil.tex("res://assets/pixel/ui/button_pressed.png")
	if tex:
		var n := StyleBoxTexture.new()
		n.texture = tex
		n.texture_margin_left = 10
		n.texture_margin_top = 6
		n.texture_margin_right = 10
		n.texture_margin_bottom = 6
		var h := n.duplicate()
		var p := StyleBoxTexture.new()
		p.texture = tex_p if tex_p else tex
		p.texture_margin_left = 10
		p.texture_margin_top = 6
		p.texture_margin_right = 10
		p.texture_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", n)
		btn.add_theme_stylebox_override("hover", h)
		btn.add_theme_stylebox_override("pressed", p)
		btn.add_theme_stylebox_override("disabled", n)
	else:
		var n := StyleBoxFlat.new()
		n.bg_color = Color(1, 0.92, 0.9, 0.95)
		n.set_corner_radius_all(12)
		btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_color_override("font_color", Color(0.35, 0.25, 0.28))
	var f := PixelUtil.font()
	if f:
		btn.add_theme_font_override("font", f)

func set_metrics(font_size: int, height: float) -> void:
	custom_minimum_size.y = height
	if _title:
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

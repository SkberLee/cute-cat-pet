# scripts/pet_hand.gd
## Cute 2D mitt that strokes the cat's head while the pet reaction plays.
class_name PetHand
extends Control

var _t := -1.0
var _dur := 1.6
var _camera: Camera3D
var _cat: Node3D
var _hearts: Array = []
var hand3d: PetHand3D

func setup(camera: Camera3D, cat: Node3D) -> void:
	_camera = camera
	_cat = cat
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	hand3d = PetHand3D.new()
	hand3d.setup(cat)

func play(duration: float) -> void:
	_dur = maxf(duration, 2.2)
	hand3d.play(_dur)
	_t = 0.0
	_hearts.clear()
	visible = true
	queue_redraw()

func is_playing() -> bool:
	return _t >= 0.0

func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t >= _dur:
		_t = -1.0
		visible = false
		return
	queue_redraw()

func _head_world() -> Vector3:
	if _cat and _cat.has_method("get_head_point"):
		return _cat.get_head_point()
	return _cat.global_position + Vector3(0, 0.9, 0.3)

func _draw() -> void:
	if _t < 0.0 or _camera == null or _cat == null:
		return
	var head: Vector3 = _head_world()
	var right := _camera.global_transform.basis.x
	var p0 := _camera.unproject_position(head)
	var s := absf(_camera.unproject_position(head + right * 0.25).x - p0.x)   # 0.25 world units in px
	s = clampf(s, 18.0, 400.0)
	var enter := clampf(_t / 0.3, 0.0, 1.0)
	var leave := clampf((_dur - _t) / 0.3, 0.0, 1.0)
	var vis := minf(enter, leave)
	var ease_v := vis * vis * (3.0 - 2.0 * vis)
	# Sweep left-right over the head top (~2.5 passes), with a slight bob.
	var phase := (_t / _dur) * TAU * 2.5
	var sweep := sin(phase)
	var pos := p0 + Vector2(sweep * 1.3 * s, -1.25 * s + absf(cos(phase)) * 0.14 * s)
	pos += Vector2(1.6 * s, -1.4 * s) * (1.0 - ease_v)   # slides in from upper right
	# floating hearts
	var n := int(_t / 0.35)
	for i in n:
		var born := i * 0.35
		var age := _t - born
		if age > 1.1:
			continue
		var hx := p0.x - 0.9 * s + sin(float(i) * 2.3) * 0.5 * s
		var hy := p0.y - 1.0 * s - age * 1.1 * s
		_heart(Vector2(hx, hy), 0.30 * s, Color(1.0, 0.45, 0.6, clampf(1.1 - age, 0.0, 1.0)))

func _heart(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(-r * 0.5, 0), r * 0.55, col)
	draw_circle(c + Vector2(r * 0.5, 0), r * 0.55, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.02, r * 0.18), c + Vector2(r * 1.02, r * 0.18), c + Vector2(0, r * 1.35)]), col)

func _draw_hand(u: float, a: float) -> void:
	# Hand reaching down onto the head (fingers point down); u = px per 0.45 world unit.
	var skin := Color(1.0, 0.84, 0.74, a)
	var line := Color(0.72, 0.42, 0.4, a)
	var sleeve := Color(0.99, 0.62, 0.72, a)
	# sleeve cuff
	var cuff := Rect2(Vector2(-1.25, -3.1) * u, Vector2(2.5, 1.5) * u)
	var sb := StyleBoxFlat.new()
	sb.bg_color = sleeve
	sb.set_corner_radius_all(int(0.5 * u))
	sb.set_border_width_all(maxi(2, int(0.07 * u)))
	sb.border_color = Color(0.85, 0.4, 0.55, a)
	draw_style_box(sb, cuff)
	draw_circle(Vector2(-0.6, -2.35) * u, 0.18 * u, Color(1, 1, 1, a * 0.8))
	draw_circle(Vector2(0.1, -2.35) * u, 0.18 * u, Color(1, 1, 1, a * 0.8))
	draw_circle(Vector2(0.8, -2.35) * u, 0.18 * u, Color(1, 1, 1, a * 0.8))
	# palm
	_blob(Vector2(0, 0), Vector2(1.45, 1.55) * u, skin, line, u)
	# fingers (pointing down)
	var fx := [-0.95, -0.32, 0.32, 0.95]
	var fl := [0.95, 1.2, 1.2, 0.95]
	for i in 4:
		_blob(Vector2(fx[i] * u, (1.05 + fl[i] * 0.45) * u), Vector2(0.38 * u, fl[i] * 0.55 * u), skin, line, u)
	# thumb
	_blob(Vector2(-1.55 * u, -0.1 * u), Vector2(0.42 * u, 0.8 * u), skin, line, u, 0.7)
	# little blush
	draw_circle(Vector2(0, 0.2 * u), 0.5 * u, Color(1.0, 0.72, 0.74, a * 0.45))

func _blob(c: Vector2, r: Vector2, col: Color, outline: Color, u: float, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var ang := TAU * i / 28.0
		var p := Vector2(cos(ang) * r.x, sin(ang) * r.y)
		pts.append(c + p.rotated(rot))
	pts.append(pts[0])
	var o := PackedVector2Array()
	for p in pts:
		o.append(p)
	draw_colored_polygon(pts.slice(0, 28), col)
	draw_polyline(pts, outline, maxf(2.0, 0.07 * u))

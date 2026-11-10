# scripts/pet_hand.gd
## HUD layer of the pet interaction: drives the 3D hand and draws floating hearts.
# class_name (legacy snapshot) PetHand
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
	var p0 := _camera.unproject_position(head)
	var right := _camera.global_transform.basis.x
	var s := absf(_camera.unproject_position(head + right * 0.25).x - p0.x)   # 0.25 world units in px
	s = clampf(s, 18.0, 400.0)
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

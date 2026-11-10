# scripts/pixel_room.gd
## Assembles the cozy pixel room from assets/pixel/room tiles.
class_name PixelRoom
extends Node2D

const SIZE := Vector2(320, 208)
const WALL_H := 72
const TILE := 32

var _built := false

func _ready() -> void:
	if _built:
		return
	_built = true
	_build()

func _build() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var floor_tex := PixelUtil.tex("res://assets/pixel/room/floor_wood_32.png")
	var wall_tex := PixelUtil.tex("res://assets/pixel/room/wall_cream.png")
	var base_tex := PixelUtil.tex("res://assets/pixel/room/wall_baseboard.png")
	var floor_root: Node2D = get_node_or_null("FloorRoot")
	if floor_root == null:
		floor_root = Node2D.new()
		floor_root.name = "FloorRoot"
		add_child(floor_root)
	var wall_root: Node2D = get_node_or_null("WallBack")
	if wall_root == null:
		wall_root = Node2D.new()
		wall_root.name = "WallBack"
		wall_root.unique_name_in_owner = true
		add_child(wall_root)
	# Extra wall above y=0 and floor below the room so letterboxing still looks like the room.
	for y in range(-256, 16, 16):
		for x in range(0, int(SIZE.x), TILE):
			_tile(wall_root, wall_tex, x, y)
	for x in range(0, int(SIZE.x), TILE):
		_tile(wall_root, base_tex, x, WALL_H - 32)
	for y in range(WALL_H, 208 + 320, TILE):
		for x in range(0, int(SIZE.x), TILE):
			_tile(floor_root, floor_tex, x, y)
	# Unique furniture may already exist in the packed scene.
	_ensure_unique("Curtain", _make_curtain(), Vector2(8, 4), false)
	_ensure_sprite("Lamp", "res://assets/pixel/room/lamp.png", Vector2(20, 36))
	_ensure_unique("Rug", PixelUtil.sprite("res://assets/pixel/room/rug.png"), Vector2(160, 164), true)
	_ensure_unique("Cushion", PixelUtil.sprite("res://assets/pixel/room/ottoman.png"), Vector2(52, 190), true)
	_ensure_sprite("Box", "res://assets/pixel/room/box.png", Vector2(268, 152))

func _tile(parent: Node2D, tex: Texture2D, x: int, y: int) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = Vector2(x, y)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(s)

func _spr(n: String, path: String, pos: Vector2, origin: Vector2) -> Sprite2D:
	var s := PixelUtil.sprite(path, false)
	s.name = n
	s.position = pos - origin
	add_child(s)
	return s

func _make_curtain() -> Sprite2D:
	# Simple pixel curtain so the dress-up theme has something to tint.
	var img := Image.create(36, 64, false, Image.FORMAT_RGBA8)
	var edge := Color(0.85, 0.55, 0.6, 1)
	var fold := Color(0.95, 0.75, 0.78, 1)
	var cloth := Color(0.97, 0.82, 0.85, 1)
	for y in 64:
		for x in 36:
			var wave := int(sin(y * 0.18 + x * 0.02) * 2.0)
			var col := cloth
			if x % 9 == 0 or x % 9 == 1:
				col = fold
			if x < 2 or x > 33 or y < 2 or y > 61:
				col = edge
			if y + wave < 3:
				col = edge
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s

func _ensure_unique(n: String, spr: Sprite2D, pos: Vector2, centered: bool) -> Sprite2D:
	var existing := get_node_or_null(n) as Sprite2D
	if existing:
		if existing.texture == null and spr.texture:
			existing.texture = spr.texture
		existing.centered = centered
		existing.position = pos
		existing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if spr != existing:
			spr.free()
		return existing
	spr.name = n
	spr.centered = centered
	spr.position = pos
	spr.unique_name_in_owner = true
	if owner:
		spr.owner = owner
	add_child(spr)
	return spr

func _ensure_sprite(n: String, path: String, pos: Vector2) -> Sprite2D:
	var existing := get_node_or_null(n) as Sprite2D
	if existing:
		if existing.texture == null:
			existing.texture = PixelUtil.tex(path)
		existing.centered = false
		existing.position = pos
		existing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return existing
	return _spr(n, path, pos + Vector2(16, 16), Vector2(16, 16))

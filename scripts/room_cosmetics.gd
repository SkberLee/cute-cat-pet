# scripts/room_cosmetics.gd
class_name RoomCosmetics
extends Node

signal theme_changed(theme_id: String)

## Soft pastel room themes. Unlock via bond milestones.
const THEMES := {
	"blush": {
		"name": "腮红粉",
		"need_bond": 0,
		"rug": Color(0.93, 0.72, 0.74),
		"cushion": Color(0.86, 0.78, 0.92),
		"curtain": Color(0.95, 0.78, 0.82),
		"wall": Color(0.97, 0.92, 0.9),
	},
	"mint": {
		"name": "薄荷绿",
		"need_bond": 25,
		"rug": Color(0.72, 0.88, 0.8),
		"cushion": Color(0.9, 0.95, 0.9),
		"curtain": Color(0.78, 0.9, 0.84),
		"wall": Color(0.94, 0.96, 0.93),
	},
	"sky": {
		"name": "天空蓝",
		"need_bond": 50,
		"rug": Color(0.72, 0.82, 0.95),
		"cushion": Color(0.95, 0.88, 0.82),
		"curtain": Color(0.8, 0.88, 0.98),
		"wall": Color(0.93, 0.95, 0.98),
	},
	"sunset": {
		"name": "日落暖",
		"need_bond": 75,
		"rug": Color(0.96, 0.78, 0.62),
		"cushion": Color(0.95, 0.72, 0.76),
		"curtain": Color(0.98, 0.82, 0.7),
		"wall": Color(0.98, 0.93, 0.88),
	},
}

@onready var rug: CanvasItem = %Rug
@onready var cushion: CanvasItem = %Cushion
@onready var curtain: CanvasItem = %Curtain
@onready var wall_back: CanvasItem = %WallBack

var current_theme: String = "blush"

func _ready() -> void:
	apply_theme(current_theme, false)

func unlocked_ids(bond: float) -> Array[String]:
	var out: Array[String] = []
	for id in ["blush", "mint", "sky", "sunset"]:
		if float(THEMES[id]["need_bond"]) <= bond:
			out.append(id)
	return out

func theme_display_name(id: String) -> String:
	if THEMES.has(id):
		return str(THEMES[id]["name"])
	return id

func apply_theme(id: String, emit_signal: bool = true) -> void:
	if not THEMES.has(id):
		id = "blush"
	current_theme = id
	var t: Dictionary = THEMES[id]
	_set_tint(rug, t["rug"])
	_set_tint(cushion, t["cushion"])
	_set_tint(curtain, t["curtain"])
	_set_tint(wall_back, t["wall"])
	if emit_signal:
		theme_changed.emit(current_theme)

func cycle_next(bond: float) -> String:
	var ids := unlocked_ids(bond)
	if ids.is_empty():
		ids = ["blush"]
	var idx := ids.find(current_theme)
	if idx < 0:
		idx = 0
	else:
		idx = (idx + 1) % ids.size()
	apply_theme(ids[idx])
	return current_theme

func _set_tint(node: CanvasItem, color: Color) -> void:
	if node == null:
		return
	# Multiply the pixel art by a soft theme tint (keep luminance).
	node.modulate = Color(
		clampf((color.r + 0.35) / 1.15, 0.55, 1.2),
		clampf((color.g + 0.35) / 1.15, 0.55, 1.2),
		clampf((color.b + 0.35) / 1.15, 0.55, 1.2),
		1.0
	)

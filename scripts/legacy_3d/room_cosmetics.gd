# scripts/room_cosmetics.gd
# class_name (legacy snapshot) RoomCosmetics
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

@onready var rug: CSGPrimitive3D = %Rug
@onready var cushion: CSGPrimitive3D = %Cushion
@onready var curtain: CSGPrimitive3D = %Curtain
@onready var wall_back: CSGPrimitive3D = %WallBack

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
	_set_albedo(rug, t["rug"])
	_set_albedo(cushion, t["cushion"])
	_set_albedo(curtain, t["curtain"])
	_set_albedo(wall_back, t["wall"])
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

func _set_albedo(node: CSGPrimitive3D, color: Color) -> void:
	if node == null:
		return
	var mat = node.material
	if mat is StandardMaterial3D:
		var dup: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
		dup.albedo_color = color
		node.material = dup
	else:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		node.material = m

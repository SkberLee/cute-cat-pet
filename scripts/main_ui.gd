# scripts/main_ui.gd
extends CanvasLayer

## Dual-orientation mobile UI. Soft bars + large touch targets.
## Portrait: 2×2 action grid; landscape: single row. Tap cat to zoom.

@onready var cat: Node3D = %Cat
@onready var stats: PetStats = %PetStats
@onready var mood_bar: ProgressBar = %MoodBar
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var bond_bar: ProgressBar = %BondBar
@onready var btn_pet: Button = %BtnPet
@onready var btn_feed: Button = %BtnFeed
@onready var btn_play: Button = %BtnPlay
@onready var btn_theme: Button = %BtnTheme
@onready var stats_card: PanelContainer = $Root/SafeMargin/Layout/StatsCard
@onready var buttons: GridContainer = $Root/SafeMargin/Layout/Buttons
@onready var feedback_label: Label = %FeedbackLabel
@onready var camera: Camera3D = $"../Camera3D"
@onready var room_cosmetics: RoomCosmetics = %RoomCosmetics
@onready var safe_margin: MarginContainer = $Root/SafeMargin
@onready var btn_zoom_back: Button = %BtnZoomBack

var _sfx_ui: AudioStream
var _ui_player: AudioStreamPlayer
var _portrait := false
var _zoomed := false
var _cam_base_pos := Vector3(0, 1.48, 2.85)
var _cam_base_fov := 48.0
var _cam_base_basis: Basis = Basis.IDENTITY
var _cam_tween: Tween

func _ready() -> void:
	_style_ui()
	_setup_ui_audio()
	_load_game()
	btn_pet.pressed.connect(_on_pet)
	btn_feed.pressed.connect(_on_feed)
	btn_play.pressed.connect(_on_play)
	if btn_theme:
		btn_theme.pressed.connect(_on_theme)
	if btn_zoom_back:
		btn_zoom_back.pressed.connect(_on_zoom_back)
		btn_zoom_back.visible = false
	if cat:
		if cat.has_signal("interaction_started"):
			cat.interaction_started.connect(_on_busy)
		if cat.has_signal("interaction_ready"):
			cat.interaction_ready.connect(_on_ready_again)
		if cat.has_signal("save_requested"):
			cat.save_requested.connect(_save_game)
	if stats:
		stats.stats_changed.connect(_refresh)
		if stats.has_signal("milestone_unlocked"):
			stats.milestone_unlocked.connect(_on_milestone_ui)
		_refresh()
	get_viewport().size_changed.connect(_on_viewport_resized)
	if feedback_label:
		feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_on_viewport_resized()
	_update_theme_button()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_try_tap_cat(mb.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_try_tap_cat(st.position)

func _try_tap_cat(screen_pos: Vector2) -> void:
	if camera == null or cat == null:
		return
	# Ignore taps that land on UI controls (buttons already consume).
	var space := get_viewport().world_3d.direct_space_state
	if space == null:
		return
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 20.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	if collider == null:
		return
	var n := collider as Node
	if n == null:
		return
	# Accept CatTapBody or any ancestor under Cat.
	var under_cat := false
	var walk: Node = n
	while walk:
		if walk == cat:
			under_cat = true
			break
		walk = walk.get_parent()
	if not under_cat:
		return
	get_viewport().set_input_as_handled()
	_toggle_zoom()

func _toggle_zoom() -> void:
	if _zoomed:
		_exit_zoom()
	else:
		_enter_zoom()

func _enter_zoom() -> void:
	if camera == null or cat == null:
		return
	_zoomed = true
	if btn_zoom_back:
		btn_zoom_back.visible = true
	_play_ui()
	var focus: Vector3 = cat.get_focus_point() if cat.has_method("get_focus_point") else cat.global_position + Vector3(0, 0.7, 0)
	var zoom_pos := focus + Vector3(0.0, 0.15, 1.08)
	if _portrait:
		zoom_pos = focus + Vector3(0.0, 0.2, 1.25)
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.set_parallel(true)
	_cam_tween.tween_property(camera, "global_position", zoom_pos, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(camera, "fov", 38.0 if _portrait else 34.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_method(func(_t: float) -> void: _aim_camera(focus), 0.0, 1.0, 0.45)
	if feedback_label:
		feedback_label.text = "近距离看看我～点「返回」或再点我"

func _aim_camera(focus: Vector3) -> void:
	if camera and is_instance_valid(cat):
		camera.look_at(focus, Vector3.UP)

func _exit_zoom() -> void:
	_zoomed = false
	if btn_zoom_back:
		btn_zoom_back.visible = false
	_play_ui()
	_restore_camera(true)

func _on_zoom_back() -> void:
	if _zoomed:
		_exit_zoom()

func _restore_camera(animated: bool) -> void:
	if camera == null:
		return
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	# Reset rotation to the default downward look used in the scene.
	var target_xform := Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-20.0)),
		_cam_base_pos
	)
	if animated:
		_cam_tween = create_tween()
		_cam_tween.set_parallel(true)
		_cam_tween.tween_property(camera, "position", _cam_base_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_cam_tween.tween_property(camera, "fov", _cam_base_fov, 0.4)
		_cam_tween.set_parallel(false)
		_cam_tween.tween_callback(func ():
			if camera:
				camera.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-20.0)), camera.position)
		)
	else:
		camera.fov = _cam_base_fov
		camera.transform = target_xform

func _setup_ui_audio() -> void:
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UiSfx"
	_ui_player.volume_db = -8.0
	add_child(_ui_player)
	_sfx_ui = load("res://assets/sfx/ui_soft.wav")

func _play_ui() -> void:
	if _ui_player and _sfx_ui:
		_ui_player.stream = _sfx_ui
		_ui_player.play()

func _style_ui() -> void:
	_apply_stats_card_style()
	_style_bar(mood_bar, Color(0.95, 0.55, 0.68))
	_style_bar(hunger_bar, Color(0.96, 0.72, 0.38))
	_style_bar(bond_bar, Color(0.68, 0.64, 0.94))
	for b in [btn_pet, btn_feed, btn_play, btn_theme, btn_zoom_back]:
		_style_button(b)

func _apply_stats_card_style() -> void:
	if stats_card == null:
		return
	var panel := StyleBoxFlat.new()
	# More opaque so wall / table don't bleed through.
	panel.bg_color = Color(1.0, 0.965, 0.95, 0.94)
	panel.corner_radius_top_left = 20
	panel.corner_radius_top_right = 20
	panel.corner_radius_bottom_left = 20
	panel.corner_radius_bottom_right = 20
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 12
	panel.content_margin_bottom = 14
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.border_color = Color(0.86, 0.72, 0.74, 0.55)
	panel.shadow_color = Color(0.45, 0.28, 0.32, 0.18)
	panel.shadow_size = 8
	panel.shadow_offset = Vector2(0, 3)
	stats_card.add_theme_stylebox_override("panel", panel)

func _style_bar(bar: ProgressBar, fill: Color) -> void:
	if bar == null:
		return
	var bg := StyleBoxFlat.new()
	# Stronger track contrast against pale card / wall.
	bg.bg_color = Color(0.78, 0.68, 0.66, 0.42)
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10
	bg.content_margin_left = 2
	bg.content_margin_right = 2
	bg.content_margin_top = 2
	bg.content_margin_bottom = 2
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(0.62, 0.5, 0.5, 0.35)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.corner_radius_top_left = 8
	fg.corner_radius_top_right = 8
	fg.corner_radius_bottom_left = 8
	fg.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 24

func _style_button(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 0.92, 0.9, 0.95)
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	normal.shadow_color = Color(0.4, 0.25, 0.28, 0.12)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)
	var hover := normal.duplicate()
	hover.bg_color = Color(1, 0.86, 0.84, 0.98)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.95, 0.78, 0.76, 1)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.9, 0.88, 0.86, 0.55)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.35, 0.25, 0.28))
	btn.add_theme_color_override("font_hover_color", Color(0.28, 0.18, 0.22))
	btn.add_theme_color_override("font_pressed_color", Color(0.22, 0.14, 0.16))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.45, 0.45, 0.7))

func _on_viewport_resized() -> void:
	var size := get_viewport().get_visible_rect().size
	_portrait = size.y > size.x
	_apply_layout()

func _apply_layout() -> void:
	if stats_card == null or buttons == null:
		return
	if safe_margin:
		if _portrait:
			safe_margin.add_theme_constant_override("margin_left", 28)
			safe_margin.add_theme_constant_override("margin_right", 28)
			safe_margin.add_theme_constant_override("margin_top", 24)
			safe_margin.add_theme_constant_override("margin_bottom", 24)
		else:
			safe_margin.add_theme_constant_override("margin_left", 36)
			safe_margin.add_theme_constant_override("margin_right", 48)
			safe_margin.add_theme_constant_override("margin_top", 28)
			safe_margin.add_theme_constant_override("margin_bottom", 28)

	if _portrait:
		stats_card.set_anchors_preset(Control.PRESET_TOP_WIDE)
		stats_card.anchor_left = 0.0
		stats_card.anchor_right = 1.0
		stats_card.offset_left = 0.0
		stats_card.offset_right = 0.0
		stats_card.offset_top = 0.0
		stats_card.offset_bottom = 172.0
		if feedback_label:
			feedback_label.offset_top = 180.0
			feedback_label.offset_bottom = 228.0
			feedback_label.add_theme_font_size_override("font_size", 22)
		# 2×2 grid: 摸摸/喂食 top, 逗逗/换装 bottom
		buttons.columns = 2
		buttons.offset_left = -168.0
		buttons.offset_right = 168.0
		buttons.offset_top = -168.0
		buttons.offset_bottom = -8.0
		buttons.add_theme_constant_override("h_separation", 14)
		buttons.add_theme_constant_override("v_separation", 12)
		for b in [btn_pet, btn_feed, btn_play]:
			if b:
				b.custom_minimum_size = Vector2(148, 68)
				b.add_theme_font_size_override("font_size", 22)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if btn_theme:
			btn_theme.visible = true
			btn_theme.custom_minimum_size = Vector2(148, 68)
			btn_theme.add_theme_font_size_override("font_size", 18)
			btn_theme.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_cam_base_fov = 48.0
		# Closer + slightly lower to shrink empty wall above the cat.
		_cam_base_pos = Vector3(0, 1.22, 2.45)
	else:
		stats_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		stats_card.anchor_left = 1.0
		stats_card.anchor_right = 1.0
		# Extra inset from right so wooden table doesn't sit under bars.
		stats_card.offset_left = -300.0
		stats_card.offset_right = -12.0
		stats_card.offset_top = 0.0
		stats_card.offset_bottom = 156.0
		if feedback_label:
			feedback_label.offset_top = 8.0
			feedback_label.offset_bottom = 56.0
			feedback_label.add_theme_font_size_override("font_size", 26)
		buttons.columns = 4
		buttons.offset_left = -380.0
		buttons.offset_right = 380.0
		buttons.offset_top = -88.0
		buttons.offset_bottom = 0.0
		buttons.add_theme_constant_override("h_separation", 16)
		buttons.add_theme_constant_override("v_separation", 8)
		for b in [btn_pet, btn_feed, btn_play]:
			if b:
				b.custom_minimum_size = Vector2(140, 68)
				b.add_theme_font_size_override("font_size", 24)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if btn_theme:
			btn_theme.visible = true
			btn_theme.custom_minimum_size = Vector2(130, 68)
			btn_theme.add_theme_font_size_override("font_size", 20)
			btn_theme.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_cam_base_fov = 46.0
		_cam_base_pos = Vector3(0, 1.42, 2.75)

	if btn_zoom_back:
		btn_zoom_back.custom_minimum_size = Vector2(120, 52)
		btn_zoom_back.add_theme_font_size_override("font_size", 20)

	if not _zoomed:
		_restore_camera(false)

func _set_buttons_enabled(enabled: bool) -> void:
	btn_pet.disabled = not enabled
	btn_feed.disabled = not enabled
	btn_play.disabled = not enabled

func _on_busy(_action: String) -> void:
	_set_buttons_enabled(false)

func _on_ready_again() -> void:
	_set_buttons_enabled(true)

func _on_pet() -> void:
	if cat and cat.has_method("do_pet"):
		cat.do_pet()

func _on_feed() -> void:
	if cat and cat.has_method("do_feed"):
		cat.do_feed()

func _on_play() -> void:
	if cat and cat.has_method("do_play"):
		cat.do_play()

func _on_theme() -> void:
	if room_cosmetics == null or stats == null:
		return
	var id := room_cosmetics.cycle_next(stats.bond)
	_play_ui()
	_update_theme_button()
	if feedback_label:
		feedback_label.text = "房间换成「%s」啦" % room_cosmetics.theme_display_name(id)
	_save_game()

func _on_milestone_ui(threshold: int, title: String) -> void:
	_update_theme_button()
	if feedback_label and threshold >= 25:
		pass
	_save_game()

func _update_theme_button() -> void:
	if btn_theme == null or room_cosmetics == null or stats == null:
		return
	var name := room_cosmetics.theme_display_name(room_cosmetics.current_theme)
	var unlocked := room_cosmetics.unlocked_ids(stats.bond)
	btn_theme.text = "换装·%s" % name
	btn_theme.disabled = unlocked.size() <= 1 and stats.bond < 25.0
	if stats.bond < 25.0:
		btn_theme.text = "换装·锁定"
		btn_theme.disabled = true

func _refresh() -> void:
	if stats == null:
		return
	mood_bar.value = stats.mood
	hunger_bar.value = stats.hunger
	bond_bar.value = stats.bond
	_update_theme_button()

func _load_game() -> void:
	var data := SaveManager.load_dict()
	if data.is_empty():
		return
	if stats and data.has("stats"):
		stats.from_save(data["stats"])
	elif stats:
		stats.from_save(data)
	if room_cosmetics and data.has("room_theme"):
		var theme_id := str(data["room_theme"])
		var bond_v := stats.bond if stats else 0.0
		if theme_id in room_cosmetics.unlocked_ids(bond_v) or theme_id == "blush":
			room_cosmetics.apply_theme(theme_id, false)
	if cat and cat.has_method("_apply_cosmetics_for_bond") and stats:
		cat._apply_cosmetics_for_bond(stats.bond)

func _save_game() -> void:
	if stats == null:
		return
	var data := {
		"stats": stats.to_save(),
		"room_theme": room_cosmetics.current_theme if room_cosmetics else "blush",
	}
	SaveManager.save_dict(data)

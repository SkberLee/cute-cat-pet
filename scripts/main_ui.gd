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
@onready var speech_bubble: Node = %SpeechBubble
@onready var camera: Camera3D = $"../Camera3D"
@onready var room_cosmetics: RoomCosmetics = %RoomCosmetics
@onready var safe_margin: MarginContainer = $Root/SafeMargin
@onready var btn_zoom_back: Button = %BtnZoomBack

var _sfx_ui: AudioStream
var _ui_player: AudioStreamPlayer
var _portrait := false
var _zoomed := false
var _cam_base_fov := 48.0
var _cam_dist := 3.0
var _cam_focus_y := 0.5
var _cam_follow_focus := Vector3.ZERO
var _cam_tween: Tween
var _last_tap_ms := -10000
var _cam_follow := true
var _cam_target := Vector3.ZERO
var _cam_pitch := -28.0
const CAM_FOLLOW_K := 1.0
const CAM_FOLLOW_SPEED := 5.0
const BASE_PORTRAIT := Vector2i(720, 1280)
const BASE_LANDSCAPE := Vector2i(1280, 720)
var _ui_scale := 1.0

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
	if speech_bubble and speech_bubble.has_method("setup"):
		speech_bubble.setup(camera, cat)
	_on_viewport_resized()
	_update_theme_button()

func _unhandled_input(event: InputEvent) -> void:
	# On Android a touch generates both ScreenTouch and an emulated mouse click;
	# handle only one of them (touch) so zoom is never toggled twice by one tap.
	if event is InputEventMouseButton:
		if DisplayServer.is_touchscreen_available():
			return
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
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < 450:
		return
	# Input positions arrive already in the stretched (canvas) space that Camera3D uses.
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
	_last_tap_ms = now
	get_viewport().set_input_as_handled()
	_toggle_zoom()

func _toggle_zoom() -> void:
	if _zoomed:
		_exit_zoom()
	else:
		_enter_zoom()

func _focus_for_cat() -> Vector3:
	var c := Vector3.ZERO
	if cat:
		# The model's origin is at its tail end; aim at the body centre instead.
		c = cat.global_position + cat.global_transform.basis.z * 0.35
	return Vector3(c.x * CAM_FOLLOW_K, _cam_focus_y, c.z * CAM_FOLLOW_K)

func _cam_pos_for(focus: Vector3) -> Vector3:
	var p := deg_to_rad(-_cam_pitch)
	return focus + Vector3(0.0, sin(p), cos(p)) * _cam_dist

func _snap_camera() -> void:
	if camera == null:
		return
	_cam_follow_focus = _focus_for_cat()
	camera.fov = _cam_base_fov
	camera.keep_aspect = Camera3D.KEEP_WIDTH if _portrait else Camera3D.KEEP_HEIGHT
	camera.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(_cam_pitch)), _cam_pos_for(_cam_follow_focus))

func _process(delta: float) -> void:
	# Gentle follow so the roaming cat always stays in frame.
	if camera == null or cat == null or _zoomed or not _cam_follow:
		return
	var target := _focus_for_cat()
	_cam_follow_focus = _cam_follow_focus.lerp(target, clampf(CAM_FOLLOW_SPEED * delta, 0.0, 1.0))
	camera.position = _cam_pos_for(_cam_follow_focus)

func _enter_zoom() -> void:
	if camera == null or cat == null:
		return
	_zoomed = true
	_cam_follow = false
	if cat.has_method("set_autonomy_paused"):
		cat.set_autonomy_paused(true)
	if btn_zoom_back:
		btn_zoom_back.visible = true
	_play_ui()
	var focus: Vector3 = cat.get_focus_point() if cat.has_method("get_focus_point") else cat.global_position + Vector3(0, 0.7, 0)
	var zoom_pos := focus + Vector3(0.0, 0.2, 1.25 if _portrait else 1.08)
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.set_parallel(true)
	_cam_tween.tween_property(camera, "global_position", zoom_pos, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(camera, "fov", 46.0 if _portrait else 34.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_method(func(_t: float) -> void: _aim_camera(focus), 0.0, 1.0, 0.45)
	_bubble_say("近距离看我～")

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
	if not animated:
		_cam_follow = true
		_snap_camera()
		return
	var focus := _focus_for_cat()
	var target_pos := _cam_pos_for(focus)
	var target_basis := Basis(Vector3.RIGHT, deg_to_rad(_cam_pitch))
	var from_q := camera.global_transform.basis.get_rotation_quaternion()
	_cam_tween = create_tween()
	_cam_tween.set_parallel(true)
	_cam_tween.tween_property(camera, "global_position", target_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(camera, "fov", _cam_base_fov, 0.4)
	_cam_tween.tween_method(func(t: float) -> void:
		camera.global_transform.basis = Basis(from_q.slerp(target_basis.get_rotation_quaternion(), t))
	, 0.0, 1.0, 0.4)
	_cam_tween.set_parallel(false)
	_cam_tween.tween_callback(func ():
		_cam_follow_focus = focus
		_cam_follow = true
		if cat and cat.has_method("set_autonomy_paused"):
			cat.set_autonomy_paused(false)
	)

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
	panel.content_margin_left = 22
	panel.content_margin_right = 22
	panel.content_margin_top = 16
	panel.content_margin_bottom = 18
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
	bar.custom_minimum_size.y = 30

func _style_button(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 0.92, 0.9, 0.95)
	normal.corner_radius_top_left = 28
	normal.corner_radius_top_right = 28
	normal.corner_radius_bottom_left = 28
	normal.corner_radius_bottom_right = 28
	normal.content_margin_left = 12
	normal.content_margin_right = 12
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
	var win := get_window()
	var wsize := Vector2(win.size)
	if wsize.x < 1.0 or wsize.y < 1.0:
		return
	var portrait_now := wsize.y > wsize.x
	# Per-orientation design resolution: UI is authored for the SHORT side being
	# 720 units, so a tall phone doesn't shrink everything to a 1280-wide layout.
	var base := BASE_PORTRAIT if portrait_now else BASE_LANDSCAPE
	if win.content_scale_size != base:
		win.content_scale_size = base
	var vis := get_viewport().get_visible_rect().size
	_portrait = portrait_now
	_ui_scale = wsize.x / maxf(vis.x, 1.0)
	_apply_layout()

func _safe_insets() -> Vector4:
	# left, top, right, bottom in canvas units (0 on desktop windows).
	var win := get_window()
	var scr_size := DisplayServer.screen_get_size(win.current_screen)
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or absi(win.size.x - scr_size.x) > 4 or absi(win.size.y - scr_size.y) > 4:
		return Vector4.ZERO
	var k := 1.0 / maxf(_ui_scale, 0.01)
	var l := clampf(float(safe.position.x) * k, 0.0, 120.0)
	var t := clampf(float(safe.position.y) * k, 0.0, 120.0)
	var r := clampf(float(scr_size.x - safe.end.x) * k, 0.0, 120.0)
	var b := clampf(float(scr_size.y - safe.end.y) * k, 0.0, 120.0)
	return Vector4(l, t, r, b)

func _set_stats_fonts(title_fs: int, label_fs: int, label_w: float, bar_h: float) -> void:
	var panel := stats_card.get_node_or_null("StatsPanel")
	if panel == null:
		return
	var title := panel.get_node_or_null("Title") as Label
	if title:
		title.add_theme_font_size_override("font_size", title_fs)
	for row_name in ["MoodRow", "HungerRow", "BondRow"]:
		var row := panel.get_node_or_null(row_name)
		if row == null:
			continue
		for c in row.get_children():
			if c is Label:
				c.add_theme_font_size_override("font_size", label_fs)
				c.custom_minimum_size.x = label_w
			elif c is ProgressBar:
				c.custom_minimum_size.y = bar_h
				c.custom_minimum_size.x = 120.0
	(panel as VBoxContainer).add_theme_constant_override("separation", int(bar_h * 0.35))

func _apply_layout() -> void:
	if stats_card == null or buttons == null:
		return
	var ins := _safe_insets()
	var btn_list: Array = [btn_pet, btn_feed, btn_play, btn_theme]
	if _portrait:
		# Base 720 wide: 2x2 grid, each button ~44% width x ~9% of a 16:9-ish height.
		var m := 24.0
		safe_margin.add_theme_constant_override("margin_left", int(m + ins.x))
		safe_margin.add_theme_constant_override("margin_right", int(m + ins.z))
		safe_margin.add_theme_constant_override("margin_top", int(18.0 + ins.y))
		safe_margin.add_theme_constant_override("margin_bottom", int(26.0 + ins.w))
		stats_card.anchor_left = 0.0
		stats_card.anchor_right = 1.0
		stats_card.anchor_top = 0.0
		stats_card.anchor_bottom = 0.0
		stats_card.offset_left = 0.0
		stats_card.offset_right = 0.0
		stats_card.offset_top = 0.0
		stats_card.offset_bottom = 10.0
		_set_stats_fonts(30, 30, 96.0, 34.0)
		var bh := 118.0
		buttons.columns = 2
		buttons.anchor_left = 0.0
		buttons.anchor_right = 1.0
		buttons.anchor_top = 1.0
		buttons.anchor_bottom = 1.0
		buttons.offset_left = 0.0
		buttons.offset_right = 0.0
		buttons.offset_top = -(bh * 2.0 + 16.0)
		buttons.offset_bottom = 0.0
		buttons.add_theme_constant_override("h_separation", 18)
		buttons.add_theme_constant_override("v_separation", 16)
		for b in btn_list:
			if b:
				b.custom_minimum_size = Vector2(0, bh)
				b.add_theme_font_size_override("font_size", 38)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if btn_zoom_back:
			btn_zoom_back.anchor_left = 0.5
			btn_zoom_back.anchor_right = 0.5
			btn_zoom_back.anchor_top = 1.0
			btn_zoom_back.anchor_bottom = 1.0
			btn_zoom_back.offset_left = -120.0
			btn_zoom_back.offset_right = 120.0
			btn_zoom_back.offset_bottom = -(bh * 2.0 + 16.0 + 14.0)
			btn_zoom_back.offset_top = btn_zoom_back.offset_bottom - 92.0
			btn_zoom_back.add_theme_font_size_override("font_size", 36)
		if speech_bubble and speech_bubble.has_method("set_metrics"):
			speech_bubble.set_metrics(34, 540.0)
		_cam_base_fov = 32.0      # horizontal FOV (KEEP_WIDTH)
		_cam_pitch = -30.0
		_cam_dist = 3.1
		_cam_focus_y = 0.55
	else:
		safe_margin.add_theme_constant_override("margin_left", int(36.0 + ins.x))
		safe_margin.add_theme_constant_override("margin_right", int(36.0 + ins.z))
		safe_margin.add_theme_constant_override("margin_top", int(20.0 + ins.y))
		safe_margin.add_theme_constant_override("margin_bottom", int(24.0 + ins.w))
		stats_card.anchor_left = 1.0
		stats_card.anchor_right = 1.0
		stats_card.anchor_top = 0.0
		stats_card.anchor_bottom = 0.0
		stats_card.offset_left = -400.0
		stats_card.offset_right = 0.0
		stats_card.offset_top = 0.0
		stats_card.offset_bottom = 10.0
		_set_stats_fonts(26, 26, 84.0, 28.0)
		var bh := 92.0
		buttons.columns = 4
		buttons.anchor_left = 0.5
		buttons.anchor_right = 0.5
		buttons.anchor_top = 1.0
		buttons.anchor_bottom = 1.0
		buttons.offset_left = -480.0
		buttons.offset_right = 480.0
		buttons.offset_top = -bh
		buttons.offset_bottom = 0.0
		buttons.add_theme_constant_override("h_separation", 18)
		buttons.add_theme_constant_override("v_separation", 10)
		for b in btn_list:
			if b:
				b.custom_minimum_size = Vector2(0, bh)
				b.add_theme_font_size_override("font_size", 30)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if btn_zoom_back:
			btn_zoom_back.anchor_left = 0.0
			btn_zoom_back.anchor_right = 0.0
			btn_zoom_back.anchor_top = 0.0
			btn_zoom_back.anchor_bottom = 0.0
			btn_zoom_back.offset_left = 0.0
			btn_zoom_back.offset_right = 200.0
			btn_zoom_back.offset_top = 0.0
			btn_zoom_back.offset_bottom = 84.0
			btn_zoom_back.add_theme_font_size_override("font_size", 32)
		if speech_bubble and speech_bubble.has_method("set_metrics"):
			speech_bubble.set_metrics(30, 480.0)
		_cam_base_fov = 44.0      # vertical FOV (KEEP_HEIGHT)
		_cam_pitch = -24.0
		_cam_dist = 3.2
		_cam_focus_y = 0.55
	if btn_theme:
		btn_theme.add_theme_font_size_override("font_size", 34 if _portrait else 28)
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

func _bubble_say(text: String, soft: bool = true) -> void:
	if speech_bubble and speech_bubble.has_method("show_line"):
		speech_bubble.show_line(text, soft)
	elif feedback_label:
		feedback_label.text = text

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
	_bubble_say("房间换成「%s」啦" % room_cosmetics.theme_display_name(id))
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

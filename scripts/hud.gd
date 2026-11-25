extends Control
class_name HUDController

class FieldMapView extends Control:
	var player_world_position: Vector2 = Vector2.ZERO
	var safe_world_position: Vector2 = Vector2.ZERO

	func _draw() -> void:
		var map_origin := Vector2(12, 12)
		var map_size := size - Vector2(24, 24)
		var scale_factor := map_size / Vector2(2400, 1600)
		draw_rect(Rect2(Vector2.ZERO, size), Color("#152B25"))
		draw_rect(Rect2(map_origin + Vector2(0, 700) * scale_factor, Vector2(2400, 200) * scale_factor), Color("#28313A"))
		draw_rect(Rect2(map_origin + Vector2(980, 0) * scale_factor, Vector2(240, 1600) * scale_factor), Color("#28313A"))
		for building in [
			Rect2(80, 80, 560, 360), Rect2(1440, 80, 600, 360),
			Rect2(100, 960, 640, 520), Rect2(1460, 960, 540, 420),
			Rect2(720, 80, 200, 240)
		]:
			draw_rect(Rect2(map_origin + building.position * scale_factor, building.size * scale_factor), Color("#B9B7A9"))
		var safe_point := map_origin + safe_world_position * scale_factor
		draw_circle(safe_point, 8, Color("#2ECC71"))
		draw_circle(map_origin + player_world_position * scale_factor, 7, Color("#F4B860"))
		draw_string(ThemeDB.fallback_font, map_origin + Vector2(4, map_size.y + 14), "AMBER: YOU     GREEN: DESIGNATED SAFE ZONE", HORIZONTAL_ALIGNMENT_LEFT, map_size.x, 12, Color("#F1F5F9"))

# Clean, professional Emergency Operations HUD for READY OR NOT
# Displays disaster status, objectives, inventory slots, guide arrow, interaction prompts,
# and AAA Top-Right Quick Utility Bar + Tactical Pause Overlay (layer = 110).

signal pause_toggled(paused: bool)
signal restart_requested
signal handbook_requested
signal return_to_menu_requested
signal input_overlay_toggled(open: bool)
signal interaction_modal_cancelled

var mission_title: String = "THE GROUND REMEMBERS"
var disaster_name: String = "EARTHQUAKE"
var primary_objective: String = "Drop, Cover and Hold On until shaking stops"
var time_remaining: float = 600.0 # 10 minutes

var hazards_count: int = 0
var hazards_required: int = 3
var residents_count: int = 0
var residents_required: int = 2
var supplies: Array[Dictionary] = []
var max_supplies: int = 4
var current_score: int = 1000

var status_text: String = "EMERGENCY ACTIVE"
var status_color: Color = Color("#F4B860")

# Nodes
var timer_label: Label
var title_label: Label
var status_badge: Label
var obj_primary_label: Label
var obj_hazards_label: Label
var obj_residents_label: Label
var score_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var inventory_box: HBoxContainer
var guide_arrow: Control
var scan_btn: Button
var mute_btn: Button

var pause_overlay: CanvasLayer = null
var active_modal_layer: CanvasLayer = null
var info_panel_kind: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	
	# Mute shortcut
	if key_event.keycode == KEY_M:
		toggle_sound()
		get_viewport().set_input_as_handled()
		return
		
	# Tactical Scan toggle
	if key_event.keycode == KEY_TAB:
		Campaign.tactical_scan_active = !Campaign.tactical_scan_active
		_update_scan_button_visual()
		SoundManager.play_ui_click()
		get_viewport().set_input_as_handled()
		return
		
	# Pause / Cancel handling
	if key_event.keycode == KEY_ESCAPE:
		if is_pause_menu_open():
			hide_pause_menu()
			get_viewport().set_input_as_handled()
		elif active_modal_layer != null:
			if info_panel_kind != "":
				close_info_panel()
			else:
				Campaign.modal_active = false
				active_modal_layer.queue_free()
				active_modal_layer = null
				interaction_modal_cancelled.emit()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not get_tree().paused and time_remaining > 0.0:
		time_remaining -= delta
		_update_timer_display()

func _build_ui() -> void:
	# 1. Top Operations Bar
	var top_panel := Panel.new()
	top_panel.position = Vector2(16, 12)
	top_panel.size = Vector2(1248, 86)
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color("#091827", 0.95)
	top_style.border_color = Color("#F4B860")
	top_style.set_border_width_all(2)
	top_style.set_corner_radius_all(8)
	top_panel.add_theme_stylebox_override("panel", top_style)
	add_child(top_panel)
	
	# Title & Disaster
	title_label = Label.new()
	title_label.position = Vector2(20, 10)
	title_label.size = Vector2(440, 24)
	title_label.text = "MISSION: " + mission_title.to_upper() + "  [" + disaster_name + "]"
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.clip_text = false
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color("#F4B860"))
	top_panel.add_child(title_label)
	
	# Primary Objective
	obj_primary_label = Label.new()
	obj_primary_label.position = Vector2(20, 34)
	obj_primary_label.size = Vector2(530, 22)
	obj_primary_label.text = "▶ OBJECTIVE: " + primary_objective
	obj_primary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_primary_label.clip_text = false
	obj_primary_label.add_theme_font_size_override("font_size", 13)
	obj_primary_label.add_theme_color_override("font_color", Color("#FFFFFF"))
	top_panel.add_child(obj_primary_label)
	
	# Emergency Status Badge
	status_badge = Label.new()
	status_badge.position = Vector2(20, 58)
	status_badge.size = Vector2(400, 20)
	status_badge.text = "● STATUS: " + status_text
	status_badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_badge.clip_text = false
	status_badge.add_theme_font_size_override("font_size", 12)
	status_badge.add_theme_color_override("font_color", status_color)
	top_panel.add_child(status_badge)
	
	# Telemetry Checklist counters
	var telemetry_box := HBoxContainer.new()
	telemetry_box.position = Vector2(520, 12)
	telemetry_box.size = Vector2(360, 32)
	telemetry_box.add_theme_constant_override("separation", 16)
	top_panel.add_child(telemetry_box)
	
	obj_hazards_label = Label.new()
	obj_hazards_label.text = "Hazards: 0/3"
	obj_hazards_label.add_theme_font_size_override("font_size", 13)
	obj_hazards_label.add_theme_color_override("font_color", Color("#E2E8F0"))
	telemetry_box.add_child(obj_hazards_label)
	
	obj_residents_label = Label.new()
	obj_residents_label.text = "Rescued: 0/2"
	obj_residents_label.add_theme_font_size_override("font_size", 13)
	obj_residents_label.add_theme_color_override("font_color", Color("#E2E8F0"))
	telemetry_box.add_child(obj_residents_label)
	
	score_label = Label.new()
	score_label.text = "Score: 1000"
	score_label.add_theme_font_size_override("font_size", 13)
	score_label.add_theme_color_override("font_color", Color("#F4B860"))
	telemetry_box.add_child(score_label)
	
	# Tactical Scan button
	scan_btn = Button.new()
	scan_btn.text = "[TAB] SCAN"
	scan_btn.position = Vector2(770, 48)
	scan_btn.size = Vector2(105, 28)
	scan_btn.add_theme_font_size_override("font_size", 11)
	scan_btn.pressed.connect(func():
		Campaign.tactical_scan_active = !Campaign.tactical_scan_active
		_update_scan_button_visual()
	)
	top_panel.add_child(scan_btn)
	_update_scan_button_visual()
	
	# Emergency Countdown Timer
	timer_label = Label.new()
	timer_label.position = Vector2(885, 8)
	timer_label.size = Vector2(110, 36)
	timer_label.text = "10:00"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 26)
	timer_label.add_theme_color_override("font_color", Color("#FF5252"))
	top_panel.add_child(timer_label)
	
	# TOP-RIGHT QUICK UTILITY BAR: [SOUND] [RESTART] [PAUSE]
	var quick_bar := HBoxContainer.new()
	quick_bar.position = Vector2(995, 48)
	quick_bar.size = Vector2(235, 28)
	quick_bar.add_theme_constant_override("separation", 6)
	top_panel.add_child(quick_bar)
	
	mute_btn = Button.new()
	_update_mute_button_visual()
	mute_btn.custom_minimum_size = Vector2(72, 28)
	mute_btn.add_theme_font_size_override("font_size", 11)
	mute_btn.pressed.connect(toggle_sound)
	quick_bar.add_child(mute_btn)
	
	var restart_btn := Button.new()
	restart_btn.text = "↻ RESTART"
	restart_btn.custom_minimum_size = Vector2(75, 28)
	restart_btn.add_theme_font_size_override("font_size", 11)
	restart_btn.pressed.connect(func():
		SoundManager.play_ui_click()
		restart_requested.emit()
	)
	quick_bar.add_child(restart_btn)
	
	var pause_btn := Button.new()
	pause_btn.text = "⏸ PAUSE"
	pause_btn.custom_minimum_size = Vector2(72, 28)
	pause_btn.add_theme_font_size_override("font_size", 11)
	pause_btn.pressed.connect(func():
		SoundManager.play_ui_click()
		show_pause_menu()
	)
	quick_bar.add_child(pause_btn)
	
	# 2. Bottom Inventory Bar
	var inv_panel := Panel.new()
	inv_panel.position = Vector2(20, 630)
	inv_panel.size = Vector2(490, 75)
	var inv_style := StyleBoxFlat.new()
	inv_style.bg_color = Color("#091827", 0.94)
	inv_style.border_color = Color("#2C4257")
	inv_style.set_border_width_all(2)
	inv_style.set_corner_radius_all(8)
	inv_panel.add_theme_stylebox_override("panel", inv_style)
	add_child(inv_panel)
	
	var inv_title := Label.new()
	inv_title.position = Vector2(14, 6)
	inv_title.size = Vector2(300, 18)
	inv_title.text = "EMERGENCY GO-BAG SLOTS:"
	inv_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inv_title.clip_text = false
	inv_title.add_theme_font_size_override("font_size", 11)
	inv_title.add_theme_color_override("font_color", Color("#94A3B8"))
	inv_panel.add_child(inv_title)
	
	inventory_box = HBoxContainer.new()
	inventory_box.position = Vector2(12, 26)
	inventory_box.size = Vector2(466, 42)
	inventory_box.add_theme_constant_override("separation", 8)
	inv_panel.add_child(inventory_box)
	_render_inventory_slots()
	
	# 3. Center Bottom Interaction Prompt
	prompt_panel = PanelContainer.new()
	prompt_panel.position = Vector2(440, 642)
	prompt_panel.size = Vector2(400, 48)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color("#102538", 0.95)
	p_style.border_color = Color("#F4B860")
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(8)
	prompt_panel.add_theme_stylebox_override("panel", p_style)
	add_child(prompt_panel)
	
	prompt_label = Label.new()
	prompt_label.text = "[E] INTERACT"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color("#F4B860"))
	prompt_panel.add_child(prompt_label)
	prompt_panel.visible = false
	
	# 4. Guide Compass Pointer (Top Right)
	guide_arrow = Control.new()
	guide_arrow.position = Vector2(1200, 115)
	guide_arrow.size = Vector2(50, 50)
	add_child(guide_arrow)
	guide_arrow.draw.connect(_draw_guide_arrow)

func toggle_sound() -> void:
	Campaign.sound_enabled = !Campaign.sound_enabled
	_update_mute_button_visual()
	SoundManager.play_ui_click()

func _update_mute_button_visual() -> void:
	if is_instance_valid(mute_btn):
		if Campaign.sound_enabled:
			mute_btn.text = "🔊 ON [M]"
			mute_btn.remove_theme_color_override("font_color")
		else:
			mute_btn.text = "🔇 MUTE [M]"
			mute_btn.add_theme_color_override("font_color", Color("#FF6B6B"))

func _update_scan_button_visual() -> void:
	if is_instance_valid(scan_btn):
		if Campaign.tactical_scan_active:
			scan_btn.text = "[TAB] ON"
			scan_btn.add_theme_color_override("font_color", Color("#2ECC71"))
		else:
			scan_btn.text = "[TAB] SCAN"
			scan_btn.remove_theme_color_override("font_color")

func _update_timer_display() -> void:
	var mins := int(time_remaining) / 60
	var secs := int(time_remaining) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]
	if time_remaining < 60.0:
		timer_label.add_theme_color_override("font_color", Color("#FF1744") if fmod(time_remaining, 0.6) > 0.3 else Color.WHITE)

func update_mission_info(m_title: String, disaster: String, obj: String) -> void:
	mission_title = m_title
	disaster_name = disaster
	primary_objective = obj
	title_label.text = "MISSION: " + mission_title.to_upper() + "  [" + disaster_name + "]"
	obj_primary_label.text = "▶ OBJECTIVE: " + primary_objective

func update_status(text: String, color: Color = Color("#F4B860")) -> void:
	status_text = text
	status_color = color
	status_badge.text = "● STATUS: " + status_text
	status_badge.add_theme_color_override("font_color", status_color)

func update_counters(hazards: int, req_hazards: int, residents: int, req_residents: int, sup_count: int, _req_sup: int) -> void:
	hazards_count = hazards
	hazards_required = req_hazards
	residents_count = residents
	residents_required = req_residents
	
	obj_hazards_label.text = "Hazards: %d/%d" % [hazards, req_hazards]
	obj_residents_label.text = "Rescued: %d/%d" % [residents, req_residents]
	
	if hazards >= req_hazards:
		obj_hazards_label.add_theme_color_override("font_color", Color("#2ECC71"))
	if residents >= req_residents:
		obj_residents_label.add_theme_color_override("font_color", Color("#2ECC71"))

func update_score_display(sc: int) -> void:
	current_score = sc
	if is_instance_valid(score_label):
		score_label.text = "Score: %d" % sc

func add_supply_item(item: Dictionary) -> void:
	supplies.append(item)
	_render_inventory_slots()

func _render_inventory_slots() -> void:
	for child in inventory_box.get_children():
		child.queue_free()
		
	for i in range(max_supplies):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(108, 38)
		var s_style := StyleBoxFlat.new()
		s_style.set_corner_radius_all(6)
		
		var badge := Label.new()
		badge.text = "[%d]" % (i + 1)
		badge.position = Vector2(4, 3)
		badge.size = Vector2(24, 14)
		badge.add_theme_font_size_override("font_size", 9)
		badge.add_theme_color_override("font_color", Color("#F4B860"))
		slot.add_child(badge)
		
		if i < supplies.size():
			s_style.bg_color = Color("#163248")
			s_style.border_color = Color("#4EA8DE")
			s_style.set_border_width_all(1)
			slot.add_theme_stylebox_override("panel", s_style)
			
			var lbl := Label.new()
			lbl.text = supplies[i].get("name", "Item")
			lbl.position = Vector2(24, 4)
			lbl.size = Vector2(80, 30)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.clip_text = false
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", Color("#F4F7F8"))
			slot.add_child(lbl)
		else:
			s_style.bg_color = Color("#0C151F")
			s_style.border_color = Color("#1C2C3C")
			s_style.set_border_width_all(1)
			slot.add_theme_stylebox_override("panel", s_style)
			
			var lbl := Label.new()
			lbl.text = "EMPTY"
			lbl.position = Vector2(24, 10)
			lbl.size = Vector2(80, 20)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", Color("#4A5568"))
			slot.add_child(lbl)
			
		inventory_box.add_child(slot)

func show_prompt(action_text: String) -> void:
	if Campaign.modal_active or is_pause_menu_open():
		prompt_panel.visible = false
		return
	prompt_label.text = "[E]  " + action_text
	prompt_panel.visible = true

func hide_prompt() -> void:
	prompt_panel.visible = false

var guide_target_pos: Vector2 = Vector2.ZERO
var player_world_pos: Vector2 = Vector2.ZERO

func update_guide_target(p_pos: Vector2, target_pos: Vector2) -> void:
	player_world_pos = p_pos
	guide_target_pos = target_pos
	guide_arrow.queue_redraw()

func _draw_guide_arrow() -> void:
	if guide_target_pos == Vector2.ZERO:
		return
	var dir := (guide_target_pos - player_world_pos).normalized()
	var angle := dir.angle()
	
	guide_arrow.draw_circle(Vector2(25, 25), 22.0, Color("#091827", 0.88))
	guide_arrow.draw_circle(Vector2(25, 25), 20.0, Color("#26465B"))
	
	var center := Vector2(25, 25)
	var tip := center + Vector2(cos(angle), sin(angle)) * 16.0
	var left := center + Vector2(cos(angle + 2.5), sin(angle + 2.5)) * 10.0
	var right := center + Vector2(cos(angle - 2.5), sin(angle - 2.5)) * 10.0
	var pts: PackedVector2Array = [tip, left, right]
	guide_arrow.draw_colored_polygon(pts, Color("#2ECC71"))
	guide_arrow.draw_string(ThemeDB.fallback_font, Vector2(0, 48), "SAFE ZONE", HORIZONTAL_ALIGNMENT_CENTER, 50, 9, Color("#A7F3D0"))

# --- TACTICAL PAUSE OVERLAY (CanvasLayer layer = 110) ---

func show_pause_menu() -> void:
	if pause_overlay != null:
		return
	Campaign.modal_active = true
	hide_prompt()
	get_tree().paused = true
	
	pause_overlay = CanvasLayer.new()
	pause_overlay.layer = 110
	add_child(pause_overlay)
	pause_toggled.emit(true)
	input_overlay_toggled.emit(true)
	
	var root := Control.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.add_child(root)
	
	# Dark blur / vignette overlay
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.09, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	
	var p := Panel.new()
	p.position = Vector2(410, 110)
	p.size = Vector2(460, 500)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color("#0C1B2A")
	p_style.border_color = Color("#F4B860")
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", p_style)
	root.add_child(p)
	
	var title := Label.new()
	title.text = "MISSION PAUSED"
	title.position = Vector2(20, 20)
	title.size = Vector2(420, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#F4B860"))
	p.add_child(title)
	
	var sub := Label.new()
	sub.text = "TACTICAL STANDBY // DISASTER SIMULATION FROZEN"
	sub.position = Vector2(20, 52)
	sub.size = Vector2(420, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color("#94A3B8"))
	p.add_child(sub)
	
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(40, 85)
	vbox.size = Vector2(380, 390)
	vbox.add_theme_constant_override("separation", 14)
	p.add_child(vbox)
	
	_add_pause_btn(vbox, "1. CONTINUE MISSION  [ESC]", func(): hide_pause_menu())
	_add_pause_btn(vbox, "2. RESTART MISSION", func():
		hide_pause_menu()
		restart_requested.emit()
	)
	_add_pause_btn(vbox, "3. SOUND & SETTINGS", func(): _show_in_game_settings(root))
	_add_pause_btn(vbox, "4. NDMA HANDBOOK", func():
		var hb := PreparednessHandbook.new()
		root.add_child(hb)
	)
	_add_pause_btn(vbox, "5. ABORT TO MAIN MENU", func():
		get_tree().paused = false
		Campaign.modal_active = false
		if pause_overlay != null:
			pause_overlay.queue_free()
			pause_overlay = null
		return_to_menu_requested.emit()
	)

func _add_pause_btn(parent: Node, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(380, 52)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 15)
	
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color("#091724")
	norm.border_color = Color("#26465B")
	norm.set_border_width_all(1)
	norm.set_corner_radius_all(6)
	norm.content_margin_left = 18
	btn.add_theme_stylebox_override("normal", norm)
	
	var hov := norm.duplicate() as StyleBoxFlat
	hov.bg_color = Color("#11283B")
	hov.border_color = Color("#F4B860")
	hov.border_width_left = 6
	hov.content_margin_left = 22
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("focus", hov)
	btn.add_theme_color_override("font_hover_color", Color("#F4B860"))
	
	btn.mouse_entered.connect(SoundManager.play_ui_hover)
	btn.pressed.connect(func():
		SoundManager.play_ui_click()
		callback.call()
	)
	parent.add_child(btn)
	return btn

func _show_in_game_settings(parent: Node) -> void:
	var set_panel := Panel.new()
	set_panel.position = Vector2(360, 100)
	set_panel.size = Vector2(560, 520)
	var sp_style := StyleBoxFlat.new()
	sp_style.bg_color = Color("#07131F")
	sp_style.border_color = Color("#4EA8DE")
	sp_style.set_border_width_all(2)
	sp_style.set_corner_radius_all(10)
	set_panel.add_theme_stylebox_override("panel", sp_style)
	parent.add_child(set_panel)
	
	var st := Label.new()
	st.text = "SETTINGS // AUDIO & CONTROLS"
	st.position = Vector2(20, 18)
	st.size = Vector2(520, 28)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_theme_font_size_override("font_size", 18)
	st.add_theme_color_override("font_color", Color("#F4B860"))
	set_panel.add_child(st)
	
	var svbox := VBoxContainer.new()
	svbox.position = Vector2(30, 65)
	svbox.size = Vector2(500, 380)
	svbox.add_theme_constant_override("separation", 18)
	set_panel.add_child(svbox)
	
	# Audio Toggle
	var a_row := HBoxContainer.new()
	svbox.add_child(a_row)
	var a_lbl := Label.new()
	a_lbl.text = "AUDIO ENGINE:"
	a_lbl.custom_minimum_size = Vector2(220, 32)
	a_row.add_child(a_lbl)
	var a_btn := Button.new()
	a_btn.text = "ENABLED" if Campaign.sound_enabled else "MUTED"
	a_btn.custom_minimum_size = Vector2(160, 32)
	a_btn.pressed.connect(func():
		toggle_sound()
		a_btn.text = "ENABLED" if Campaign.sound_enabled else "MUTED"
	)
	a_row.add_child(a_btn)
	
	# Screen Shake Toggle
	var sh_row := HBoxContainer.new()
	svbox.add_child(sh_row)
	var sh_lbl := Label.new()
	sh_lbl.text = "SCREEN SHAKE:"
	sh_lbl.custom_minimum_size = Vector2(220, 32)
	sh_row.add_child(sh_lbl)
	var sh_btn := Button.new()
	sh_btn.text = "FULL" if Campaign.screen_shake_enabled else "REDUCED"
	sh_btn.custom_minimum_size = Vector2(160, 32)
	sh_btn.pressed.connect(func():
		Campaign.screen_shake_enabled = !Campaign.screen_shake_enabled
		sh_btn.text = "FULL" if Campaign.screen_shake_enabled else "REDUCED"
		SoundManager.play_ui_click()
	)
	sh_row.add_child(sh_btn)
	
	# Controls quick list
	var c_box := Panel.new()
	c_box.custom_minimum_size = Vector2(500, 180)
	var cp_style := StyleBoxFlat.new()
	cp_style.bg_color = Color("#0A1724")
	cp_style.border_color = Color("#1E364D")
	cp_style.set_border_width_all(1)
	cp_style.set_corner_radius_all(6)
	c_box.add_theme_stylebox_override("panel", cp_style)
	svbox.add_child(c_box)
	
	var c_txt := Label.new()
	c_txt.text = "TACTICAL CONTROLS:\n\n• WASD : 8-Way Movement\n• [E] : Inspect Hazard / Escort Civilian\n• [TAB] : Tactical Radar Scan\n• [1]-[4] : Quick Go-Bag Slots\n• [M] : Quick Audio Mute\n• [ESC] : Pause / Resume"
	c_txt.position = Vector2(16, 12)
	c_txt.size = Vector2(468, 156)
	c_txt.add_theme_font_size_override("font_size", 12)
	c_txt.add_theme_color_override("font_color", Color("#CBD5E1"))
	c_box.add_child(c_txt)
	
	var c_close := Button.new()
	c_close.text = "CLOSE SETTINGS"
	c_close.position = Vector2(190, 460)
	c_close.size = Vector2(180, 42)
	c_close.pressed.connect(func():
		SoundManager.play_ui_click()
		set_panel.queue_free()
	)
	set_panel.add_child(c_close)

func hide_pause_menu() -> void:
	if pause_overlay != null:
		get_tree().paused = false
		Campaign.modal_active = false
		pause_overlay.queue_free()
		pause_overlay = null
		pause_toggled.emit(false)
		input_overlay_toggled.emit(false)

func has_open_info_panel() -> bool:
	return info_panel_kind != ""

func is_pause_menu_open() -> bool:
	return pause_overlay != null

# Dedicated CanvasLayer 100 Modal Dialogs (Hazard Dossier, Resident Dialogue, Info Panels)
func show_hazard_dossier(hazard_data: Dictionary, on_closed: Callable) -> void:
	Campaign.modal_active = true
	hide_prompt()
	
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	active_modal_layer = layer
	
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.09, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	
	var card := Panel.new()
	card.position = Vector2(280, 95)
	card.size = Vector2(720, 515)
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color("#0C1B2A")
	c_style.border_color = Color("#F4B860")
	c_style.set_border_width_all(2)
	c_style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", c_style)
	root.add_child(card)
	
	var h_title := Label.new()
	h_title.text = "HAZARD IDENTIFICATION DOSSIER"
	h_title.position = Vector2(30, 20)
	h_title.size = Vector2(660, 30)
	h_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h_title.clip_text = false
	h_title.add_theme_font_size_override("font_size", 20)
	h_title.add_theme_color_override("font_color", Color("#F4B860"))
	card.add_child(h_title)
	
	var sub := Label.new()
	sub.text = str(hazard_data.get("title", "")) + "  •  CATEGORY: " + str(hazard_data.get("type", "")) + "  •  THREAT: " + str(hazard_data.get("threat", ""))
	sub.position = Vector2(30, 56)
	sub.size = Vector2(660, 24)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.clip_text = false
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color("#E2E8F0"))
	card.add_child(sub)
	
	var desc := Label.new()
	desc.text = "SITUATION ASSESSMENT:\n" + str(hazard_data.get("description", ""))
	desc.position = Vector2(30, 95)
	desc.size = Vector2(660, 95)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.clip_text = false
	desc.add_theme_font_size_override("font_size", 15)
	card.add_child(desc)
	
	var ndma_box := Panel.new()
	ndma_box.position = Vector2(30, 200)
	ndma_box.size = Vector2(660, 200)
	var n_style := StyleBoxFlat.new()
	n_style.bg_color = Color("#11241C")
	n_style.border_color = Color("#2ECC71")
	n_style.set_border_width_all(2)
	n_style.set_corner_radius_all(8)
	ndma_box.add_theme_stylebox_override("panel", n_style)
	card.add_child(ndma_box)
	
	var ndma_head := Label.new()
	ndma_head.text = "OFFICIAL NDMA SAFETY PROTOCOL & DIRECTIVE:"
	ndma_head.position = Vector2(20, 14)
	ndma_head.size = Vector2(620, 24)
	ndma_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ndma_head.clip_text = false
	ndma_head.add_theme_font_size_override("font_size", 14)
	ndma_head.add_theme_color_override("font_color", Color("#2ECC71"))
	ndma_box.add_child(ndma_head)
	
	var ndma_body := Label.new()
	ndma_body.text = str(hazard_data.get("ndma_rule", ""))
	ndma_body.position = Vector2(20, 44)
	ndma_body.size = Vector2(620, 140)
	ndma_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ndma_body.clip_text = false
	ndma_body.add_theme_font_size_override("font_size", 15)
	ndma_body.add_theme_color_override("font_color", Color("#F1F5F9"))
	ndma_box.add_child(ndma_body)
	
	var close_btn := Button.new()
	close_btn.text = "MARK BARRICADED & LOG HAZARD  [ESC]"
	close_btn.position = Vector2(180, 435)
	close_btn.size = Vector2(360, 50)
	close_btn.pressed.connect(func():
		Campaign.modal_active = false
		layer.queue_free()
		active_modal_layer = null
		on_closed.call()
	)
	card.add_child(close_btn)
	close_btn.grab_focus()

func show_resident_dialogue(res_data: Dictionary, on_escort_started: Callable) -> void:
	Campaign.modal_active = true
	hide_prompt()
	
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	active_modal_layer = layer
	
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.09, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	
	var card := Panel.new()
	card.position = Vector2(280, 135)
	card.size = Vector2(720, 440)
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color("#0C1B2A")
	c_style.border_color = Color("#4EA8DE")
	c_style.set_border_width_all(2)
	c_style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", c_style)
	root.add_child(card)
	
	var name_lbl := Label.new()
	name_lbl.text = "RESIDENT ASSISTANCE: " + str(res_data.get("name", "")) + " (Age " + str(res_data.get("age", "")) + ")"
	name_lbl.position = Vector2(30, 20)
	name_lbl.size = Vector2(660, 30)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.clip_text = false
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color("#80D8FF"))
	card.add_child(name_lbl)
	
	var vuln_lbl := Label.new()
	vuln_lbl.text = "VULNERABILITY: " + str(res_data.get("vulnerability", ""))
	vuln_lbl.position = Vector2(30, 56)
	vuln_lbl.size = Vector2(660, 26)
	vuln_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vuln_lbl.clip_text = false
	vuln_lbl.add_theme_font_size_override("font_size", 14)
	vuln_lbl.add_theme_color_override("font_color", Color("#FFAB91"))
	card.add_child(vuln_lbl)
	
	var d_box := Panel.new()
	d_box.position = Vector2(30, 95)
	d_box.size = Vector2(660, 195)
	var d_style := StyleBoxFlat.new()
	d_style.bg_color = Color("#132738")
	d_style.set_corner_radius_all(8)
	d_box.add_theme_stylebox_override("panel", d_style)
	card.add_child(d_box)
	
	var dia_lbl := Label.new()
	dia_lbl.text = "\"" + str(res_data.get("initial_dialogue", "")) + "\""
	dia_lbl.position = Vector2(24, 20)
	dia_lbl.size = Vector2(612, 155)
	dia_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dia_lbl.clip_text = false
	dia_lbl.add_theme_font_size_override("font_size", 16)
	dia_lbl.add_theme_color_override("font_color", Color("#F1F5F9"))
	d_box.add_child(dia_lbl)
	
	var escort_btn := Button.new()
	escort_btn.text = "TAKE UNDER ESCORT & GUIDE TO SAFE ZONE  [ESC/ENTER]"
	escort_btn.position = Vector2(140, 325)
	escort_btn.size = Vector2(440, 52)
	escort_btn.pressed.connect(func():
		Campaign.modal_active = false
		layer.queue_free()
		active_modal_layer = null
		on_escort_started.call()
	)
	card.add_child(escort_btn)
	escort_btn.grab_focus()

func toggle_info_panel(kind: String) -> void:
	if pause_overlay != null:
		return
	if info_panel_kind == kind:
		close_info_panel()
		return
	if active_modal_layer != null:
		return

	var heading := ""
	var body := ""
	match kind:
		"map":
			heading = "AARANYA FIELD MAP"
			body = "CURRENT POSITION: shown by the camera following your coordinator.\n\n"
			body += "MISSION SAFE DESTINATION: " + str(Campaign.MISSION_METADATA[Campaign.mission_id]["target_safe_zone"]) + "\n\n"
			body += "MAP KEY\n"
			body += "Amber markers: hazards to inspect\n"
			body += "Blue markers: emergency supplies\n"
			body += "Red markers: residents needing assistance\n"
			body += "Green marker: designated safe zone\n\n"
			body += "Move around the town streets; do not enter blocked or hazardous routes."
		"inventory":
			heading = "EMERGENCY INVENTORY"
			if supplies.is_empty():
				body = "No emergency supplies collected yet."
			else:
				for item in supplies:
					body += "• " + str(item.get("name", "Emergency supply")) + "\n"
					body += "  " + str(item.get("purpose", "")) + "\n\n"
		"objectives":
			heading = "MISSION OBJECTIVES"
			body = "PRIMARY TASK\n" + primary_objective + "\n\n"
			body += "HAZARDS IDENTIFIED: %d / %d\n" % [hazards_count, hazards_required]
			body += "CIVILIANS RESCUED: %d / %d\n" % [residents_count, residents_required]
			body += "SUPPLIES COLLECTED: %d / %d" % [supplies.size(), 2]
		_:
			return

	Campaign.modal_active = true
	hide_prompt()
	
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	active_modal_layer = layer
	info_panel_kind = kind
	input_overlay_toggled.emit(true)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.09, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	var card := Panel.new()
	card.position = Vector2(280, 95)
	card.size = Vector2(720, 530)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#0C1B2A")
	card_style.border_color = Color("#F4B860")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	card_style.add_theme_stylebox_override("panel", card_style)
	root.add_child(card)

	var title := Label.new()
	title.text = heading
	title.position = Vector2(32, 20)
	title.size = Vector2(656, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.clip_text = false
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#F4B860"))
	card.add_child(title)

	var details := Label.new()
	details.text = body
	details.position = Vector2(44, 80)
	details.size = Vector2(632, 350) if kind != "map" else Vector2(632, 58)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.clip_text = false
	details.add_theme_font_size_override("font_size", 16)
	details.add_theme_color_override("font_color", Color("#F1F5F9"))
	card.add_child(details)

	if kind == "map":
		var field_map := FieldMapView.new()
		field_map.position = Vector2(44, 145)
		field_map.size = Vector2(632, 290)
		field_map.player_world_position = player_world_pos
		match Campaign.mission_id:
			0: field_map.safe_world_position = Vector2(2100, 800)
			1: field_map.safe_world_position = Vector2(1740, 260)
			2: field_map.safe_world_position = Vector2(980, 1300)
		card.add_child(field_map)

	var close_button := Button.new()
	close_button.text = "CLOSE  [ESC]"
	close_button.position = Vector2(250, 460)
	close_button.size = Vector2(220, 48)
	close_button.pressed.connect(close_info_panel)
	card.add_child(close_button)
	close_button.grab_focus()

func close_info_panel() -> void:
	if info_panel_kind == "":
		return
	Campaign.modal_active = false
	if is_instance_valid(active_modal_layer):
		active_modal_layer.queue_free()
	active_modal_layer = null
	info_panel_kind = ""
	input_overlay_toggled.emit(false)

extends Control

# AAA Tactical Main Menu for READY OR NOT: THE LAST 10 MINUTES • AARANYA
# Live stormy Aaranya town backdrop, monsoon weather, lightning & sub-bass thunder,
# glassmorphic menu card with smooth hover animations, and fully wired Mission Select,
# NDMA Handbook, and Settings modals.

var camera_drift_x: float = 0.0
var lightning_timer: float = 8.0
var flash_alpha: float = 0.0
var pulse_line_clock: float = 0.0

# Nodes
var live_backdrop: Control
var flash_rect: ColorRect
var menu_panel: PanelContainer
var buttons: Array[Button] = []
var active_modal_layer: CanvasLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_build_ui()

func _process(delta: float) -> void:
	camera_drift_x += delta * 12.0
	pulse_line_clock += delta * 4.0
	
	# Lightning & thunder scheduling
	lightning_timer -= delta
	if lightning_timer <= 0.0:
		lightning_timer = randf_range(7.0, 11.0)
		_trigger_lightning()
		
	if flash_alpha > 0.0:
		flash_alpha = maxf(0.0, flash_alpha - delta * 3.5)
		if is_instance_valid(flash_rect):
			flash_rect.color = Color(0.9, 0.95, 1.0, flash_alpha * 0.45)
			
	if is_instance_valid(live_backdrop):
		live_backdrop.queue_redraw()

func _trigger_lightning() -> void:
	flash_alpha = 1.0
	SoundManager.play_sfx("thunder")

func _build_ui() -> void:
	# 1. Live Stormy Aaranya Backdrop Layer
	live_backdrop = Control.new()
	live_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	live_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live_backdrop.draw.connect(_draw_live_backdrop)
	add_child(live_backdrop)
	
	# 2. Slanted Monsoon Rain & Earthquake Dust Layer
	var rain_layer := Control.new()
	rain_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rain_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rain_layer.draw.connect(func(): _draw_monsoon_rain(rain_layer))
	add_child(rain_layer)
	
	# 3. Intermittent Lightning Flash Overlay
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0.0)
	add_child(flash_rect)
	
	# 4. Industrial Caution Framing Stripes (Top & Bottom)
	var top_stripe := Control.new()
	top_stripe.position = Vector2.ZERO
	top_stripe.size = Vector2(1280, 8)
	top_stripe.draw.connect(func(): _draw_caution_stripe(top_stripe, 8.0))
	add_child(top_stripe)
	
	var bot_stripe := Control.new()
	bot_stripe.position = Vector2(0, 712)
	bot_stripe.size = Vector2(1280, 8)
	bot_stripe.draw.connect(func(): _draw_caution_stripe(bot_stripe, 8.0))
	add_child(bot_stripe)
	
	# 5. Radial Edge Vignette
	var vignette := Control.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.draw.connect(func(): _draw_vignette(vignette))
	add_child(vignette)
	
	# 6. Incident identity and campaign briefing
	var overline := Label.new()
	overline.position = Vector2(82, 72)
	overline.size = Vector2(700, 24)
	overline.text = "AARANYA DISTRICT  /  EMERGENCY RESPONSE NETWORK"
	overline.add_theme_font_size_override("font_size", 12)
	overline.add_theme_color_override("font_color", Color("#9BB2BD"))
	add_child(overline)

	var network_status := Label.new()
	network_status.position = Vector2(1040, 72)
	network_status.size = Vector2(165, 24)
	network_status.text = "●  SIMULATION READY"
	network_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	network_status.add_theme_font_size_override("font_size", 11)
	network_status.add_theme_color_override("font_color", Color("#86D7B3"))
	add_child(network_status)

	var title_lbl := Label.new()
	title_lbl.position = Vector2(76, 158)
	title_lbl.size = Vector2(730, 78)
	title_lbl.text = "READY OR NOT"
	title_lbl.add_theme_font_size_override("font_size", 62)
	title_lbl.add_theme_color_override("font_color", Color("#F4B860"))
	add_child(title_lbl)

	var subtitle := Label.new()
	subtitle.position = Vector2(82, 238)
	subtitle.size = Vector2(700, 38)
	subtitle.text = "THE LAST 10 MINUTES"
	subtitle.add_theme_font_size_override("font_size", 23)
	subtitle.add_theme_color_override("font_color", Color("#E6EDF0"))
	add_child(subtitle)

	var description := Label.new()
	description.position = Vector2(84, 293)
	description.size = Vector2(660, 62)
	description.text = "A town in crisis. Every decision matters.\nLead your community to safety."
	description.add_theme_font_size_override("font_size", 17)
	description.add_theme_color_override("font_color", Color("#B4C3CA"))
	add_child(description)

	var briefing := Panel.new()
	briefing.position = Vector2(82, 420)
	briefing.size = Vector2(700, 126)
	var briefing_style := StyleBoxFlat.new()
	briefing_style.bg_color = Color("#0B1822", 0.91)
	briefing_style.border_color = Color("#344955")
	briefing_style.set_border_width_all(1)
	briefing_style.border_width_left = 3
	briefing_style.set_corner_radius_all(8)
	briefing_style.content_margin_left = 20
	briefing.add_theme_stylebox_override("panel", briefing_style)
	add_child(briefing)

	var briefing_kicker := Label.new()
	briefing_kicker.position = Vector2(22, 14)
	briefing_kicker.size = Vector2(640, 20)
	briefing_kicker.add_theme_font_size_override("font_size", 11)
	briefing_kicker.add_theme_color_override("font_color", Color("#E8C66A"))
	briefing.add_child(briefing_kicker)

	var operation_id := Campaign.MISSION_METADATA.size() - 1
	var operation_available := false
	for index in range(Campaign.MISSION_METADATA.size()):
		if Campaign.unlocked[index] and not Campaign.completed[index]:
			operation_id = index
			operation_available = true
			break
	var operation: Dictionary = Campaign.MISSION_METADATA[operation_id]
	briefing_kicker.text = ("NEXT OPERATION     /     " + str(operation["act"])) if operation_available else "CAMPAIGN RECORD     /     ALL OPERATIONS COMPLETE"

	var briefing_title := Label.new()
	briefing_title.position = Vector2(22, 40)
	briefing_title.size = Vector2(640, 30)
	briefing_title.text = operation["title"]
	briefing_title.add_theme_font_size_override("font_size", 20)
	briefing_title.add_theme_color_override("font_color", Color("#F0F4F5"))
	briefing.add_child(briefing_title)

	var briefing_details := Label.new()
	briefing_details.position = Vector2(22, 78)
	briefing_details.size = Vector2(650, 22)
	briefing_details.text = "%s     •     %s     •     %d MIN RESPONSE WINDOW" % [
		operation["disaster"], operation["location"], int(int(operation["time_limit"]) / 60)
	]
	briefing_details.add_theme_font_size_override("font_size", 10)
	briefing_details.add_theme_color_override("font_color", Color("#9BB2BD"))
	briefing.add_child(briefing_details)

	var control_hint := Label.new()
	control_hint.position = Vector2(84, 624)
	control_hint.size = Vector2(700, 22)
	control_hint.text = "ARROWS / LEFT STICK  NAVIGATE  •  ENTER / A  SELECT  •  ESC / B  BACK"
	control_hint.add_theme_font_size_override("font_size", 11)
	control_hint.add_theme_color_override("font_color", Color("#81949E"))
	add_child(control_hint)

	# 7. Field operations panel
	menu_panel = PanelContainer.new()
	menu_panel.position = Vector2(850, 165)
	menu_panel.size = Vector2(356, 420)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#0A1721", 0.96)
	card_style.border_color = Color("#344955")
	card_style.set_border_width_all(1)
	card_style.border_width_top = 3
	card_style.set_corner_radius_all(10)
	card_style.content_margin_left = 22
	card_style.content_margin_right = 22
	card_style.content_margin_top = 20
	card_style.content_margin_bottom = 18
	menu_panel.add_theme_stylebox_override("panel", card_style)
	add_child(menu_panel)
	
	var menu_vbox := VBoxContainer.new()
	menu_vbox.add_theme_constant_override("separation", 9)
	menu_panel.add_child(menu_vbox)

	var menu_heading := Label.new()
	menu_heading.text = "FIELD OPERATIONS"
	menu_heading.add_theme_font_size_override("font_size", 19)
	menu_heading.add_theme_color_override("font_color", Color("#EDF3F5"))
	menu_vbox.add_child(menu_heading)

	var menu_subheading := Label.new()
	menu_subheading.text = "SELECT YOUR NEXT ACTION"
	menu_subheading.add_theme_font_size_override("font_size", 10)
	menu_subheading.add_theme_color_override("font_color", Color("#81949E"))
	menu_vbox.add_child(menu_subheading)

	_create_tactical_button(menu_vbox, "DEPLOY CAMPAIGN", _on_new_campaign)
	_create_tactical_button(menu_vbox, "MISSION SELECT", _on_mission_select)
	_create_tactical_button(menu_vbox, "PREPAREDNESS HANDBOOK", _on_handbook)
	_create_tactical_button(menu_vbox, "SYSTEM SETTINGS", _on_settings)
	_create_tactical_button(menu_vbox, "EXIT TO DESKTOP", _on_exit)

	var menu_divider := HSeparator.new()
	menu_divider.custom_minimum_size = Vector2(0, 1)
	menu_vbox.add_child(menu_divider)

	var menu_footer := Label.new()
	menu_footer.text = "OFFLINE TRAINING SIMULATION"
	menu_footer.add_theme_font_size_override("font_size", 9)
	menu_footer.add_theme_color_override("font_color", Color("#718590"))
	menu_vbox.add_child(menu_footer)
	buttons[0].grab_focus()

func _create_tactical_button(parent: Node, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 44)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 13)
	
	var normal_style := StyleBoxFlat.new()
	var is_primary := buttons.is_empty()
	normal_style.bg_color = Color("#D7AA57") if is_primary else Color("#0D1E29")
	normal_style.border_color = Color("#D7AA57") if is_primary else Color("#2A414D")
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(5)
	normal_style.content_margin_left = 14
	btn.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color("#E7BD70") if is_primary else Color("#142B38")
	hover_style.border_color = Color("#F4B860") if is_primary else Color("#73909D")
	hover_style.set_border_width_all(1)
	hover_style.border_width_left = 4
	hover_style.set_corner_radius_all(5)
	hover_style.content_margin_left = 19
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)
	btn.add_theme_color_override("font_color", Color("#17222A") if is_primary else Color("#D8E2E6"))
	btn.add_theme_color_override("font_hover_color", Color("#111C22") if is_primary else Color("#F4B860"))
	btn.add_theme_color_override("font_focus_color", Color("#111C22") if is_primary else Color("#F4B860"))
	
	UIFeedback.attach(btn, Color("#E8C66A"))
	btn.pressed.connect(func():
		callback.call()
	)
	parent.add_child(btn)
	buttons.append(btn)
	return btn

# --- DRAWING LIVE DISASTER BACKDROP ---

func _draw_live_backdrop() -> void:
	var offset_x := fmod(camera_drift_x, 800.0)
	
	# Base dark nocturnal town terrain
	live_backdrop.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("#0B161B"))
	
	# Roads drift slowly beneath
	var road_y := 410.0
	live_backdrop.draw_rect(Rect2(-200 - offset_x * 0.4, road_y, 1800, 130), Color("#181F26"))
	live_backdrop.draw_line(Vector2(0, road_y), Vector2(1280, road_y), Color("#475569"), 2.0)
	live_backdrop.draw_line(Vector2(0, road_y + 130), Vector2(1280, road_y + 130), Color("#475569"), 2.0)
	
	# Center yellow dashes
	for x in range(-200, 1600, 70):
		var dx: float = x - offset_x * 0.4
		live_backdrop.draw_line(Vector2(dx, road_y + 65), Vector2(dx + 35, road_y + 65), Color("#F4B860", 0.7), 3.0)
		
	# Distant town buildings: Aaranya Vidyalaya & Health Clinic silhouettes
	var b1_x: float = 80 - offset_x * 0.25
	_draw_bg_building(Rect2(b1_x, 160, 320, 200), "AARANYA VIDYALAYA", Color("#19242D"), Color("#0E4766"))
	
	var b2_x: float = 780 - offset_x * 0.25
	_draw_bg_building(Rect2(b2_x, 170, 360, 190), "PRIMARY HEALTH CLINIC", Color("#182329"), Color("#00695C"))
	
	# Warm streetlamps with a subtle, time-based flicker
	for i in range(5):
		var lx: float = i * 320 - offset_x * 0.4
		var ly: float = road_y - 15.0
		var flicker := 0.9 + 0.1 * sin(pulse_line_clock * (2.1 + i * 0.13) + i)
		live_backdrop.draw_circle(Vector2(lx, ly), 55.0, Color(1.0, 0.85, 0.4, 0.08 * flicker))
		live_backdrop.draw_circle(Vector2(lx, ly), 5.0, Color("#F4B860"))
		live_backdrop.draw_line(Vector2(lx, ly), Vector2(lx, ly + 25), Color("#334155"), 3.0)
		
	# Pulsing red [! HAZARD] radar beacons
	var pulse := (sin(pulse_line_clock * 2.0) + 1.0) * 0.5
	var beacon_pos := Vector2(420 - offset_x * 0.4, road_y + 65)
	live_backdrop.draw_arc(beacon_pos, 28.0 + pulse * 18.0, 0, TAU, 24, Color(0.95, 0.25, 0.2, 0.4 * (1.0 - pulse)), 2.0)
	live_backdrop.draw_circle(beacon_pos, 8.0, Color("#EF4444"))
	live_backdrop.draw_string(ThemeDB.fallback_font, beacon_pos + Vector2(-30, -16), "! ACTIVE HAZARD", HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color("#FF8A80"))

func _draw_bg_building(rect: Rect2, label: String, bg: Color, accent: Color) -> void:
	live_backdrop.draw_rect(rect, bg)
	live_backdrop.draw_rect(rect, accent, false, 2.0)
	# Rooftop vents
	for vx in range(int(rect.position.x) + 20, int(rect.end.x) - 20, 50):
		live_backdrop.draw_rect(Rect2(vx, rect.position.y + 25, 24, 16), Color("#24313C"))
	# Lit windows
	for wx in range(int(rect.position.x) + 30, int(rect.end.x) - 30, 45):
		for wy in range(int(rect.position.y) + 70, int(rect.end.y) - 30, 40):
			live_backdrop.draw_rect(Rect2(wx, wy, 18, 14), Color(1.0, 0.85, 0.5, 0.25))
	live_backdrop.draw_string(ThemeDB.fallback_font, rect.position + Vector2(16, 22), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32, 11, accent)

func _draw_monsoon_rain(node: Control) -> void:
	# Slanted rain streaks & dust motes
	var seed_val := int(pulse_line_clock * 60.0)
	for i in range(110):
		var rx := fmod(float((seed_val * 37 + i * 197) % 1350), 1280.0)
		var ry := fmod(float((seed_val * 53 + i * 311) % 780), 720.0)
		# Slanted streak (-18 deg)
		node.draw_line(Vector2(rx, ry), Vector2(rx - 8, ry + 22), Color(0.7, 0.85, 1.0, 0.22), 1.2)
		
	# Drifting dust motes
	for j in range(35):
		var dx := fmod(float((seed_val * 17 + j * 431) % 1280), 1280.0)
		var dy := fmod(float((seed_val * 23 + j * 269) % 720), 720.0)
		node.draw_circle(Vector2(dx, dy), 1.8, Color(1.0, 0.95, 0.8, 0.28))

func _draw_seismic_pulse_line(node: Control) -> void:
	var width := 800.0
	var mid_y := 8.0
	var pts := PackedVector2Array()
	for x in range(0, int(width), 8):
		var norm_x: float = x / width
		var wave: float = sin(norm_x * 18.0 - pulse_line_clock * 2.5) * exp(-pow((norm_x - 0.5) * 3.5, 2.0)) * 6.0
		pts.append(Vector2(x, mid_y + wave))
	for i in range(pts.size() - 1):
		node.draw_line(pts[i], pts[i + 1], Color("#F4B860", 0.75), 2.0)

func _draw_caution_stripe(node: Control, height: float) -> void:
	var center_y := height * 0.5
	node.draw_rect(Rect2(0, center_y, 1280, 1), Color("#324550", 0.85))
	node.draw_rect(Rect2(0, center_y - 1, 112, 2), Color("#D7AA57", 0.9))

func _draw_vignette(node: Control) -> void:
	# Subtle dark radial edge vignette
	var center := Vector2(640, 360)
	node.draw_circle(center, 780.0, Color(0.01, 0.03, 0.06, 0.35))
	node.draw_arc(center, 720.0, 0, TAU, 32, Color(0, 0, 0, 0.55), 80.0)

# --- MENU ACTIONS & MODALS ---

func _on_new_campaign() -> void:
	Campaign.reset_campaign()
	SceneTransition.change_scene("res://scenes/mission.tscn")

func _on_mission_select() -> void:
	_open_mission_select_modal()

func _on_handbook() -> void:
	var hb := PreparednessHandbook.new()
	hb.closed.connect(func(): active_modal_layer = null)
	add_child(hb)
	active_modal_layer = hb

func _on_settings() -> void:
	_open_settings_modal()

func _on_exit() -> void:
	get_tree().quit()

# --- MISSION SELECT MODAL ---

func _open_mission_select_modal() -> void:
	if active_modal_layer != null:
		return
		
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	active_modal_layer = layer
	
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.09, 0.90)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	
	var card := Panel.new()
	card.position = Vector2(220, 70)
	card.size = Vector2(840, 580)
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color("#0C1B2A")
	c_style.border_color = Color("#F4B860")
	c_style.set_border_width_all(2)
	c_style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", c_style)
	root.add_child(card)
	
	var title := Label.new()
	title.text = "MISSION SELECT // TACTICAL CRISIS DEPLOYMENT"
	title.position = Vector2(40, 20)
	title.size = Vector2(760, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#F4B860"))
	card.add_child(title)
	
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(40, 75)
	vbox.size = Vector2(760, 420)
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)
	
	for meta in Campaign.MISSION_METADATA:
		var act_btn := Button.new()
		act_btn.custom_minimum_size = Vector2(760, 110)
		act_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var b_style := StyleBoxFlat.new()
		b_style.bg_color = Color("#091724")
		b_style.border_color = meta["color"]
		b_style.set_border_width_all(1)
		b_style.border_width_left = 6
		b_style.set_corner_radius_all(6)
		b_style.content_margin_left = 18
		b_style.content_margin_top = 10
		b_style.content_margin_right = 18
		b_style.content_margin_bottom = 10
		act_btn.add_theme_stylebox_override("normal", b_style)
		
		var h_style := b_style.duplicate() as StyleBoxFlat
		h_style.bg_color = Color("#11283B")
		h_style.border_width_left = 10
		act_btn.add_theme_stylebox_override("hover", h_style)
		act_btn.add_theme_stylebox_override("focus", h_style)
		
		var btn_vbox := VBoxContainer.new()
		btn_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		act_btn.add_child(btn_vbox)
		
		var act_head := Label.new()
		act_head.text = "%s: %s [%s]" % [meta["act"], meta["title"], meta["disaster"]]
		act_head.add_theme_font_size_override("font_size", 16)
		act_head.add_theme_color_override("font_color", meta["color"])
		btn_vbox.add_child(act_head)
		
		var act_loc := Label.new()
		act_loc.text = "LOCATION: " + meta["location"] + "  •  SAFE DESTINATION: " + meta["target_safe_zone"]
		act_loc.add_theme_font_size_override("font_size", 12)
		act_loc.add_theme_color_override("font_color", Color("#94A3B8"))
		btn_vbox.add_child(act_loc)
		
		var act_sub := Label.new()
		act_sub.text = meta["subtitle"]
		act_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		act_sub.clip_text = false
		act_sub.add_theme_font_size_override("font_size", 12)
		act_sub.add_theme_color_override("font_color", Color("#E2E8F0"))
		btn_vbox.add_child(act_sub)
		
		var idx: int = meta["id"]
		UIFeedback.attach(act_btn, meta["color"], false)
		act_btn.pressed.connect(func():
			SoundManager.play_ui_click()
			Campaign.mission_id = idx
			layer.queue_free()
			active_modal_layer = null
			SceneTransition.change_scene("res://scenes/mission.tscn")
		)
		vbox.add_child(act_btn)
		
	var back_btn := Button.new()
	back_btn.text = "RETURN TO MAIN MENU  [ESC]"
	back_btn.position = Vector2(280, 515)
	back_btn.size = Vector2(280, 45)
	back_btn.pressed.connect(func():
		SoundManager.play_ui_click()
		layer.queue_free()
		active_modal_layer = null
	)
	UIFeedback.attach(back_btn, Color("#F4B860"), false)
	card.add_child(back_btn)
	back_btn.grab_focus()

# --- SETTINGS MODAL ---

func _open_settings_modal() -> void:
	if active_modal_layer != null:
		return
		
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	active_modal_layer = layer
	
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.09, 0.90)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	
	var card := Panel.new()
	card.position = Vector2(260, 60)
	card.size = Vector2(760, 600)
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color("#0C1B2A")
	c_style.border_color = Color("#F4B860")
	c_style.set_border_width_all(2)
	c_style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", c_style)
	root.add_child(card)
	
	var title := Label.new()
	title.text = "SYSTEM SETTINGS & CONTROLS CHEATSHEET"
	title.position = Vector2(30, 20)
	title.size = Vector2(700, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#F4B860"))
	card.add_child(title)
	
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(40, 75)
	vbox.size = Vector2(680, 440)
	vbox.add_theme_constant_override("separation", 20)
	card.add_child(vbox)
	
	# Audio Toggle
	var audio_row := HBoxContainer.new()
	vbox.add_child(audio_row)
	var audio_lbl := Label.new()
	audio_lbl.text = "MASTER AUDIO ENGINE:"
	audio_lbl.custom_minimum_size = Vector2(300, 36)
	audio_lbl.add_theme_font_size_override("font_size", 16)
	audio_row.add_child(audio_lbl)
	
	var audio_toggle := CheckButton.new()
	audio_toggle.text = "MUTED" if not Campaign.sound_enabled else "ENABLED"
	audio_toggle.button_pressed = Campaign.sound_enabled
	audio_toggle.toggled.connect(func(pressed: bool):
		Campaign.sound_enabled = pressed
		audio_toggle.text = "ENABLED" if pressed else "MUTED"
		SoundManager.play_ui_click()
	)
	audio_row.add_child(audio_toggle)
	
	# SFX Volume Slider
	var vol_row := HBoxContainer.new()
	vbox.add_child(vol_row)
	var vol_lbl := Label.new()
	vol_lbl.text = "AUDIO VOLUME (SFX & SIRENS):"
	vol_lbl.custom_minimum_size = Vector2(300, 36)
	vol_lbl.add_theme_font_size_override("font_size", 16)
	vol_row.add_child(vol_lbl)
	
	var vol_slider := HSlider.new()
	vol_slider.custom_minimum_size = Vector2(260, 36)
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	vol_slider.value = Campaign.sfx_volume
	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(Campaign.sfx_volume * 100.0)
	val_lbl.custom_minimum_size = Vector2(60, 36)
	vol_slider.value_changed.connect(func(v: float):
		Campaign.sfx_volume = v
		val_lbl.text = "%d%%" % int(v * 100.0)
	)
	vol_row.add_child(vol_slider)
	vol_row.add_child(val_lbl)
	
	# Screen Shake Toggle
	var shake_row := HBoxContainer.new()
	vbox.add_child(shake_row)
	var shake_lbl := Label.new()
	shake_lbl.text = "EARTHQUAKE SCREEN SHAKE:"
	shake_lbl.custom_minimum_size = Vector2(300, 36)
	shake_lbl.add_theme_font_size_override("font_size", 16)
	shake_row.add_child(shake_lbl)
	
	var shake_btn := Button.new()
	shake_btn.text = "FULL (INTENSE)" if Campaign.screen_shake_enabled else "REDUCED (ACCESSIBILITY)"
	shake_btn.custom_minimum_size = Vector2(220, 36)
	shake_btn.pressed.connect(func():
		Campaign.screen_shake_enabled = !Campaign.screen_shake_enabled
		shake_btn.text = "FULL (INTENSE)" if Campaign.screen_shake_enabled else "REDUCED (ACCESSIBILITY)"
		SoundManager.play_ui_click()
	)
	UIFeedback.attach(shake_btn, Color("#F4B860"), false)
	shake_row.add_child(shake_btn)
	
	# Tactical Controls Cheatsheet
	var cheat_panel := Panel.new()
	cheat_panel.custom_minimum_size = Vector2(680, 180)
	var cp_style := StyleBoxFlat.new()
	cp_style.bg_color = Color("#07121D")
	cp_style.border_color = Color("#1E364D")
	cp_style.set_border_width_all(1)
	cp_style.set_corner_radius_all(6)
	cheat_panel.add_theme_stylebox_override("panel", cp_style)
	vbox.add_child(cheat_panel)
	
	var cheat_text := Label.new()
	cheat_text.text = "TACTICAL CONTROLS DIRECTORY:\n\n" + \
		"• WASD / ARROW KEYS : 8-Way Responder Movement & Directional Aim\n" + \
		"• [E] KEY : Inspect Hazards / Barricade Danger / Assist Civilians\n" + \
		"• [TAB] KEY : Tactical Scan Toggle (Reveals In-World Hazard & Supply Pills)\n" + \
		"• [1] - [4] KEYS : Instant Go-Bag Equipment Slots Access\n" + \
		"• [M] KEY : Quick Master Audio Mute Toggle\n" + \
		"• [ESC] KEY : Pause Tactical Operations & View Safety Handbook"
	cheat_text.position = Vector2(20, 15)
	cheat_text.size = Vector2(640, 150)
	cheat_text.add_theme_font_size_override("font_size", 13)
	cheat_text.add_theme_color_override("font_color", Color("#CBD5E1"))
	cheat_panel.add_child(cheat_text)
	
	var close_btn := Button.new()
	close_btn.text = "SAVE & RETURN  [ESC]"
	close_btn.position = Vector2(240, 535)
	close_btn.size = Vector2(280, 45)
	close_btn.pressed.connect(func():
		SoundManager.play_ui_click()
		layer.queue_free()
		active_modal_layer = null
	)
	UIFeedback.attach(close_btn, Color("#F4B860"), false)
	card.add_child(close_btn)
	close_btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if active_modal_layer != null and event.is_action_pressed("ui_cancel"):
		SoundManager.play_ui_click()
		active_modal_layer.queue_free()
		active_modal_layer = null
		get_viewport().set_input_as_handled()

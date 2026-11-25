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
	
	# 6. Title Header & Sector Badge
	var header_box := VBoxContainer.new()
	header_box.position = Vector2(240, 50)
	header_box.size = Vector2(800, 150)
	header_box.add_theme_constant_override("separation", 6)
	add_child(header_box)
	
	var title_lbl := Label.new()
	title_lbl.text = "READY OR NOT"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 52)
	title_lbl.add_theme_color_override("font_color", Color("#F4B860"))
	header_box.add_child(title_lbl)
	
	# Horizontal seismic pulse line underneath title
	var pulse_line := Control.new()
	pulse_line.custom_minimum_size = Vector2(800, 16)
	pulse_line.draw.connect(func(): _draw_seismic_pulse_line(pulse_line))
	header_box.add_child(pulse_line)
	
	var subtitle_badge := Label.new()
	subtitle_badge.text = "NDMA DOCTRINE SIMULATION // SECTOR: AARANYA // STATUS: CRITICAL"
	subtitle_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_badge.add_theme_font_size_override("font_size", 13)
	subtitle_badge.add_theme_color_override("font_color", Color("#38BDF8"))
	header_box.add_child(subtitle_badge)
	
	# 7. Glassmorphic Tactical Menu Card (Tightly wraps buttons, no empty bottom padding)
	menu_panel = PanelContainer.new()
	menu_panel.position = Vector2(450, 230)
	menu_panel.size = Vector2(380, 390)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.08, 0.13, 0.88)
	card_style.border_color = Color("#F4B860")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	card_style.content_margin_left = 24
	card_style.content_margin_right = 24
	card_style.content_margin_top = 22
	card_style.content_margin_bottom = 22
	menu_panel.add_theme_stylebox_override("panel", card_style)
	add_child(menu_panel)
	
	var menu_vbox := VBoxContainer.new()
	menu_vbox.add_theme_constant_override("separation", 14)
	menu_panel.add_child(menu_vbox)
	
	_create_tactical_button(menu_vbox, "NEW CAMPAIGN", _on_new_campaign)
	_create_tactical_button(menu_vbox, "MISSION SELECT", _on_mission_select)
	_create_tactical_button(menu_vbox, "PREPAREDNESS HANDBOOK", _on_handbook)
	_create_tactical_button(menu_vbox, "SETTINGS", _on_settings)
	_create_tactical_button(menu_vbox, "EXIT TO DESKTOP", _on_exit)

func _create_tactical_button(parent: Node, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(332, 46)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 15)
	
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("#0A1926", 0.90)
	normal_style.border_color = Color("#26465B")
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(6)
	normal_style.content_margin_left = 18
	btn.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color("#122A3E", 0.95)
	hover_style.border_color = Color("#F4B860")
	hover_style.set_border_width_all(1)
	hover_style.border_width_left = 6
	hover_style.set_corner_radius_all(6)
	hover_style.content_margin_left = 24 # +6px smooth slide feel
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)
	btn.add_theme_color_override("font_hover_color", Color("#F4B860"))
	btn.add_theme_color_override("font_focus_color", Color("#F4B860"))
	
	btn.mouse_entered.connect(func(): SoundManager.play_ui_hover())
	btn.pressed.connect(func():
		SoundManager.play_ui_click()
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
	
	# Flickering yellow streetlamps along road
	for i in range(5):
		var lx: float = i * 320 - offset_x * 0.4
		var ly: float = road_y - 15.0
		var flicker := randf_range(0.85, 1.0)
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
	var w := 1280.0
	var stripe_w := 24.0
	var offset := fmod(camera_drift_x * 0.5, stripe_w * 2.0)
	var x := -stripe_w * 2.0 + offset
	while x < w + stripe_w * 2.0:
		var pts: PackedVector2Array = [
			Vector2(x, 0), Vector2(x + stripe_w, 0),
			Vector2(x + stripe_w - 6, height), Vector2(x - 6, height)
		]
		node.draw_colored_polygon(pts, Color("#F59E0B", 0.85))
		x += stripe_w * 2.0

func _draw_vignette(node: Control) -> void:
	# Subtle dark radial edge vignette
	var center := Vector2(640, 360)
	node.draw_circle(center, 780.0, Color(0.01, 0.03, 0.06, 0.35))
	node.draw_arc(center, 720.0, 0, TAU, 32, Color(0, 0, 0, 0.55), 80.0)

# --- MENU ACTIONS & MODALS ---

func _on_new_campaign() -> void:
	Campaign.reset_campaign()
	get_tree().change_scene_to_file("res://scenes/mission.tscn")

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
		act_btn.mouse_entered.connect(SoundManager.play_ui_hover)
		act_btn.pressed.connect(func():
			SoundManager.play_ui_click()
			Campaign.mission_id = idx
			layer.queue_free()
			active_modal_layer = null
			get_tree().change_scene_to_file("res://scenes/mission.tscn")
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
	card.add_child(close_btn)
	close_btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if active_modal_layer != null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		SoundManager.play_ui_click()
		active_modal_layer.queue_free()
		active_modal_layer = null
		get_viewport().set_input_as_handled()

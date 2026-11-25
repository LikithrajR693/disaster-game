extends CanvasLayer
class_name CampaignReport

# Official Aaranya District Disaster Management Authority (DDMA) Campaign Report
# Dedicated CanvasLayer (layer = 100) with backdrop dimmer.
# Summarizes performance across all 3 disaster scenarios and issues an emergency responder certificate.

signal closed

func _init() -> void:
	layer = 100

func _ready() -> void:
	Campaign.modal_active = true
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.05, 0.09, 0.92)
	root.add_child(bg)
	
	var panel := Panel.new()
	panel.position = Vector2(100, 35)
	panel.size = Vector2(1080, 650)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color("#0C1B2A")
	p_style.border_color = Color("#F4B860")
	p_style.set_border_width_all(3)
	p_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", p_style)
	root.add_child(panel)
	
	var summary: Dictionary = Campaign.get_campaign_summary()
	var all_done: bool = summary.get("all_cleared", false)
	var grade: String = summary.get("grade", "INCOMPLETE")
	var total_score: int = summary.get("total_score", 0)
	var total_residents: int = summary.get("total_residents", 0)
	var total_hazards: int = summary.get("total_hazards", 0)
	
	# Certificate Header Banner
	var head := Panel.new()
	head.position = Vector2(0, 0)
	head.size = Vector2(1080, 80)
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color("#172E44")
	h_style.set_corner_radius_all(8)
	head.add_theme_stylebox_override("panel", h_style)
	panel.add_child(head)
	
	var title := Label.new()
	title.text = "AARANYA DISTRICT DISASTER MANAGEMENT COMMISSION"
	title.position = Vector2(40, 16)
	title.size = Vector2(1000, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.clip_text = false
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#F4B860"))
	head.add_child(title)
	
	var sub := Label.new()
	sub.text = "OFFICIAL READINESS CERTIFICATE & AFTER-ACTION ACCREDITATION"
	sub.position = Vector2(40, 46)
	sub.size = Vector2(1000, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.clip_text = false
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color("#94A3B8"))
	head.add_child(sub)
	
	# Certificate Border Body
	var cert_card := Panel.new()
	cert_card.position = Vector2(40, 105)
	cert_card.size = Vector2(1000, 450)
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color("#07121D")
	c_style.border_color = Color("#2ECC71") if all_done else Color("#F4B860")
	c_style.set_border_width_all(2)
	c_style.set_corner_radius_all(8)
	cert_card.add_theme_stylebox_override("panel", c_style)
	panel.add_child(cert_card)
	
	var cert_status := Label.new()
	cert_status.text = "COMMENDATION LEVEL: " + grade
	cert_status.position = Vector2(30, 20)
	cert_status.size = Vector2(940, 36)
	cert_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cert_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cert_status.clip_text = false
	cert_status.add_theme_font_size_override("font_size", 20)
	cert_status.add_theme_color_override("font_color", Color("#2ECC71") if all_done else Color("#F4B860"))
	cert_card.add_child(cert_status)
	
	# Statistics Grid
	var grid := GridContainer.new()
	grid.position = Vector2(120, 75)
	grid.size = Vector2(760, 100)
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 16)
	cert_card.add_child(grid)
	
	_add_stat_card(grid, "DISASTERS RESOLVED", "%d / 3" % summary.get("missions_cleared", 0))
	_add_stat_card(grid, "TOWNSFOLK EVACUATED", "%d / 6" % total_residents)
	_add_stat_card(grid, "HAZARDS BARRICADED", "%d / 9" % total_hazards)
	_add_stat_card(grid, "TOTAL SAFETY SCORE", "%d PTS" % total_score)
	_add_stat_card(grid, "NDMA COMPLIANCE", "98% (OPTIMAL)" if all_done else "IN PROGRESS")
	_add_stat_card(grid, "OPERATIONAL STATUS", "READY FOR CRISIS" if all_done else "TRAINING INCOMPLETE")
	
	# Commendation Prose
	var prose := Label.new()
	prose.text = ("This document certifies that the Emergency Response Coordinator has successfully demonstrated practical mastery of the Indian National Disaster Management Authority (NDMA) core life-safety doctrines across Earthquake, Flood, and Fire incidents.\n\n" +
		"By correctly executing Drop, Cover & Hold On, enforcing 'Turn Around Don't Drown' during flash flooding, and adhering to strict stairwell-only evacuation beneath smoke layers, the coordinator preserved vulnerable human lives and maintained civil emergency order.") if all_done else ("The Aaranya Emergency Response Campaign is currently in progress. Complete all three disaster scenarios (Earthquake, Flood, and Fire) to earn full NDMA Accreditation.")
	prose.position = Vector2(50, 205)
	prose.size = Vector2(900, 140)
	prose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prose.clip_text = false
	prose.add_theme_font_size_override("font_size", 15)
	prose.add_theme_color_override("font_color", Color("#CBD5E1"))
	cert_card.add_child(prose)
	
	# Sign-off seal
	var seal := Label.new()
	seal.text = "COMMISSIONER OF RELIEF & DISASTER RECOVERY\nAARANYA DISTRICT ADMINISTRATION\nMINISTRY OF HOME AFFAIRS, GOVT OF INDIA"
	seal.position = Vector2(50, 365)
	seal.size = Vector2(900, 60)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	seal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	seal.clip_text = false
	seal.add_theme_font_size_override("font_size", 12)
	seal.add_theme_color_override("font_color", Color("#94A3B8"))
	cert_card.add_child(seal)
	
	# Close button
	var btn := Button.new()
	btn.text = "RETURN TO MAIN MENU  [ESC]"
	btn.position = Vector2(400, 580)
	btn.size = Vector2(280, 48)
	btn.pressed.connect(func():
		Campaign.modal_active = false
		SoundManager.play_sfx("click")
		closed.emit()
		queue_free()
	)
	panel.add_child(btn)
	btn.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Campaign.modal_active = false
		SoundManager.play_sfx("click")
		closed.emit()
		queue_free()
		get_viewport().set_input_as_handled()

func _add_stat_card(parent: Node, label: String, val: String) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(220, 45)
	var l := Label.new()
	l.text = label
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = false
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color("#94A3B8"))
	box.add_child(l)
	var v := Label.new()
	v.text = val
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.clip_text = false
	v.add_theme_font_size_override("font_size", 18)
	v.add_theme_color_override("font_color", Color("#F4B860"))
	box.add_child(v)
	parent.add_child(box)

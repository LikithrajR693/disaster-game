extends CanvasLayer
class_name MissionDebrief

# Comprehensive Mission Debrief & After-Action Report
# Dedicated CanvasLayer (layer = 100) with backdrop dimmer.
# Displays performance score, action breakdown, NDMA doctrine analysis, and interactive knowledge quiz.

signal continue_requested
signal replay_requested
signal menu_requested

var mission_id: int = 0
var report_data: Dictionary = {}

var quiz_answered: bool = false
var quiz_box: VBoxContainer
var quiz_feedback_label: Label

const QUIZ_DATA: Array[Dictionary] = [
	{
		"question": "During an earthquake, why is running outdoors into the street extremely dangerous according to the NDMA?",
		"options": [
			{"text": "Falling glass, parapets, roof tiles, and facade masonry collapse directly onto street exits.", "correct": true},
			{"text": "Earthquakes open giant chasms that swallow people instantly.", "correct": false},
			{"text": "Outdoor air becomes poisonous during seismic friction.", "correct": false}
		],
		"explanation": "NDMA research shows the greatest hazard during shaking is falling exterior debris (cornices, bricks, window glass) near building perimeters. Dropping under sturdy cover inside is statistically far safer."
	},
	{
		"question": "What is the primary danger when attempting to cross even shallow-looking floodwaters?",
		"options": [
			{"text": "Flowing water conceals missing manholes, electrical currents, and sweeps adults away in just 6 inches.", "correct": true},
			{"text": "Floodwaters contain radioactive fallout from clouds.", "correct": false},
			{"text": "Shallow water causes boots to instantly dissolve.", "correct": false}
		],
		"explanation": "'Turn Around, Don't Drown'. Just 6 inches of moving water can knock down an adult, and 12 inches can sweep away cars. Floodwater also conceals missing manhole covers and live submerged power lines."
	},
	{
		"question": "Why must you NEVER use an elevator during a building fire evacuation?",
		"options": [
			{"text": "Elevator shafts act as smoke chimneys, and electrical cutoff can trap you inside.", "correct": true},
			{"text": "Elevators travel too slowly for modern fire codes.", "correct": false},
			{"text": "Elevator buttons become magnetized by fire heat.", "correct": false}
		],
		"explanation": "Elevator shafts act like chimneys, channeling toxic smoke and heated gases upwards. Power failure is almost certain during fires, creating an inescapable metal incinerator. Always use fire stairs."
	}
]

func _init() -> void:
	layer = 100

func setup(m_id: int, report: Dictionary) -> void:
	mission_id = m_id
	report_data = report
	Campaign.modal_active = true
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	
	# Dark semi-transparent backdrop dimmer
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.05, 0.09, 0.88)
	root.add_child(bg)
	
	# Main Panel
	var panel := Panel.new()
	panel.position = Vector2(60, 25)
	panel.size = Vector2(1160, 670)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color("#0C1B2A")
	p_style.border_color = Color("#F4B860")
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", p_style)
	root.add_child(panel)
	
	var passed: bool = report_data.get("passed", false)
	var score: int = report_data.get("score", 0)
	var grade: String = report_data.get("grade", "A")
	
	var header_bar := Panel.new()
	header_bar.position = Vector2(0, 0)
	header_bar.size = Vector2(1160, 65)
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color("#11241C") if passed else Color("#2A1212")
	h_style.set_corner_radius_all(8)
	header_bar.add_theme_stylebox_override("panel", h_style)
	panel.add_child(header_bar)
	
	var title_lbl := Label.new()
	title_lbl.text = "AFTER-ACTION DEBRIEF: MISSION %d — %s" % [mission_id + 1, "PASSED" if passed else "INCOMPLETE"]
	title_lbl.position = Vector2(30, 16)
	title_lbl.size = Vector2(700, 32)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.clip_text = false
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color("#2ECC71") if passed else Color("#E74C3C"))
	header_bar.add_child(title_lbl)
	
	var score_lbl := Label.new()
	score_lbl.text = "GRADE: %s  •  SAFETY SCORE: %d PTS" % [grade, score]
	score_lbl.position = Vector2(750, 16)
	score_lbl.size = Vector2(380, 32)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	score_lbl.clip_text = false
	score_lbl.add_theme_font_size_override("font_size", 20)
	score_lbl.add_theme_color_override("font_color", Color("#F4B860"))
	header_bar.add_child(score_lbl)
	
	# Left Column: Statistics & Action Log
	var stats_title := Label.new()
	stats_title.text = "FIELD EVALUATION BREAKDOWN"
	stats_title.position = Vector2(30, 80)
	stats_title.size = Vector2(520, 24)
	stats_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_title.clip_text = false
	stats_title.add_theme_font_size_override("font_size", 16)
	stats_title.add_theme_color_override("font_color", Color("#4EA8DE"))
	panel.add_child(stats_title)
	
	var stats_box := Panel.new()
	stats_box.position = Vector2(30, 110)
	stats_box.size = Vector2(530, 95)
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = Color("#07121D")
	sb_style.border_color = Color("#1E364D")
	sb_style.set_border_width_all(1)
	sb_style.set_corner_radius_all(6)
	stats_box.add_theme_stylebox_override("panel", sb_style)
	panel.add_child(stats_box)
	
	var stats_txt := Label.new()
	stats_txt.text = "• Hazards Neutralized & Barricaded: %d/3\n• Residents Evacuated to Safety: %d/2\n• Essential Disaster Supplies Secured: %d/2\n• Evacuation Status: %s" % [
		report_data.get("hazards", 0),
		report_data.get("residents", 0),
		report_data.get("supplies", 0),
		"ALL OBJECTIVES SECURED" if passed else "PARTIAL CASUALTIES / INCOMPLETE"
	]
	stats_txt.position = Vector2(16, 10)
	stats_txt.size = Vector2(500, 75)
	stats_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_txt.clip_text = false
	stats_txt.add_theme_font_size_override("font_size", 14)
	stats_box.add_child(stats_txt)
	
	# Decision Log
	var log_title := Label.new()
	log_title.text = "KEY EMERGENCY DECISIONS LOGGED"
	log_title.position = Vector2(30, 215)
	log_title.size = Vector2(520, 24)
	log_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_title.clip_text = false
	log_title.add_theme_font_size_override("font_size", 16)
	log_title.add_theme_color_override("font_color", Color("#4EA8DE"))
	panel.add_child(log_title)
	
	var log_box := Panel.new()
	log_box.position = Vector2(30, 245)
	log_box.size = Vector2(530, 275)
	var lb_style := StyleBoxFlat.new()
	lb_style.bg_color = Color("#07121D")
	lb_style.border_color = Color("#1E364D")
	lb_style.set_border_width_all(1)
	lb_style.set_corner_radius_all(6)
	log_box.add_theme_stylebox_override("panel", lb_style)
	panel.add_child(log_box)
	
	var log_label := RichTextLabel.new()
	log_label.position = Vector2(14, 12)
	log_label.size = Vector2(502, 250)
	log_label.bbcode_enabled = true
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_box.add_child(log_label)
	
	var log_lines := ""
	var decisions: Array = report_data.get("decisions", [])
	for d in decisions:
		var safe: bool = d.get("safe", true)
		if safe:
			log_lines += "[color=#2ECC71]✔ " + d.get("text", "") + "[/color]\n[color=#94A3B8]" + d.get("exp", "") + "[/color]\n\n"
		else:
			log_lines += "[color=#E74C3C]✖ " + d.get("text", "") + "[/color]\n[color=#FFAB91]" + d.get("exp", "") + "[/color]\n\n"
	log_label.text = log_lines
	
	# Right Column: NDMA Knowledge Check Quiz
	var quiz_title := Label.new()
	quiz_title.text = "NDMA DISASTER KNOWLEDGE VALIDATION"
	quiz_title.position = Vector2(590, 80)
	quiz_title.size = Vector2(540, 24)
	quiz_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiz_title.clip_text = false
	quiz_title.add_theme_font_size_override("font_size", 16)
	quiz_title.add_theme_color_override("font_color", Color("#F4B860"))
	panel.add_child(quiz_title)
	
	var q_card := Panel.new()
	q_card.position = Vector2(590, 110)
	q_card.size = Vector2(540, 410)
	var qc_style := StyleBoxFlat.new()
	qc_style.bg_color = Color("#07121D")
	qc_style.border_color = Color("#26465B")
	qc_style.set_border_width_all(1)
	qc_style.set_corner_radius_all(6)
	q_card.add_theme_stylebox_override("panel", qc_style)
	panel.add_child(q_card)
	
	var q_data: Dictionary = QUIZ_DATA[mission_id]
	
	var q_lbl := Label.new()
	q_lbl.text = "QUESTION:\n" + str(q_data.get("question", ""))
	q_lbl.position = Vector2(20, 14)
	q_lbl.size = Vector2(500, 80)
	q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_lbl.clip_text = false
	q_lbl.add_theme_font_size_override("font_size", 15)
	q_lbl.add_theme_color_override("font_color", Color("#FFFFFF"))
	q_card.add_child(q_lbl)
	
	quiz_box = VBoxContainer.new()
	quiz_box.position = Vector2(20, 100)
	quiz_box.size = Vector2(500, 180)
	quiz_box.add_theme_constant_override("separation", 10)
	q_card.add_child(quiz_box)
	
	for opt in q_data.get("options", []):
		var btn := Button.new()
		btn.text = "• " + str(opt.get("text", ""))
		btn.custom_minimum_size = Vector2(500, 52)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.clip_text = false
		btn.add_theme_font_size_override("font_size", 13)
		var is_cor: bool = opt.get("correct", false)
		var exp: String = q_data.get("explanation", "")
		btn.pressed.connect(func(): _on_quiz_answered(is_cor, exp))
		quiz_box.add_child(btn)
		
	quiz_feedback_label = Label.new()
	quiz_feedback_label.position = Vector2(20, 290)
	quiz_feedback_label.size = Vector2(500, 110)
	quiz_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiz_feedback_label.clip_text = false
	quiz_feedback_label.add_theme_font_size_override("font_size", 13)
	q_card.add_child(quiz_feedback_label)
	
	# Bottom Navigation Buttons
	var nav_box := HBoxContainer.new()
	nav_box.position = Vector2(30, 590)
	nav_box.size = Vector2(1100, 50)
	nav_box.add_theme_constant_override("separation", 20)
	panel.add_child(nav_box)
	
	var cont_btn := Button.new()
	cont_btn.text = "CONTINUE CAMPAIGN" if mission_id < 2 else "VIEW CAMPAIGN SUMMARY"
	cont_btn.custom_minimum_size = Vector2(340, 50)
	cont_btn.pressed.connect(func():
		Campaign.modal_active = false
		SoundManager.play_sfx("click")
		continue_requested.emit()
		queue_free()
	)
	nav_box.add_child(cont_btn)
	
	var rep_btn := Button.new()
	rep_btn.text = "REPLAY MISSION"
	rep_btn.custom_minimum_size = Vector2(220, 50)
	rep_btn.pressed.connect(func():
		Campaign.modal_active = false
		SoundManager.play_sfx("click")
		replay_requested.emit()
		queue_free()
	)
	nav_box.add_child(rep_btn)
	
	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(220, 50)
	menu_btn.pressed.connect(func():
		Campaign.modal_active = false
		SoundManager.play_sfx("click")
		menu_requested.emit()
		queue_free()
	)
	nav_box.add_child(menu_btn)
	cont_btn.grab_focus()

func _on_quiz_answered(correct: bool, explanation: String) -> void:
	if quiz_answered:
		return
	quiz_answered = true
	
	for child in quiz_box.get_children():
		if child is Button:
			child.disabled = true
			
	if correct:
		SoundManager.play_sfx("success")
		quiz_feedback_label.text = "✔ CORRECT!\n" + explanation
		quiz_feedback_label.add_theme_color_override("font_color", Color("#2ECC71"))
	else:
		SoundManager.play_sfx("warning")
		quiz_feedback_label.text = "✖ INCORRECT.\n" + explanation
		quiz_feedback_label.add_theme_color_override("font_color", Color("#FF5252"))

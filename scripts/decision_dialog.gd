extends CanvasLayer
class_name DecisionDialog

# High-impact decision consequence engine modal.
# Dedicated CanvasLayer (layer = 100) with backdrop dimmer.
# Evaluates safety correctness, cites official NDMA doctrine, applies score changes.

signal decision_completed(is_safe: bool, choice_text: String, explanation: String, score_delta: int)

var is_showing_consequence: bool = false
var current_choice_data: Dictionary = {}
var option_buttons: Array[Button] = []
var selected_option_index: int = 0
var decision_completed_once: bool = false

func _init() -> void:
	layer = 100

func setup(title: String, situation: String, options: Array[Dictionary]) -> void:
	Campaign.modal_active = true
	
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	
	# Dark semi-transparent backdrop dimmer
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.05, 0.09, 0.85)
	root.add_child(backdrop)
	
	# Main dialog card
	var card := Panel.new()
	card.name = "Card"
	card.position = Vector2(240, 50)
	card.size = Vector2(800, 620)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0C1B2A")
	style.border_color = Color("#F4B860")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", style)
	root.add_child(card)
	
	# Header alert banner
	var header := Panel.new()
	header.position = Vector2(0, 0)
	header.size = Vector2(800, 64)
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color("#172E44")
	h_style.set_corner_radius_all(8)
	header.add_theme_stylebox_override("panel", h_style)
	card.add_child(header)
	
	var title_lbl := Label.new()
	title_lbl.text = "CRITICAL EMERGENCY DECISION: " + title.to_upper()
	title_lbl.position = Vector2(30, 18)
	title_lbl.size = Vector2(740, 32)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.clip_text = false
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color("#F4B860"))
	header.add_child(title_lbl)
	
	# Situation description
	var sit_lbl := Label.new()
	sit_lbl.text = situation
	sit_lbl.position = Vector2(40, 85)
	sit_lbl.size = Vector2(720, 165)
	sit_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sit_lbl.clip_text = false
	sit_lbl.add_theme_font_size_override("font_size", 18)
	sit_lbl.add_theme_color_override("font_color", Color("#E2E8F0"))
	card.add_child(sit_lbl)
	
	# Instruction label
	var instr := Label.new()
	instr.text = "SELECT YOUR IMMEDIATE RESPONSE PROTOCOL:"
	instr.position = Vector2(40, 260)
	instr.size = Vector2(720, 24)
	instr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instr.clip_text = false
	instr.add_theme_font_size_override("font_size", 14)
	instr.add_theme_color_override("font_color", Color("#94A3B8"))
	card.add_child(instr)
	
	# Option buttons
	var vbox := VBoxContainer.new()
	vbox.name = "OptionsBox"
	vbox.position = Vector2(40, 295)
	vbox.size = Vector2(720, 290)
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)
	
	for opt in options:
		var btn := Button.new()
		btn.text = "• " + str(opt["text"])
		btn.custom_minimum_size = Vector2(720, 66)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.clip_text = false
		btn.add_theme_font_size_override("font_size", 15)
		var opt_data := opt
		btn.pressed.connect(func(): _on_option_chosen(opt_data))
		btn.pressed.connect(SoundManager.play_ui_click)
		btn.mouse_entered.connect(SoundManager.play_ui_click)
		vbox.add_child(btn)
		option_buttons.append(btn)

func _ready() -> void:
	if not option_buttons.is_empty():
		option_buttons[0].grab_focus()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if is_showing_consequence:
		if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER or key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ESCAPE:
			SoundManager.play_ui_click()
			_proceed()
			get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_UP or key_event.keycode == KEY_DOWN:
		if not option_buttons.is_empty():
			var step := -1 if key_event.keycode == KEY_UP else 1
			selected_option_index = posmod(selected_option_index + step, option_buttons.size())
			option_buttons[selected_option_index].grab_focus()
			SoundManager.play_ui_click()
			get_viewport().set_input_as_handled()
		return

	if key_event.keycode in [KEY_1, KEY_KP_1] and option_buttons.size() >= 1:
		SoundManager.play_ui_click()
		option_buttons[0].emit_signal("pressed")
		get_viewport().set_input_as_handled()
	elif key_event.keycode in [KEY_2, KEY_KP_2] and option_buttons.size() >= 2:
		SoundManager.play_ui_click()
		option_buttons[1].emit_signal("pressed")
		get_viewport().set_input_as_handled()
	elif key_event.keycode in [KEY_3, KEY_KP_3] and option_buttons.size() >= 3:
		SoundManager.play_ui_click()
		option_buttons[2].emit_signal("pressed")
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		if not option_buttons.is_empty():
			SoundManager.play_ui_click()
			option_buttons[selected_option_index].emit_signal("pressed")
			get_viewport().set_input_as_handled()

func _on_option_chosen(option: Dictionary) -> void:
	if is_showing_consequence:
		return
	is_showing_consequence = true
	current_choice_data = option
	
	var card := find_child("Card", true, false)
	var opts := card.get_node("OptionsBox")
	opts.queue_free()
	
	var is_safe: bool = option.get("safe", false)
	var explanation: String = option.get("explanation", "")
	var doctrine: String = option.get("doctrine", "")
	var score: int = option.get("score", 0)
	
	if is_safe:
		SoundManager.play_protocol_correct()
	else:
		SoundManager.play_protocol_wrong()
		
	# Build consequence review card
	var con_panel := Panel.new()
	con_panel.position = Vector2(40, 270)
	con_panel.size = Vector2(720, 255)
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color("#11241C") if is_safe else Color("#2A1212")
	c_style.border_color = Color("#2ECC71") if is_safe else Color("#E74C3C")
	c_style.set_border_width_all(2)
	c_style.set_corner_radius_all(8)
	con_panel.add_theme_stylebox_override("panel", c_style)
	card.add_child(con_panel)
	
	var res_title := Label.new()
	res_title.text = "✔ SAFETY PROTOCOL ADHERED (+%d PTS)" % score if is_safe else "✖ HAZARD VIOLATION (%d PTS)" % score
	res_title.position = Vector2(20, 16)
	res_title.size = Vector2(680, 28)
	res_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	res_title.clip_text = false
	res_title.add_theme_font_size_override("font_size", 18)
	res_title.add_theme_color_override("font_color", Color("#2ECC71") if is_safe else Color("#E74C3C"))
	con_panel.add_child(res_title)
	
	var exp_lbl := Label.new()
	exp_lbl.text = explanation
	exp_lbl.position = Vector2(20, 52)
	exp_lbl.size = Vector2(680, 85)
	exp_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exp_lbl.clip_text = false
	exp_lbl.add_theme_font_size_override("font_size", 15)
	exp_lbl.add_theme_color_override("font_color", Color("#F1F5F9"))
	con_panel.add_child(exp_lbl)
	
	var doc_lbl := Label.new()
	doc_lbl.text = "NDMA DOCTRINE: " + doctrine
	doc_lbl.position = Vector2(20, 145)
	doc_lbl.size = Vector2(680, 95)
	doc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	doc_lbl.clip_text = false
	doc_lbl.add_theme_font_size_override("font_size", 13)
	doc_lbl.add_theme_color_override("font_color", Color("#94A3B8"))
	con_panel.add_child(doc_lbl)
	
	var cont_btn := Button.new()
	cont_btn.text = "PROCEED WITH MISSION  [ENTER]"
	cont_btn.position = Vector2(260, 545)
	cont_btn.size = Vector2(280, 50)
	cont_btn.pressed.connect(_proceed)
	cont_btn.pressed.connect(SoundManager.play_ui_click)
	cont_btn.mouse_entered.connect(SoundManager.play_ui_click)
	card.add_child(cont_btn)
	cont_btn.grab_focus()

func _proceed() -> void:
	if decision_completed_once:
		return
	decision_completed_once = true
	Campaign.modal_active = false
	var is_safe: bool = current_choice_data.get("safe", false)
	var explanation: String = current_choice_data.get("explanation", "")
	var score: int = current_choice_data.get("score", 0)
	var choice_text: String = current_choice_data.get("text", "")
	decision_completed.emit(is_safe, choice_text, explanation, score)
	queue_free()

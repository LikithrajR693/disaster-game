extends CanvasLayer
class_name PreparednessHandbook

# Comprehensive Disaster Preparedness Handbook based on authoritative NDMA India material
# Dedicated CanvasLayer (layer = 100) with backdrop dimmer.
# Features tabbed browsing: Earthquake, Flood, Fire, and Emergency Contacts & Go-Bag Checklist.

signal closed

var active_tab: int = 0
var content_label: RichTextLabel
var tab_buttons: Array[Button] = []

const TABS: Array[Dictionary] = [
	{
		"title": "EARTHQUAKE PROTOCOL",
		"text": "[b][color=#F4B860]NATIONAL DISASTER MANAGEMENT AUTHORITY (NDMA) — EARTHQUAKE GUIDELINES[/color][/b]\n\n" +
			"[b][color=#2ECC71]1. IMMEDIATE ACTION DURING ACTIVE SHAKING:[/color][/b]\n" +
			"• [b]DROP, COVER, AND HOLD ON:[/b] Immediately drop to hands and knees to prevent being knocked over. Take cover under a sturdy desk or table. Hold on to your shelter with one hand and protect your head/neck with the other until shaking completely stops.\n" +
			"• [b]DO NOT RUN OUTSIDE:[/b] Running outside during active shaking is the leading cause of earthquake injuries and fatalities. Falling glass, building facade tiles, parapets, and exterior masonry collapse directly onto street exits.\n" +
			"• [b]AVOID DOORWAYS:[/b] In modern structures, doorways are no stronger than standard walls and doors swinging violently can cause severe crush injuries.\n\n" +
			"[b][color=#4EA8DE]2. POST-SHAKING EVACUATION & TRIAGE:[/color][/b]\n" +
			"• Wait until all primary tremors cease before exiting the structure.\n" +
			"• [b]UTILITY ISOLATION:[/b] If you smell sulfur or gas, turn off the main gas cylinder/pipeline valve immediately. Do NOT turn on or off any electrical switches (sparks can ignite gas vapor).\n" +
			"• [b]STAY CLEAR OF POWER LINES:[/b] Keep a minimum safe distance of 10 meters from fallen wires. Treat all downed lines as live.\n" +
			"• [b]OPEN ASSEMBLY AREA:[/b] Move quickly to designated open grounds (parks, sports fields) away from buildings, overhead wires, and tall trees."
	},
	{
		"title": "FLOOD PROTOCOL",
		"text": "[b][color=#F4B860]CENTRAL WATER COMMISSION (CWC) & NDMA — FLOOD SAFETY PROTOCOL[/color][/b]\n\n" +
			"[b][color=#2ECC71]1. 'TURN AROUND, DON'T DROWN' DOCTRINE:[/color][/b]\n" +
			"• [b]NEVER WALK OR DRIVE THROUGH FLOODWATER:[/b] Just 6 inches (15 cm) of moving floodwater can sweep a grown adult off their feet. Just 12 inches can float and carry away a vehicle.\n" +
			"• [b]CONCEALED HAZARDS:[/b] Murky floodwaters hide missing storm drain manhole covers, deep sinkholes, sharp metal debris, open sewers, and toxic chemicals.\n\n" +
			"[b][color=#E0533C]2. ELECTRICAL HAZARDS IN FLOODS:[/color][/b]\n" +
			"• Water is an excellent conductor of electricity. Submerged transformers, street junction boxes, and downed wires electrify standing flood pools, causing instant fatal electrocution.\n" +
			"• If water is rising inside a home, turn off the main circuit breaker only if you can do so safely without standing in water.\n\n" +
			"[b][color=#4EA8DE]3. EVACUATION & ELEVATED SHELTERS:[/color][/b]\n" +
			"• Follow elevated terrain routes along high ridges or designated bridges.\n" +
			"• Never delay an evacuation to move heavy furniture, television, or bulky belongings. Lives cannot be replaced; property can.\n" +
			"• Boil all drinking water or use chlorine purification tablets after a flood to prevent cholera and waterborne epidemics."
	},
	{
		"title": "FIRE PROTOCOL",
		"text": "[b][color=#F4B860]NATIONAL BUILDING CODE (NBC) & FIRE SAFETY DIRECTIVE[/color][/b]\n\n" +
			"[b][color=#2ECC71]1. IMMEDIATE RESPONSE (R.A.C.E. PROTOCOL):[/color][/b]\n" +
			"• [b]RESCUE:[/b] Remove persons in immediate danger if safe to do so.\n" +
			"• [b]ALARM:[/b] Pull the nearest manual fire alarm call point and shout 'FIRE! FIRE!' to alert building occupants.\n" +
			"• [b]CONFINE:[/b] Close doors behind you as you exit to slow fire spread and smoke propagation.\n" +
			"• [b]EVACUATE:[/b] Proceed directly out of the building to the designated assembly area.\n\n" +
			"[b][color=#E0533C]2. SMOKE HAZARDS & CRAWL LOW:[/color][/b]\n" +
			"• Smoke inhalation and toxic gases (carbon monoxide & hydrogen cyanide) kill more people in fires than flames.\n" +
			"• Heated smoke rises to the ceiling. The cleanest, coolest, and most breathable air remains 1 to 2 feet (30-60 cm) above the floor. [b]CRAWL ON HANDS AND KNEES[/b] under the smoke layer with a damp cloth over your nose.\n\n" +
			"[b][color=#FF5252]3. NEVER USE ELEVATORS:[/color][/b]\n" +
			"• Elevator shafts act as vertical chimneys drawing smoke and superheated flames. Electrical failure can cut hoist power, trapping occupants in a death trap. Always use fire stairs.\n\n" +
			"[b][color=#F4B860]4. P.A.S.S. EXTINGUISHER TECHNIQUE:[/color][/b]\n" +
			"• [b]P[/b]ull the locking pin. [b]A[/b]im nozzle at the BASE of fire. [b]S[/b]queeze the handle. [b]S[/b]weep side to side."
	},
	{
		"title": "CONTACTS & GO-BAG",
		"text": "[b][color=#F4B860]INDIAN DISASTER EMERGENCY HELPLINES (TOLL FREE)[/color][/b]\n\n" +
			"• [b][color=#2ECC71]112[/color][/b] — Unified National Emergency Response Support System (ERSS)\n" +
			"• [b][color=#2ECC71]108[/color][/b] — Emergency Medical Services / Government Ambulance\n" +
			"• [b][color=#2ECC71]101[/color][/b] — Fire & Rescue Services\n" +
			"• [b][color=#2ECC71]1070[/color][/b] — NDMA National Disaster Helpline (24x7 Control Room)\n" +
			"• [b][color=#2ECC71]1077[/color][/b] — District Disaster Management Authority (DDMA)\n\n" +
			"[b][color=#4EA8DE]RECOMMENDED 72-HOUR DISASTER GO-BAG CHECKLIST:[/color][/b]\n\n" +
			"1. [b]Water:[/b] 3 liters of sealed drinking water per person per day + ORS sachets.\n" +
			"2. [b]First Aid Kit:[/b] Antiseptic solution, sterile gauze, triangular bandages, paracetamol, burn ointment, adhesive tape.\n" +
			"3. [b]Emergency Whistle:[/b] High decibel signaling tool (whistling takes 10x less energy than screaming under rubble).\n" +
			"4. [b]Heavy Duty Flashlight:[/b] Waterproof LED torch with spare batteries.\n" +
			"5. [b]Portable Radio:[/b] Battery-powered / solar crank AM/FM radio for All India Radio emergency advisories.\n" +
			"6. [b]Waterproof Document Pouch:[/b] Copies of Aadhaar, Ration Card, property papers, insurance, bank records.\n" +
			"7. [b]Emergency Cash:[/b] Small denomination banknotes (ATMs and UPI go offline during disasters).\n" +
			"8. [b]Multi-tool / Heavy Gloves:[/b] Leather work gloves for clearing broken glass and masonry."
	}
]

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
	
	# Dark backdrop
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.05, 0.09, 0.90)
	root.add_child(bg)
	
	# Main Container
	var panel := Panel.new()
	panel.position = Vector2(80, 40)
	panel.size = Vector2(1120, 640)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color("#0C1B2A")
	p_style.border_color = Color("#F4B860")
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", p_style)
	root.add_child(panel)
	
	# Title
	var title := Label.new()
	title.text = "AARANYA DISASTER PREPAREDNESS HANDBOOK"
	title.position = Vector2(40, 20)
	title.size = Vector2(1040, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.clip_text = false
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#F4B860"))
	panel.add_child(title)
	
	var sub := Label.new()
	sub.text = "OFFICIAL GUIDELINES BASED ON NATIONAL DISASTER MANAGEMENT AUTHORITY (NDMA) DOCTRINE"
	sub.position = Vector2(40, 56)
	sub.size = Vector2(1040, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.clip_text = false
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color("#94A3B8"))
	panel.add_child(sub)
	
	# Tab Buttons Bar
	var tabs_box := HBoxContainer.new()
	tabs_box.position = Vector2(40, 90)
	tabs_box.size = Vector2(1040, 45)
	tabs_box.add_theme_constant_override("separation", 12)
	panel.add_child(tabs_box)
	
	for i in TABS.size():
		var btn := Button.new()
		btn.text = TABS[i]["title"]
		btn.custom_minimum_size = Vector2(248, 45)
		var idx := i
		btn.pressed.connect(func(): _switch_tab(idx))
		UIFeedback.attach(btn, Color("#F4B860"), false)
		tabs_box.add_child(btn)
		tab_buttons.append(btn)
		
	# Text Content Area
	var content_panel := Panel.new()
	content_panel.position = Vector2(40, 150)
	content_panel.size = Vector2(1040, 410)
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color("#07121D")
	c_style.border_color = Color("#1E364D")
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(6)
	content_panel.add_theme_stylebox_override("panel", c_style)
	panel.add_child(content_panel)
	
	content_label = RichTextLabel.new()
	content_label.position = Vector2(24, 20)
	content_label.size = Vector2(992, 370)
	content_label.bbcode_enabled = true
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_panel.add_child(content_label)
	
	# Close Button
	var close_btn := Button.new()
	close_btn.text = "RETURN TO PREVIOUS SCREEN  [ESC]"
	close_btn.position = Vector2(420, 575)
	close_btn.size = Vector2(280, 45)
	close_btn.pressed.connect(func():
		Campaign.modal_active = false
		SoundManager.play_sfx("click")
		closed.emit()
		queue_free()
	)
	UIFeedback.attach(close_btn, Color("#F4B860"), false)
	panel.add_child(close_btn)
	close_btn.grab_focus()
	
	_switch_tab(0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Campaign.modal_active = false
		SoundManager.play_sfx("click")
		closed.emit()
		queue_free()
		get_viewport().set_input_as_handled()

func _switch_tab(index: int) -> void:
	active_tab = index
	SoundManager.play_sfx("click")
	content_label.text = TABS[index]["text"]
	
	for i in tab_buttons.size():
		if i == index:
			tab_buttons[i].add_theme_color_override("font_color", Color("#F4B860"))
		else:
			tab_buttons[i].remove_theme_color_override("font_color")

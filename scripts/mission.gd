extends Node2D

# Master Mission Controller for READY OR NOT: THE LAST 10 MINUTES
# Coordinates Earthquake (0), Flood (1), and Fire (2) disaster simulations.

var mission_id: int = 0

# Core Nodes
var town_map: TownMap
var player: PlayerController
var camera: Camera2D
var hud: HUDController
var hud_canvas: CanvasLayer
var atmosphere_vignette: AtmosphereVignette

# Game State
var score: int = 1000
var hazards_inspected_count: int = 0
var residents_saved_count: int = 0
var supplies_collected_count: int = 0
var decisions_log: Array[Dictionary] = []

var active_hazards: Array[Hazard] = []
var active_residents: Array[Resident] = []
var active_supplies: Array[SupplyItem] = []

# Disaster-specific timers & flags
var shaking_timer: float = 0.0
var is_shaking: bool = false
var shake_intensity: float = 0.0
var camera_trauma: float = 0.0
var camera_shake_clock: float = 0.0
var camera_impulse_offset: Vector2 = Vector2.ZERO
var camera_impulse_velocity: Vector2 = Vector2.ZERO
var evacuation_active: bool = false
var mission_ended: bool = false

func _ready() -> void:
	mission_id = Campaign.mission_id
	_initialize_world()
	_setup_player()
	_setup_hud()
	_setup_atmosphere_overlay()
	_populate_scenario()
	call_deferred("_start_mission_intro")

func _initialize_world() -> void:
	town_map = TownMap.new()
	town_map.setup(mission_id)
	town_map.safe_zone_reached.connect(_on_safe_zone_reached)
	add_child(town_map)

func _setup_player() -> void:
	player = PlayerController.new()
	# Spawn location depending on disaster
	match mission_id:
		0: player.position = Vector2(400, 340) # Inside school courtyard
		1: player.position = Vector2(700, 520) # Near Gandhi Marg North
		2: player.position = Vector2(340, 1220) # Inside Aaranya Towers corridor
		
	player.interaction_requested.connect(_on_player_interaction)
	add_child(player)
	
	camera = Camera2D.new()
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = GameConfig.CAMERA_SMOOTHING_SPEED
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 2400
	camera.limit_bottom = 1600
	player.add_child(camera)

func _setup_hud() -> void:
	hud = HUDController.new()
	hud_canvas = CanvasLayer.new()
	hud_canvas.layer = 10
	add_child(hud_canvas)
	var meta: Dictionary = Campaign.MISSION_METADATA[mission_id]
	hud.mission_title = meta["title"]
	hud.disaster_name = meta["disaster"]
	hud.primary_objective = meta["subtitle"]
	hud.time_remaining = float(meta["time_limit"])
	
	hud.pause_toggled.connect(_on_pause_toggled)
	hud.restart_requested.connect(_on_restart_requested)
	hud.handbook_requested.connect(_on_handbook_requested)
	hud.return_to_menu_requested.connect(_on_return_to_menu)
	hud.input_overlay_toggled.connect(_on_input_overlay_toggled)
	hud.interaction_modal_cancelled.connect(_on_interaction_modal_cancelled)
	
	hud_canvas.add_child(hud)
	_update_hud_counters()

func _setup_atmosphere_overlay() -> void:
	atmosphere_vignette = AtmosphereVignette.new()
	atmosphere_vignette.setup(mission_id)
	add_child(atmosphere_vignette)

func _physics_process(delta: float) -> void:
	if mission_ended:
		return
		
	# Guide arrow tracking
	if is_instance_valid(player) and is_instance_valid(town_map):
		hud.update_guide_target(player.global_position, town_map.get_safe_zone_center())
		atmosphere_vignette.set_world_context(player.global_position, active_hazards, camera_trauma)
		
		# Spatial Hazard Proximity Audio Tracking
		var min_hazard_dist := 9999.0
		var nearest_type := ""
		for h in active_hazards:
			if is_instance_valid(h) and not h.inspected:
				var d := player.global_position.distance_to(h.global_position)
				if d < min_hazard_dist:
					min_hazard_dist = d
					nearest_type = h.hazard_type
		SoundManager.update_hazard_proximity(min_hazard_dist, nearest_type)
		
	# Interaction prompt tracking
	if is_instance_valid(player):
		if is_instance_valid(player.nearby_interactable):
			var target: Node2D = player.nearby_interactable
			if target is Hazard and not target.inspected:
				hud.show_prompt("INSPECT " + target.hazard_title.to_upper())
			elif target is SupplyItem:
				hud.show_prompt("COLLECT " + target.item_name.to_upper())
			elif target is Resident and target.current_state == Resident.State.WAITING:
				hud.show_prompt("ASSIST " + target.resident_name.to_upper())
			else:
				hud.hide_prompt()
		else:
			hud.hide_prompt()
			
	camera_shake_clock += delta
	camera_trauma = maxf(0.0, camera_trauma - delta * (GameConfig.EARTHQUAKE_SHAKE_TRAUMA_DECAY if is_shaking else GameConfig.CAMERA_TRAUMA_DECAY))
	if is_instance_valid(camera):
		var look_ahead := player.facing_direction.normalized() * GameConfig.CAMERA_LOOK_AHEAD if player.velocity.length_squared() > 1.0 else Vector2.ZERO
		camera.position = camera.position.lerp(look_ahead, 1.0 - exp(-GameConfig.CAMERA_LOOK_DAMPING * delta))
		var spring_frequency := GameConfig.CAMERA_IMPULSE_SPRING
		var spring_acceleration := -camera_impulse_offset * spring_frequency * spring_frequency
		spring_acceleration -= 2.0 * GameConfig.CAMERA_IMPULSE_DAMPING * spring_frequency * camera_impulse_velocity
		camera_impulse_velocity += spring_acceleration * delta
		camera_impulse_offset += camera_impulse_velocity * delta
		var shake_scale := (camera_trauma * (shake_intensity if is_shaking else 6.0)) if Campaign.screen_shake_enabled else 0.0
		camera.offset = Vector2(
			sin(camera_shake_clock * GameConfig.CAMERA_SHAKE_X_FREQUENCY) * shake_scale,
			cos(camera_shake_clock * GameConfig.CAMERA_SHAKE_Y_FREQUENCY) * shake_scale
		) + camera_impulse_offset
		camera.rotation = sin(camera_shake_clock * GameConfig.CAMERA_SHAKE_ROTATION_FREQUENCY) * camera_trauma * (0.012 if Campaign.screen_shake_enabled else 0.0)

	# Earthquake screen-shake duration
	if is_shaking and shaking_timer > 0.0:
		shaking_timer -= delta
		if shaking_timer <= 0.0:
			_end_earthquake_shaking()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if hud.is_pause_menu_open():
			hud.hide_pause_menu()
		elif hud.has_open_info_panel():
			hud.close_info_panel()
		elif player.can_move:
			hud.show_pause_menu()
		get_viewport().set_input_as_handled()
	elif player.can_move and event.is_action_pressed("open_map"):
		hud.toggle_info_panel("map")
		get_viewport().set_input_as_handled()
	elif player.can_move and event.is_action_pressed("open_inventory"):
		hud.toggle_info_panel("inventory")
		get_viewport().set_input_as_handled()
	elif player.can_move and event.is_action_pressed("open_objectives"):
		hud.toggle_info_panel("objectives")
		get_viewport().set_input_as_handled()

func _populate_scenario() -> void:
	match mission_id:
		0:
			# EARTHQUAKE SCENARIO
			# Hazards
			_spawn_hazard("eq_h1", "Downed 11kV Power Line", "ELECTRICAL", "CRITICAL",
				"Keep at least 10m away. Do NOT touch wet road or wires. Report to Aaranya Electricity Board.",
				"Severed overhead power line arcing into water puddle on Gandhi Marg.",
				Vector2(780, 720))
			_spawn_hazard("eq_h2", "Severely Fractured School Parapet", "STRUCTURAL", "HIGH",
				"Never walk directly beneath damaged masonry or cornices. Falling debris causes fatal trauma.",
				"Heavy concrete lintel hanging precariously over primary school exit doorway.",
				Vector2(450, 440))
			_spawn_hazard("eq_h3", "Major Road Fissure & Asphalt Rupture", "STRUCTURAL", "HIGH",
				"Mark route as impassable. Do not attempt to drive or step across unstable fissures.",
				"Deep shear fissure splitting the road surface; water main leaking beneath.",
				Vector2(650, 810))
			_spawn_hazard("eq_h4", "Domestic LPG Cylinder Leak", "FIRE", "CRITICAL",
				"Do NOT turn electrical switches ON or OFF. Turn off main cylinder regulator and ventilate if safe.",
				"Smell of mercaptan sulfur detected near collapsed school kitchen block.",
				Vector2(220, 240))
				
			# Supplies
			_spawn_supply("eq_s1", "NDMA Trauma First Aid Kit", "MEDICAL",
				"Sterile compresses, tourniquets, and bandages for triaging lacerations and blunt trauma.",
				Vector2(320, 260))
			_spawn_supply("eq_s2", "Heavy-Duty Emergency LED Torch", "LIGHT",
				"High lumen searchlight with spare alkaline batteries for navigating darkened rubble.",
				Vector2(540, 260))
			_spawn_supply("eq_s3", "High-Decibel Emergency Whistle", "RESCUE",
				"Signaling acoustic tool. Sound penetrates rubble far more effectively than shouting.",
				Vector2(700, 380))
				
			# Residents
			_spawn_resident("Mrs. Anandi Sharma", 72, "Severe Osteoarthritis / Reduced Mobility",
				"The ground shook so violently... my knees collapsed under me. I cannot walk quickly through the rubble!",
				"God bless you! We made it out to the open sports ground. The sky is clear above us!",
				Color("#E57373"), Vector2(340, 380))
			_spawn_resident("Master Aarav", 9, "Separated Child / Extreme Panic",
				"I was in the hallway when the lights fell... I don't know where my teacher is! Please don't leave me!",
				"I can see the open field! Thank you coordinator sir!",
				Color("#64B5F6"), Vector2(500, 400))
				
		1:
			# FLOOD SCENARIO
			# Hazards
			_spawn_hazard("fl_h1", "Submerged Road Section (Hidden Manhole)", "WATER", "CRITICAL",
				"'Turn Around, Don't Drown'. 6 inches of water knocks adults down; submerged open manholes drown victims.",
				"1.5 feet of fast-moving muddy flood current obscuring washed-away storm drain covers.",
				Vector2(1280, 800))
			_spawn_hazard("fl_h2", "Submerged Electrical Transformer Box", "ELECTRICAL", "CRITICAL",
				"Never wade through standing water near electrical infrastructure. Fatal electrocution zone.",
				"Water has reached the base of a 415V distribution box; electrical humming and bubbling observed.",
				Vector2(1050, 980))
			_spawn_hazard("fl_h3", "Submerged Vehicle & Floating Debris", "WATER", "HIGH",
				"Never shelter inside a car in rising floodwaters. Abandon stranded vehicles for high ground.",
				"Car swept off road lodged against culvert; sharp floating timber and corrugated tin sheets.",
				Vector2(1380, 770))
				
			# Supplies
			_spawn_supply("fl_s1", "Waterproof Emergency Document Pouch", "DOCS",
				"Watertight container preserving Aadhaar, property records, and emergency cash dry.",
				Vector2(480, 480))
			_spawn_supply("fl_s2", "Emergency Battery & Weather Radio", "COMMS",
				"Broadcast receiver for India Meteorological Dept (IMD) and relief command alerts.",
				Vector2(820, 520))
			_spawn_supply("fl_s3", "Emergency Flotation Vest & Whistle", "RESCUE",
				"Buoyancy aid for assisting non-swimmers across treacherous drainage borders.",
				Vector2(920, 620))
				
			# Residents
			_spawn_resident("Mr. Rajesh Verma", 48, "Shopkeeper / Reluctance to Abandon Shop",
				"My life's savings are in this shop! If I leave, the water will ruin everything! I should stay...",
				"You were right... possessions can be bought again, life cannot. Thank you for making me move!",
				Color("#FFB74D"), Vector2(860, 820))
			_spawn_resident("Nurse Lakshmi", 34, "PHC Nurse / Carrying Medical Supplies",
				"The clinic basement is flooding rapidly! I have the emergency insulin box, guide me to high ground!",
				"We reached the elevated community hall plinth! We are well above the flood waterline!",
				Color("#81C784"), Vector2(1420, 900))
				
		2:
			# FIRE SCENARIO
			# Hazards
			_spawn_hazard("fr_h1", "Dense Toxic Smoke Inversion Layer", "FIRE", "CRITICAL",
				"Crawl on hands and knees beneath the smoke layer. Smoke and carbon monoxide rise to the ceiling.",
				"Thick black acrid smoke banking down from ceiling height; zero visibility upright.",
				Vector2(320, 1100))
			_spawn_hazard("fr_h2", "Operating Passenger Elevator", "FIRE", "CRITICAL",
				"NEVER USE ELEVATORS IN A FIRE. Elevator shafts act as vertical chimneys for toxic gases.",
				"Elevator doors open with call light illuminated; shaft drafting heavy heat upwards.",
				Vector2(440, 1020))
			_spawn_hazard("fr_h3", "Arcing Electrical Distribution Panel", "ELECTRICAL", "HIGH",
				"Do NOT use water on electrical fires. Use ABC dry chemical or CO2 extinguisher only.",
				"Sparks and blue flames erupting from the main floor circuit breaker board.",
				Vector2(220, 1260))
				
			# Supplies
			_spawn_supply("fr_s1", "ABC Dry Chemical Fire Extinguisher", "FIRE",
				"Multipurpose 5kg monoammonium phosphate extinguisher for clearing small escape route flames.",
				Vector2(260, 1020))
			_spawn_supply("fr_s2", "Emergency Smoke Hood & Flashlight", "LIGHT",
				"Particle filtration hood and penetrating beam for navigating dense smoke.",
				Vector2(480, 1180))
				
			# Residents
			_spawn_resident("Mr. Kulkarni", 78, "Senior Citizen / Severe Respiratory Distress",
				"*Coughing* The smoke is so thick... I can't see the exit door! My chest feels so tight!",
				"*Breathing clean air* Oh thank heaven! The cool fresh air... you got us out just in time!",
				Color("#BA68C8"), Vector2(280, 1160))
			_spawn_resident("Meera & Baby", 29, "Parent with Infant / Disoriented",
				"The fire alarm panicked everyone! People were rushing toward the elevator! Where do we go?!",
				"We are in the safe parking perimeter! My baby is safe! Thank you coordinator!",
				Color("#4DB6AC"), Vector2(460, 1100))

func _spawn_hazard(id: String, title: String, type: String, threat: String, ndma_rule: String, desc: String, pos: Vector2) -> void:
	var h := Hazard.new()
	h.hazard_id = id
	h.hazard_title = title
	h.hazard_type = type
	h.threat_level = threat
	h.ndma_rule = ndma_rule
	h.description = desc
	h.position = pos
	h.hazard_inspected.connect(_on_hazard_inspected)
	add_child(h)
	active_hazards.append(h)

func _spawn_supply(id: String, name: String, type: String, purpose: String, pos: Vector2) -> void:
	var s := SupplyItem.new()
	s.item_id = id
	s.item_name = name
	s.item_type = type
	s.ndma_purpose = purpose
	s.position = pos
	s.supply_collected.connect(_on_supply_collected)
	add_child(s)
	active_supplies.append(s)

func _spawn_resident(name: String, age: int, vuln: String, init_d: String, safe_d: String, color: Color, pos: Vector2) -> void:
	var r := Resident.new()
	r.resident_name = name
	r.age = age
	r.vulnerability = vuln
	r.initial_dialogue = init_d
	r.safe_dialogue = safe_d
	r.resident_color = color
	r.position = pos
	r.resident_rescued.connect(_on_resident_rescued)
	r.resident_reached_safety.connect(_on_resident_safe)
	add_child(r)
	active_residents.append(r)

func _start_mission_intro() -> void:
	player.can_move = false
	
	match mission_id:
		0:
			# EARTHQUAKE INTRO DECISION
			var options: Array[Dictionary] = [
				{
					"text": "DROP to hands and knees, take COVER under a sturdy table, and HOLD ON.",
					"safe": true,
					"score": 500,
					"explanation": "Drop, Cover, and Hold On protects the brain, neck, and vital organs from falling fixtures, ceiling fans, and shattered glass.",
					"doctrine": "NDMA Earthquake Directive: Never attempt to run outside while ground shaking is actively occurring."
				},
				{
					"text": "Sprint immediately toward the exterior courtyard exit.",
					"safe": false,
					"score": -300,
					"explanation": "Running outside during active shaking exposes you to falling exterior parapets, brick cornices, and glass shards.",
					"doctrine": "NDMA statistical analysis reveals over 70% of seismic injuries occur near building exterior thresholds."
				},
				{
					"text": "Stand upright beneath an interior doorway.",
					"safe": false,
					"score": -200,
					"explanation": "Modern doorways are not structurally reinforced; heavy swinging fire doors frequently crush hands and limbs.",
					"doctrine": "Doorway standing is obsolete doctrine from unreinforced adobe buildings. Always seek sturdy desk cover."
				}
			]
			_show_decision("EARTHQUAKE STRIKES",
				"A sudden Richter 6.8 seismic tremor convulses the town of Aaranya! Fluorescent lights shatter, shelves collapse, and violent ground motion makes standing upright impossible.\n\nWhat is your IMMEDIATE protective action?",
				options,
				func(is_safe: bool): _start_earthquake_shaking(is_safe)
			)
			
		1:
			# FLOOD INTRO DECISION
			SoundManager.play_hazard_alert()
			var options: Array[Dictionary] = [
				{
					"text": "Initiate immediate evacuation to the elevated Community Hall Shelter via the northern ridge route.",
					"safe": true,
					"score": 500,
					"explanation": "Early, proactive evacuation along proven high-ground routes avoids flash-flood traps and submerged road deaths.",
					"doctrine": "NDMA Flood Rule: Always evacuate before low-lying escape roads are inundated."
				},
				{
					"text": "Stay in the lower ground rooms to move heavy appliances and televisions onto high tables.",
					"safe": false,
					"score": -300,
					"explanation": "Possessions can be replaced; human lives cannot. Flash floods rise exponentially, trapping occupants inside within minutes.",
					"doctrine": "NDMA Life Safety First: Never delay an evacuation for bulky household items or electronics."
				},
				{
					"text": "Take a two-wheeler motorcycle down the flooded eastern shortcut road.",
					"safe": false,
					"score": -400,
					"explanation": "Just 12 inches of moving water floats motorbikes and cars, carrying them into deep canals and open culverts.",
					"doctrine": "'Turn Around, Don't Drown'. Never attempt to drive through water of unknown depth."
				}
			]
			_show_decision("FLASH FLOOD WARNING",
				"Central Water Commission (CWC) flashes an Emergency Red Alert: Upstream canal embankment has breached! Muddy torrents are pouring across low-lying roads. You have an estimated 10-minute evacuation window.\n\nWhat is your IMMEDIATE priority?",
				options,
				func(is_safe: bool):
					evacuation_active = true
					player.can_move = true
					hud.update_status("EVACUATION ACTIVE — PROCEED TO ELEVATED SHELTER", Color("#4BA3E3"))
					hud.update_mission_info(Campaign.MISSION_METADATA[1]["title"], "FLOOD", "Guide residents to elevated Community Shelter via ridge route")
			)
			
		2:
			# FIRE INTRO DECISION
			SoundManager.play_hazard_alert()
			var options: Array[Dictionary] = [
				{
					"text": "Sound the manual pull-station alarm, yell loud warnings to occupants, and head to the fire stairwell.",
					"safe": true,
					"score": 500,
					"explanation": "Early occupant alert and immediate stairwell egress saves the greatest number of building lives.",
					"doctrine": "R.A.C.E. Protocol (Rescue, Alarm, Confine, Evacuate) — National Building Code of India."
				},
				{
					"text": "Call the passenger elevator to descend quickly down to the ground floor.",
					"safe": false,
					"score": -500,
					"explanation": "Elevators are fatal traps in fires. Shafts draft smoke and heat upwards like a chimney; power failure traps you inside.",
					"doctrine": "NEVER USE ELEVATORS IN A FIRE. Electrical failure and chimney smoke effects cause instant asphyxiation."
				},
				{
					"text": "Return to your apartment bedroom to collect cash, bank cards, and personal jewelry.",
					"safe": false,
					"score": -350,
					"explanation": "Toxic smoke and heat spread within seconds. Going back into rooms kills people who think they have extra time.",
					"doctrine": "Once an evacuation begins, NEVER re-enter or return for belongings."
				}
			]
			_show_decision("RESIDENTIAL FIRE OUTBREAK",
				"Piercing fire alarms sound through the Aaranya Towers residential block! Pungent acrid smoke is seeping from corridor vents. Occupants are beginning to panic.\n\nWhat is your IMMEDIATE action?",
				options,
				func(is_safe: bool):
					evacuation_active = true
					player.can_move = true
					hud.update_status("FIRE EVACUATION ACTIVE — USE STAIRWELLS ONLY", Color("#E0533C"))
					hud.update_mission_info(Campaign.MISSION_METADATA[2]["title"], "FIRE", "Evacuate occupants via stairs to external assembly area")
			)

func _show_decision(title: String, prompt: String, options: Array[Dictionary], on_resolved: Callable) -> void:
	var dlg := DecisionDialog.new()
	dlg.setup(title, prompt, options)
	dlg.decision_completed.connect(func(is_safe: bool, choice_txt: String, exp: String, sc: int):
		score += sc
		hud.update_score_display(score)
		decisions_log.append({
			"safe": is_safe,
			"text": choice_txt,
			"exp": exp,
			"score": sc
		})
		on_resolved.call(is_safe)
	)
	add_child(dlg)

func _start_earthquake_shaking(safe_choice: bool) -> void:
	is_shaking = true
	shaking_timer = GameConfig.EARTHQUAKE_SHAKE_DURATION
	shake_intensity = 8.0
	camera_trauma = 1.0
	player.can_move = false
	hud.update_status("ACTIVE SHAKING — STAY UNDER COVER! (HOLD ON)", Color("#FF5252"))
	SoundManager.play_tremor_rumble()
	town_map.trigger_tremor()
	
	if not safe_choice:
		# Consequence of running outside
		shake_intensity = 14.0
		camera_trauma = 1.0

func _end_earthquake_shaking() -> void:
	is_shaking = false
	player.can_move = true
	evacuation_active = true
	SoundManager.play_hazard_alert()
	hud.update_status("SHAKING STOPPED — ASSESS HAZARDS & EVACUATE", Color("#2ECC71"))
	hud.update_mission_info(Campaign.MISSION_METADATA[0]["title"], "EARTHQUAKE", "Inspect damaged buildings, assist residents, assemble on open sports ground")

func _on_player_interaction(target: Node2D) -> void:
	if not evacuation_active or not player.can_move or Campaign.modal_active:
		return

	camera_impulse_velocity -= player.global_position.direction_to(target.global_position) * GameConfig.CAMERA_IMPULSE_STRENGTH
		
	if target is Hazard:
		if not target.inspected:
			player.can_move = false
			hud.show_hazard_dossier(target.inspect_hazard(), func():
				player.can_move = true
			)
	elif target is SupplyItem:
		target.collect()
	elif target is Resident:
		if target.current_state == Resident.State.WAITING:
			player.can_move = false
			hud.show_resident_dialogue({
				"name": target.resident_name,
				"age": target.age,
				"vulnerability": target.vulnerability,
				"initial_dialogue": target.initial_dialogue
			}, func():
				player.can_move = true
				target.assist_resident(player)
				player.register_escorted_resident(target)
			)

func _on_hazard_inspected(h_data: Dictionary) -> void:
	hazards_inspected_count += 1
	score += 250
	hud.update_score_display(score)
	_update_hud_counters()

func _on_supply_collected(item_data: Dictionary) -> void:
	supplies_collected_count += 1
	score += 200
	hud.add_supply_item(item_data)
	hud.update_score_display(score)
	_update_hud_counters()

func _on_resident_rescued(r_data: Dictionary) -> void:
	hud.update_status("ESCORTING: " + str(r_data.get("name", "")), Color("#80D8FF"))

func _on_resident_safe(r_data: Dictionary) -> void:
	residents_saved_count += 1
	score += 500
	hud.update_score_display(score)
	_update_hud_counters()

func _update_hud_counters() -> void:
	var meta: Dictionary = Campaign.MISSION_METADATA[mission_id]
	hud.update_counters(
		hazards_inspected_count, meta["required_hazards"],
		residents_saved_count, meta["required_residents"],
		supplies_collected_count, 2
	)

func _on_safe_zone_reached() -> void:
	if mission_ended:
		return
		
	# Check if any following residents reached the safe zone
	for r in active_residents:
		if r.current_state == Resident.State.FOLLOWING:
			r.mark_safe()
			player.unregister_escorted_resident(r)
			
	var meta: Dictionary = Campaign.MISSION_METADATA[mission_id]
	var hazards_ok: bool = hazards_inspected_count >= int(meta["required_hazards"])
	var residents_ok: bool = residents_saved_count >= int(meta["required_residents"])
	
	if residents_ok and hazards_ok:
		_complete_mission(true)
	else:
		# Warn the player that residents are still in danger!
		var warning := "WARNING: RESIDENTS STILL IN DANGER ZONE!" if not residents_ok else "INSPECT THE REMAINING HAZARDS BEFORE COMPLETING THE MISSION!"
		hud.update_status(warning, Color("#FF5252"))
		SoundManager.play_sfx("warning")

func _complete_mission(passed: bool) -> void:
	mission_ended = true
	player.can_move = false
	
	var grade := "C"
	if passed:
		if score >= 2300:
			grade = "S (DISTINGUISHED)"
		elif score >= 1800:
			grade = "A (EXEMPLARY)"
		else:
			grade = "B (COMPLIANT)"
			
	var report := {
		"passed": passed,
		"score": score,
		"grade": grade,
		"hazards": hazards_inspected_count,
		"residents": residents_saved_count,
		"supplies": supplies_collected_count,
		"decisions": decisions_log
	}
	
	Campaign.record_report(mission_id, report)
	SoundManager.play_sfx("success" if passed else "warning")
	
	# Show After-Action Debrief screen
	var debrief := MissionDebrief.new()
	debrief.setup(mission_id, report)
	debrief.continue_requested.connect(_on_continue_campaign)
	debrief.replay_requested.connect(_on_replay_mission)
	debrief.menu_requested.connect(_on_return_to_menu)
	hud.add_child(debrief)

func _on_continue_campaign() -> void:
	if mission_id < 2:
		Campaign.mission_id = mission_id + 1
		SceneTransition.reload_scene()
	else:
		# Show Campaign Final Report
		var rep := CampaignReport.new()
		rep.closed.connect(_on_return_to_menu)
		hud.add_child(rep)

func _on_replay_mission() -> void:
	get_tree().paused = false
	Campaign.modal_active = false
	SceneTransition.reload_scene()

func _on_restart_requested() -> void:
	get_tree().paused = false
	Campaign.modal_active = false
	SceneTransition.reload_scene()

func _on_return_to_menu() -> void:
	get_tree().paused = false
	Campaign.modal_active = false
	SceneTransition.change_scene("res://scenes/main_menu.tscn")

func _on_pause_toggled(_p: bool) -> void:
	player.can_move = not _p and evacuation_active and not is_shaking and not mission_ended

func _on_input_overlay_toggled(open: bool) -> void:
	if open:
		player.can_move = false
	elif not mission_ended:
		player.can_move = evacuation_active and not is_shaking

func _on_interaction_modal_cancelled() -> void:
	if not mission_ended:
		player.can_move = evacuation_active and not is_shaking

func _on_handbook_requested() -> void:
	var hb := PreparednessHandbook.new()
	hb.closed.connect(func(): player.can_move = true)
	hud.add_child(hb)
	player.can_move = false

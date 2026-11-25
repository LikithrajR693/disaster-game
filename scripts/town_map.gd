extends Node2D
class_name TownMap

# Procedural 2D Environment for the fictional Indian town of AARANYA (2400 x 1600)
# Clean, enterprise-grade NDMA disaster-response simulation.
# Detailed top-down architectural blueprints: rooftop parapet borders, AC/solar vents,
# courtyard markings, clear entry thresholds, high-contrast header plaques, and disaster effects.

signal safe_zone_reached

var mission_id: int = 0
var anim_timer: float = 0.0
var _streetlights: Array[PointLight2D] = []
var _light_clock: float = 0.0
var _light_texture: Texture2D
var _dust_emitter: GPUParticles2D
var _dust_bursts: Array[GPUParticles2D] = []
var _rain_emitter: GPUParticles2D
var _substation_light: PointLight2D
var _substation_sparks: GPUParticles2D
var _substation_timer: float = 2.2
var _substation_flash_time: float = 0.0
var _random := RandomNumberGenerator.new()

# Safe zone area
var safe_zone_area: Area2D

func setup(m_id: int) -> void:
	mission_id = m_id
	_build_physical_colliders()
	_build_safe_zone()
	_build_atmosphere()

func _process(delta: float) -> void:
	anim_timer += delta
	_light_clock += delta
	_substation_timer -= delta
	_substation_flash_time = maxf(0.0, _substation_flash_time - delta)
	if is_instance_valid(_substation_light):
		_substation_light.energy = 1.8 if _substation_flash_time > 0.0 else 0.0
	if _substation_timer <= 0.0:
		_substation_timer = _random.randf_range(1.7, 2.7)
		_substation_flash_time = 0.12
		if is_instance_valid(_substation_sparks):
			_substation_sparks.emitting = true
			_substation_sparks.restart()
		SoundManager.play_electric_arc()
	for index in range(_streetlights.size()):
		if is_instance_valid(_streetlights[index]):
			var flicker := 0.68 + 0.22 * (0.5 + 0.5 * sin(_light_clock * (3.4 + index * 0.13) + index))
			if fmod(_light_clock + index * 0.41, 5.7 + index * 0.07) < 0.07:
				flicker *= 0.28
			_streetlights[index].energy = flicker
	queue_redraw()

func trigger_tremor() -> void:
	if is_instance_valid(_dust_emitter):
		_dust_emitter.restart()
	for burst in _dust_bursts:
		if is_instance_valid(burst):
			burst.emitting = true
			burst.restart()

func _build_atmosphere() -> void:
	_random.randomize()
	var modulate := CanvasModulate.new()
	modulate.color = Color(0.42, 0.46, 0.54, 1.0)
	add_child(modulate)

	_light_texture = _make_light_texture()
	for lamp_position in [
		Vector2(450, 675), Vector2(800, 675), Vector2(1400, 675), Vector2(1750, 675),
		Vector2(450, 925), Vector2(800, 925), Vector2(1400, 925), Vector2(1750, 925),
		Vector2(955, 300), Vector2(955, 1250), Vector2(1245, 300), Vector2(1245, 1250)
	]:
		var lamp := _add_light(lamp_position, Color(1.0, 0.72, 0.34), 0.76, 2.4)
		_streetlights.append(lamp)

	var safe_light := _add_light(get_safe_zone_center(), Color(0.20, 1.0, 0.52), 1.25, 4.0)
	safe_light.texture_scale = 3.2
	var clinic_light := _add_light(Vector2(1730, 1365), Color(0.20, 1.0, 0.52), 1.1, 3.2)
	clinic_light.texture_scale = 2.8
	_substation_light = _add_light(Vector2(820, 240), Color(0.34, 0.86, 1.0), 0.0, 3.0)
	_substation_sparks = _make_particles(14, 0.24, Vector2(820, 240), Color(0.55, 0.84, 1.0, 0.95), Vector2(0, -1), 180.0, 80.0, 250.0)
	_substation_sparks.one_shot = true
	_substation_sparks.explosiveness = 1.0
	_substation_sparks.emitting = false

	_dust_emitter = _make_particles(180, 7.0, Vector2(1200, 800), Color(0.78, 0.74, 0.66, 0.36), Vector2(1.0, -0.15), 8.0, 6.0, 20.0)
	_dust_emitter.emitting = mission_id != 1
	if mission_id == 0:
		for debris_position in [Vector2(390, 448), Vector2(420, 944), Vector2(610, 826), Vector2(1100, 550)]:
			_dust_bursts.append(_make_dust_burst(debris_position))
	if mission_id == 1:
		_rain_emitter = _make_particles(300, 1.7, Vector2(1200, 800), Color(0.65, 0.82, 0.95, 0.64), Vector2(0.18, 1.0), 14.0, 360.0, 520.0)
		_rain_emitter.texture = _make_rain_texture()

func _add_light(at: Vector2, light_color: Color, energy: float, size: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.position = at
	light.texture = _light_texture
	light.color = light_color
	light.energy = energy
	light.texture_scale = size
	light.shadow_enabled = false
	add_child(light)
	return light

func _make_light_texture() -> Texture2D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var distance := Vector2(x - 63.5, y - 63.5).length() / 64.0
			var alpha := pow(maxf(0.0, 1.0 - distance), 2.4)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)

func _make_rain_texture() -> Texture2D:
	var image := Image.create(4, 20, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.72, 0.88, 1.0, 0.8))
	return ImageTexture.create_from_image(image)

func _make_particles(amount: int, lifetime: float, at: Vector2, particle_color: Color, direction: Vector2, spread_degrees: float, speed_min: float, speed_max: float) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.position = at
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.0
	particles.local_coords = true
	particles.texture = _make_particle_texture(particle_color)
	particles.visibility_rect = Rect2(-1300, -900, 2600, 1800)
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(1200, 800, 1)
	process_material.direction = Vector3(direction.x, direction.y, 0)
	process_material.spread = spread_degrees
	process_material.initial_velocity_min = speed_min
	process_material.initial_velocity_max = speed_max
	process_material.gravity = Vector3(0, -3 if direction.y < 0.0 else 260, 0)
	process_material.scale_min = 0.45 if speed_max < 100.0 else 0.55
	process_material.scale_max = 1.3 if speed_max < 100.0 else 1.0
	particles.process_material = process_material
	add_child(particles)
	return particles

func _make_dust_burst(at: Vector2) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.position = at
	particles.amount = 32
	particles.lifetime = 1.1
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = false
	particles.texture = _make_particle_texture(Color(0.76, 0.70, 0.60, 0.48))
	particles.visibility_rect = Rect2(-100, -90, 200, 180)
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(34, 18, 1)
	process_material.direction = Vector3(0, -1, 0)
	process_material.spread = 180.0
	process_material.initial_velocity_min = 36.0
	process_material.initial_velocity_max = 120.0
	process_material.gravity = Vector3(0, 48, 0)
	process_material.scale_min = 0.7
	process_material.scale_max = 2.4
	process_material.color = Color(0.76, 0.70, 0.60, 0.48)
	particles.process_material = process_material
	add_child(particles)
	return particles

func _make_particle_texture(particle_color: Color) -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	for y in range(8):
		for x in range(8):
			var distance := Vector2(x - 3.5, y - 3.5).length()
			var alpha := clampf(1.0 - distance / 4.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(particle_color.r, particle_color.g, particle_color.b, particle_color.a * alpha))
	return ImageTexture.create_from_image(image)

func _build_physical_colliders() -> void:
	# Add StaticBody2D collision boxes for all buildings so the player cannot walk through them
	_add_building_collider(Rect2(80, 80, 560, 360))   # School
	_add_building_collider(Rect2(1440, 80, 600, 360)) # Community Hall
	_add_building_collider(Rect2(100, 960, 640, 520)) # Residential Apartments (Ward 4)
	_add_building_collider(Rect2(1460, 960, 540, 420)) # Clinic / PHC
	_add_building_collider(Rect2(720, 80, 200, 240))  # Water Reservoir / Substation

	# Keep movement inside the drawn town and prevent walking through tree trunks.
	_add_building_collider(Rect2(-40, -40, 40, 1680))
	_add_building_collider(Rect2(2400, -40, 40, 1680))
	_add_building_collider(Rect2(0, -40, 2400, 40))
	_add_building_collider(Rect2(0, 1600, 2400, 40))
	for tree_pos in [
		Vector2(680, 420), Vector2(740, 560), Vector2(880, 450),
		Vector2(1320, 440), Vector2(1380, 600), Vector2(1260, 1020),
		Vector2(780, 1020), Vector2(840, 1180), Vector2(1380, 1420),
		Vector2(2040, 400), Vector2(2180, 460), Vector2(2040, 1200),
		Vector2(2200, 1260), Vector2(400, 620), Vector2(1600, 620)
	]:
		_add_circle_collider(tree_pos, 14.0)

func _add_building_collider(rect: Rect2) -> void:
	var sb := StaticBody2D.new()
	sb.collision_layer = 1
	sb.collision_mask = 1
	sb.position = rect.position + rect.size * 0.5
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	sb.add_child(shape)
	add_child(sb)

func _add_circle_collider(center: Vector2, radius: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = center
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)
	add_child(body)

func _build_safe_zone() -> void:
	safe_zone_area = Area2D.new()
	safe_zone_area.collision_layer = 16
	safe_zone_area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	
	match mission_id:
		0:
			safe_zone_area.position = Vector2(2100, 800)
			box.size = Vector2(380, 480)
		1:
			safe_zone_area.position = Vector2(1740, 260)
			box.size = Vector2(360, 240)
		2:
			safe_zone_area.position = Vector2(980, 1300)
			box.size = Vector2(360, 280)
			
	shape.shape = box
	safe_zone_area.add_child(shape)
	safe_zone_area.body_entered.connect(_on_safe_zone_entered)
	add_child(safe_zone_area)

func _on_safe_zone_entered(body: Node2D) -> void:
	if body is PlayerController:
		safe_zone_reached.emit()

func get_safe_zone_center() -> Vector2:
	if is_instance_valid(safe_zone_area):
		return safe_zone_area.position
	return Vector2(2100, 800)

func _draw() -> void:
	# 1. Base Ground (Earthen deep green with subtle terrain shading)
	draw_rect(Rect2(0, 0, 2400, 1600), Color("#14271E"))
	
	# Grass garden patches
	for gp in [Vector2(200, 520), Vector2(400, 580), Vector2(1300, 540), Vector2(1700, 600), Vector2(2100, 200), Vector2(2100, 1300)]:
		draw_circle(gp, 95.0, Color("#102119"))
		
	# 2. Sidewalks & Footpaths (Flagstone paving with curb bevel)
	draw_rect(Rect2(0, 675, 2400, 250), Color("#37424C"))
	draw_rect(Rect2(955, 0, 290, 1600), Color("#37424C"))
	draw_rect(Rect2(35, 35, 650, 450), Color("#2E3842"))
	draw_rect(Rect2(1395, 35, 690, 450), Color("#2E3842"))
	draw_rect(Rect2(55, 915, 730, 610), Color("#2E3842"))
	draw_rect(Rect2(1415, 915, 630, 510), Color("#2E3842"))
	
	# Sidewalk paving flagstone pattern
	for x in range(0, 2400, 60):
		draw_line(Vector2(x, 675), Vector2(x, 700), Color("#252E37"), 1.5)
		draw_line(Vector2(x, 900), Vector2(x, 925), Color("#252E37"), 1.5)
		
	# 3. Main Roads (Gandhi Marg East-West & Nehru Marg North-South)
	draw_rect(Rect2(0, 700, 2400, 200), Color("#1C2127"))
	draw_rect(Rect2(980, 0, 240, 1600), Color("#1C2127"))
	
	# Road Curbs (Light grey bevel)
	draw_line(Vector2(0, 700), Vector2(2400, 700), Color("#606E7D"), 3.0)
	draw_line(Vector2(0, 900), Vector2(2400, 900), Color("#606E7D"), 3.0)
	draw_line(Vector2(980, 0), Vector2(980, 1600), Color("#606E7D"), 3.0)
	draw_line(Vector2(1220, 0), Vector2(1220, 1600), Color("#606E7D"), 3.0)
	
	# Yellow dashed centerlines
	for x in range(0, 2400, 70):
		if x < 950 or x > 1250:
			draw_line(Vector2(x, 800), Vector2(x + 38, 800), Color("#F4B860"), 4.0)
	for y in range(0, 1600, 70):
		if y < 670 or y > 930:
			draw_line(Vector2(1100, y), Vector2(1100, y + 38), Color("#F4B860"), 4.0)
			
	# Zebra Crossings at Intersection
	_draw_zebra_crossing(Vector2(880, 710), Vector2(880, 890), false)
	_draw_zebra_crossing(Vector2(1240, 710), Vector2(1240, 890), false)
	_draw_zebra_crossing(Vector2(1000, 630), Vector2(1200, 630), true)
	_draw_zebra_crossing(Vector2(1000, 970), Vector2(1200, 970), true)
	
	# Roundabout Island at Central Intersection (1100, 800)
	draw_circle(Vector2(1100, 800), 75.0, Color("#1D4D32"))
	draw_circle(Vector2(1100, 800), 72.0, Color("#133623"))
	draw_circle(Vector2(1100, 800), 32.0, Color("#7E8E9B"))
	draw_circle(Vector2(1100, 800), 20.0, Color("#424E58"))
	draw_circle(Vector2(1100, 800), 8.0, Color("#F4B860"))
	
	# 4. Detailed Top-Down Architectural Blueprints
	_draw_school_building(Rect2(80, 80, 560, 360))
	_draw_community_hall(Rect2(1440, 80, 600, 360))
	_draw_residential_towers(Rect2(100, 960, 640, 520))
	_draw_clinic_building(Rect2(1460, 960, 540, 420))
	_draw_substation_compound(Rect2(720, 80, 200, 240))
	
	# 5. Trees (Lush Indian foliage: Neem, Gulmohar, Banyan)
	var tree_locs: Array[Vector2] = [
		Vector2(680, 420), Vector2(740, 560), Vector2(880, 450),
		Vector2(1320, 440), Vector2(1380, 600), Vector2(1260, 1020),
		Vector2(780, 1020), Vector2(840, 1180), Vector2(1380, 1420),
		Vector2(2040, 400), Vector2(2180, 460), Vector2(2040, 1200),
		Vector2(2200, 1260), Vector2(400, 620), Vector2(1600, 620)
	]
	for t in tree_locs:
		draw_circle(t + Vector2(12, 14), 32.0, Color(0, 0, 0, 0.32))
		draw_circle(t, 32.0, Color("#144C2D"))
		draw_circle(t + Vector2(-6, -6), 24.0, Color("#1F6A40"))
		draw_circle(t + Vector2(6, 6), 16.0, Color("#2C8B54"))
		draw_circle(t, 6.0, Color("#3E2713"))
		
	# 6. Streetlights with warm lighting halos
	var lamp_locs: Array[Vector2] = [
		Vector2(450, 675), Vector2(800, 675), Vector2(1400, 675), Vector2(1750, 675),
		Vector2(450, 925), Vector2(800, 925), Vector2(1400, 925), Vector2(1750, 925),
		Vector2(955, 300), Vector2(955, 1250), Vector2(1245, 300), Vector2(1245, 1250)
	]
	for l in lamp_locs:
		draw_circle(l, 44.0, Color(1.0, 0.88, 0.5, 0.12))
		draw_circle(l, 8.0, Color("#F4B860"))
		draw_line(l, l + Vector2(0, 16), Color("#242C35"), 4.0)
		
	# 7. Safe Zone Visual Marking
	_draw_safe_zone_indicator()
	
	# 8. Disaster Effects
	_draw_disaster_effects()

func _draw_zebra_crossing(start: Vector2, end: Vector2, horizontal: bool) -> void:
	if horizontal:
		var x := start.x
		while x < end.x:
			draw_rect(Rect2(x, start.y, 22, 28), Color(1, 1, 1, 0.88))
			x += 38
	else:
		var y := start.y
		while y < end.y:
			draw_rect(Rect2(start.x, y, 28, 22), Color(1, 1, 1, 0.88))
			y += 38

# --- DETAILED ARCHITECTURAL BLUEPRINTS ---

func _draw_school_building(rect: Rect2) -> void:
	# Deep outer drop shadow
	draw_rect(Rect2(rect.position + Vector2(18, 20), rect.size), Color(0, 0, 0, 0.40))
	# Outer masonry walls (Warm Ochre/Sandstone)
	draw_rect(rect, Color("#C8BA95"))
	draw_rect(rect, Color("#6D4C41"), false, 4.0)
	
	# Inset Rooftop Parapet
	var roof := Rect2(rect.position + Vector2(14, 14), rect.size - Vector2(28, 28))
	draw_rect(roof, Color("#B2A47F"))
	draw_rect(roof, Color("#5D4037"), false, 2.5)
	
	# School Courtyard / Assembly Quadrangle
	var court := Rect2(roof.position + Vector2(20, 80), Vector2(roof.size.x - 40, roof.size.y - 100))
	draw_rect(court, Color("#8C7D5D"))
	draw_rect(court, Color("#4E342E"), false, 2.0)
	# Courtyard markings / badminton-prayer lines
	draw_rect(Rect2(court.position + Vector2(40, 20), court.size - Vector2(80, 40)), Color(1, 1, 1, 0.25), false, 1.5)
	
	# Rooftop Solar Panels (Eco-school detail)
	for i in range(4):
		var sp_pos := roof.position + Vector2(30 + i * 55, 30)
		draw_rect(Rect2(sp_pos, Vector2(45, 32)), Color("#1A365D"))
		draw_rect(Rect2(sp_pos, Vector2(45, 32)), Color("#63B3ED"), false, 1.5)
		draw_line(sp_pos + Vector2(22, 0), sp_pos + Vector2(22, 32), Color("#63B3ED"), 1.0)
		
	# Water storage tank on rooftop
	draw_circle(roof.position + Vector2(roof.size.x - 50, 45), 20.0, Color("#4A5568"))
	draw_circle(roof.position + Vector2(roof.size.x - 50, 45), 16.0, Color("#2B6CB0"))
	
	# Header Plaque
	_draw_header_plaque(rect, "AARANYA VIDYALAYA (GOVT HIGHER SECONDARY SCHOOL)", Color("#1A365D"), Color("#F4B860"))
	# Clear Entry Threshold
	_draw_entry_threshold(rect, 80.0, Color("#6D4C41"))

func _draw_community_hall(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(18, 20), rect.size), Color(0, 0, 0, 0.40))
	# Blue-grey reinforced concrete facade
	draw_rect(rect, Color("#B0BEC5"))
	draw_rect(rect, Color("#263238"), false, 4.0)
	
	var roof := Rect2(rect.position + Vector2(16, 16), rect.size - Vector2(32, 32))
	draw_rect(roof, Color("#90A4AE"))
	draw_rect(roof, Color("#37474F"), false, 2.5)
	
	# Elevated plinth border
	draw_rect(Rect2(rect.position - Vector2(8, 8), rect.size + Vector2(16, 16)), Color(0.2, 0.6, 0.9, 0.25), false, 2.0)
	
	# Rooftop AC chiller units & ventilation arrays
	for i in range(3):
		var ac_pos := roof.position + Vector2(60 + i * 110, 80)
		draw_rect(Rect2(ac_pos, Vector2(75, 45)), Color("#455A64"))
		draw_rect(Rect2(ac_pos, Vector2(75, 45)), Color("#CFD8DC"), false, 1.5)
		draw_circle(ac_pos + Vector2(37, 22), 14.0, Color("#263238"))
		
	# Skylight domes (Relief center natural illumination)
	for j in range(3):
		var sky_pos := roof.position + Vector2(100 + j * 140, 220)
		draw_circle(sky_pos, 28.0, Color("#607D8B"))
		draw_circle(sky_pos, 22.0, Color(0.3, 0.7, 0.9, 0.7))
		
	_draw_header_plaque(rect, "COMMUNITY DISASTER RELIEF CENTER (SHELTER +2.5m)", Color("#0D47A1"), Color("#90CAF9"))
	_draw_entry_threshold(rect, 90.0, Color("#1565C0"))

func _draw_residential_towers(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(18, 20), rect.size), Color(0, 0, 0, 0.40))
	# Multi-story apartment block (Warm Terracotta/Brick)
	draw_rect(rect, Color("#BCAAA4"))
	draw_rect(rect, Color("#4E342E"), false, 4.0)
	
	var roof := Rect2(rect.position + Vector2(16, 16), rect.size - Vector2(32, 32))
	draw_rect(roof, Color("#A1887F"))
	draw_rect(roof, Color("#3E2723"), false, 2.5)
	
	# Wing division line (Block A & Block B)
	var mid_x := roof.position.x + roof.size.x * 0.5
	draw_line(Vector2(mid_x, roof.position.y), Vector2(mid_x, roof.end.y), Color("#3E2723"), 3.0)
	
	# Rooftop water overhead tanks & elevator shafts
	draw_rect(Rect2(mid_x - 45, roof.position.y + 40, 90, 60), Color("#37474F"))
	draw_rect(Rect2(mid_x - 45, roof.position.y + 40, 90, 60), Color("#FF5252"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(mid_x - 40, roof.position.y + 75), "LIFT SHAFT", HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color("#FF8A80"))
	
	# Balcony arrays & ventilation ducts
	for bx in [roof.position.x + 35, mid_x + 35]:
		for by in range(int(roof.position.y) + 120, int(roof.end.y) - 60, 65):
			draw_rect(Rect2(bx, by, 70, 42), Color("#6D4C41"))
			draw_rect(Rect2(bx, by, 70, 42), Color("#D7CCC8"), false, 1.5)
			draw_rect(Rect2(bx + 110, by, 70, 42), Color("#6D4C41"))
			draw_rect(Rect2(bx + 110, by, 70, 42), Color("#D7CCC8"), false, 1.5)
			
	_draw_header_plaque(rect, "AARANYA TOWERS (RESIDENTIAL WARD 4 COMPLEX)", Color("#3E2723"), Color("#FFCCBC"))
	_draw_entry_threshold(rect, 85.0, Color("#4E342E"))

func _draw_clinic_building(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(18, 20), rect.size), Color(0, 0, 0, 0.40))
	# Clean clinical white/mint facade
	draw_rect(rect, Color("#CFD8DC"))
	draw_rect(rect, Color("#00695C"), false, 4.0)
	
	var roof := Rect2(rect.position + Vector2(16, 16), rect.size - Vector2(32, 32))
	draw_rect(roof, Color("#B0BEC5"))
	draw_rect(roof, Color("#004D40"), false, 2.5)
	
	# Rooftop Red Cross medical emblem
	var cross_center := roof.position + Vector2(roof.size.x * 0.5, 90)
	draw_circle(cross_center, 38.0, Color.WHITE)
	draw_rect(Rect2(cross_center + Vector2(-24, -8), Vector2(48, 16)), Color("#D32F2F"))
	draw_rect(Rect2(cross_center + Vector2(-8, -24), Vector2(16, 48)), Color("#D32F2F"))
	
	# Emergency ambulance bay apron
	var amb_bay := Rect2(roof.position.x + 40, roof.end.y - 120, 160, 80)
	draw_rect(amb_bay, Color("#37474F"))
	draw_rect(amb_bay, Color("#FFD54F"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(amb_bay.position.x + 5, amb_bay.position.y + 45), "AMBULANCE ONLY", HORIZONTAL_ALIGNMENT_CENTER, 150, 11, Color("#FFF59D"))
	
	_draw_header_plaque(rect, "AARANYA PRIMARY HEALTH CLINIC & EMERGENCY TRIAGE", Color("#004D40"), Color("#A7FFEB"))
	_draw_entry_threshold(rect, 80.0, Color("#00695C"))

func _draw_substation_compound(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(18, 20), rect.size), Color(0, 0, 0, 0.40))
	# Industrial steel/slate grey
	draw_rect(rect, Color("#78909C"))
	draw_rect(rect, Color("#E65100"), false, 3.5)
	
	# High voltage danger warning hatchings
	for hx in range(int(rect.position.x) + 15, int(rect.end.x) - 15, 30):
		draw_line(Vector2(hx, rect.position.y + 15), Vector2(hx + 18, rect.end.y - 15), Color("#D84315", 0.5), 2.0)
		
	# Transformer coils
	draw_circle(rect.position + Vector2(60, 140), 28.0, Color("#37474F"))
	draw_circle(rect.position + Vector2(140, 140), 28.0, Color("#37474F"))
	draw_circle(rect.position + Vector2(60, 140), 18.0, Color("#FFB300"))
	draw_circle(rect.position + Vector2(140, 140), 18.0, Color("#FFB300"))
	
	_draw_header_plaque(rect, "11kV SUBSTATION", Color("#BF360C"), Color("#FFE082"))

func _draw_header_plaque(b_rect: Rect2, text: String, bg_color: Color, border_color: Color) -> void:
	var plaque_w := minf(b_rect.size.x - 36, 440.0)
	var plaque_rect := Rect2(b_rect.position.x + (b_rect.size.x - plaque_w) * 0.5, b_rect.position.y + 18, plaque_w, 30)
	draw_rect(plaque_rect, bg_color)
	draw_rect(plaque_rect, border_color, false, 1.8)
	draw_string(ThemeDB.fallback_font, plaque_rect.position + Vector2(8, 20), text, HORIZONTAL_ALIGNMENT_CENTER, plaque_w - 16, 12, border_color)

func _draw_entry_threshold(b_rect: Rect2, width: float, frame_color: Color) -> void:
	var ent_pos := Vector2(b_rect.position.x + (b_rect.size.x - width) * 0.5, b_rect.end.y - 12)
	draw_rect(Rect2(ent_pos, Vector2(width, 22)), frame_color)
	draw_rect(Rect2(ent_pos + Vector2(8, 4), Vector2(width - 16, 16)), Color("#101418"))
	draw_string(ThemeDB.fallback_font, ent_pos + Vector2(0, 15), "ENTRY", HORIZONTAL_ALIGNMENT_CENTER, width, 10, Color("#E2E8F0"))

func _draw_safe_zone_indicator() -> void:
	var center := get_safe_zone_center()
	var pulse := (sin(anim_timer * 3.0) + 1.0) * 0.5
	
	match mission_id:
		0:
			draw_circle(center, 180.0, Color(0.1, 0.7, 0.3, 0.12 + pulse * 0.08))
			draw_arc(center, 180.0, 0, TAU, 32, Color(0.2, 0.9, 0.4, 0.6 + pulse * 0.3), 3.0)
			draw_string(ThemeDB.fallback_font, center + Vector2(-120, -12), "★ DESIGNATED OPEN ASSEMBLY AREA ★", HORIZONTAL_ALIGNMENT_CENTER, 240, 13, Color("#69F0AE"))
			draw_string(ThemeDB.fallback_font, center + Vector2(-120, 12), "(CLEAR SKY • SAFE FROM DEBRIS)", HORIZONTAL_ALIGNMENT_CENTER, 240, 11, Color("#B9F6CA"))
		1:
			draw_rect(Rect2(center - Vector2(160, 110), Vector2(320, 220)), Color(0.2, 0.6, 0.9, 0.15 + pulse * 0.1))
			draw_rect(Rect2(center - Vector2(160, 110), Vector2(320, 220)), Color(0.3, 0.8, 1.0, 0.7), false, 3.0)
			draw_string(ThemeDB.fallback_font, center + Vector2(-130, 0), "★ ELEVATED FLOOD SHELTER (+2.5m) ★", HORIZONTAL_ALIGNMENT_CENTER, 260, 13, Color("#80D8FF"))
		2:
			draw_rect(Rect2(center - Vector2(150, 120), Vector2(300, 240)), Color(0.1, 0.7, 0.3, 0.15 + pulse * 0.1))
			draw_rect(Rect2(center - Vector2(150, 120), Vector2(300, 240)), Color(0.2, 0.9, 0.4, 0.7), false, 3.0)
			draw_string(ThemeDB.fallback_font, center + Vector2(-130, 0), "★ EXTERNAL FIRE ASSEMBLY POINT ★", HORIZONTAL_ALIGNMENT_CENTER, 260, 13, Color("#69F0AE"))

func _draw_disaster_effects() -> void:
	match mission_id:
		0:
			var fissure_color := Color("#101418")
			draw_line(Vector2(500, 780), Vector2(620, 830), fissure_color, 7.0)
			draw_line(Vector2(620, 830), Vector2(740, 800), fissure_color, 8.0)
			draw_line(Vector2(740, 800), Vector2(820, 860), fissure_color, 6.0)
			draw_line(Vector2(1040, 480), Vector2(1120, 540), fissure_color, 7.0)
			draw_line(Vector2(1120, 540), Vector2(1080, 620), fissure_color, 6.0)
			
			draw_circle(Vector2(380, 460), 22.0, Color("#8D7B68"))
			draw_circle(Vector2(400, 470), 16.0, Color("#A4907C"))
			draw_circle(Vector2(360, 470), 14.0, Color("#C8B6A6"))
			draw_circle(Vector2(430, 942), 18.0, Color("#7A6B5E"))
			draw_circle(Vector2(456, 950), 12.0, Color("#A28E7B"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(488, 764), Vector2(512, 770), Vector2(506, 790), Vector2(482, 784)
			]), Color("#82766A"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(630, 824), Vector2(650, 818), Vector2(660, 836), Vector2(640, 846)
			]), Color("#A08D7D"))
			_draw_hazard_barricade(Vector2(780, 720))
			
			var pole_pos := Vector2(780, 720)
			draw_line(pole_pos, pole_pos + Vector2(35, 12), Color("#2C353F"), 6.0)
			if fmod(anim_timer, 0.4) < 0.15:
				draw_circle(pole_pos + Vector2(40, 14), 12.0, Color(1.0, 0.9, 0.3, 0.8))
				draw_line(pole_pos + Vector2(35, 12), pole_pos + Vector2(55, 6), Color.WHITE, 2.0)
				
		1:
			var water_wave := sin(anim_timer * 2.5) * 8.0
			var flood_color := Color(0.18, 0.38, 0.45, 0.72)
			
			draw_rect(Rect2(1200, 700 + water_wave * 0.3, 1200, 200), flood_color)
			draw_rect(Rect2(980, 900, 240, 700), flood_color)
			for fx in range(1240, 2350, 110):
				var wy := 760.0 + sin(anim_timer * 3.0 + fx * 0.02) * 14.0
				draw_line(Vector2(fx, wy), Vector2(fx + 40, wy), Color(0.6, 0.85, 0.95, 0.6), 2.5)
			for fy in range(920, 1550, 100):
				var wx := 1050.0 + cos(anim_timer * 2.5 + fy * 0.02) * 12.0
				draw_line(Vector2(wx, fy), Vector2(wx + 30, fy), Color(0.6, 0.85, 0.95, 0.6), 2.5)
			for ripple_index in range(4):
				var phase := fmod(anim_timer * 0.8 + ripple_index * 0.25, 1.0)
				var radius := 8.0 + phase * 34.0
				var alpha := 0.48 * (1.0 - phase)
				draw_arc(Vector2(1130, 790), radius, 0.0, TAU, 24, Color(0.72, 0.9, 0.98, alpha), 1.5)
				draw_arc(Vector2(1080, 1040), radius * 0.8, 0.0, TAU, 24, Color(0.72, 0.9, 0.98, alpha * 0.8), 1.2)
			draw_line(Vector2(1200, 706), Vector2(1200, 894), Color(0.76, 0.9, 0.95, 0.55), 3.0)
			draw_line(Vector2(982, 900), Vector2(1218, 900), Color(0.76, 0.9, 0.95, 0.55), 3.0)
				
			draw_rect(Rect2(1380, 770, 70, 36), Color("#8C3B3B"))
			draw_circle(Vector2(1415, 788), 12.0, Color(0.2, 0.5, 0.6, 0.5))
			
			draw_rect(Rect2(1210, 705, 12, 190), Color("#E74C3C"))
			draw_rect(Rect2(1206, 740, 20, 30), Color("#F4B860"))
			draw_string(ThemeDB.fallback_font, Vector2(1170, 695), "ROAD CLOSED - FLOOD", HORIZONTAL_ALIGNMENT_CENTER, 140, 10, Color("#FF6B6B"))
			
		2:
			var smoke_phase := fmod(anim_timer, 2.0) / 2.0
			for s in [Vector2(240, 1100), Vector2(360, 1160), Vector2(480, 1080), Vector2(280, 1240)]:
				var s_offset := Vector2(cos(anim_timer + s.x) * 15.0, -smoke_phase * 40.0)
				draw_circle(s + s_offset, 45.0 + smoke_phase * 20.0, Color(0.12, 0.12, 0.14, 0.45 * (1.0 - smoke_phase)))
				
			for fl in [Vector2(200, 1060), Vector2(320, 1040), Vector2(440, 1060)]:
				var flame_h := 18.0 + sin(anim_timer * 12.0 + fl.x) * 6.0
				var f_pts: PackedVector2Array = [
					fl + Vector2(-12, 8),
					fl + Vector2(12, 8),
					fl + Vector2(0, -flame_h)
				]
				draw_colored_polygon(f_pts, Color("#FF5722"))
				draw_colored_polygon(PackedVector2Array([fl + Vector2(-6, 6), fl + Vector2(6, 6), fl + Vector2(0, -flame_h * 0.6)]), Color("#FFEB3B"))

func _draw_hazard_barricade(center: Vector2) -> void:
	draw_line(center + Vector2(-52, -34), center + Vector2(52, -34), Color("#D32F2F"), 5.0)
	for x in range(-48, 49, 18):
		draw_line(center + Vector2(x, -38), center + Vector2(x + 12, -30), Color("#F4B860"), 3.0)
	for cone_x in [-54.0, 54.0]:
		var cone := center + Vector2(cone_x, -26)
		draw_colored_polygon(PackedVector2Array([
			cone + Vector2(-7, 12), cone + Vector2(7, 12), cone + Vector2(0, -8)
		]), Color("#F07832"))

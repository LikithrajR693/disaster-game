extends Area2D
class_name Hazard

# In-world interactable disaster hazard with animated warning feedback and NDMA dossier

signal hazard_inspected(hazard_data: Dictionary)

@export var hazard_id: String = "hazard_1"
@export var hazard_title: String = "Exposed Power Lines"
@export var hazard_type: String = "ELECTRICAL" # ELECTRICAL, STRUCTURAL, WATER, FIRE
@export var threat_level: String = "CRITICAL"
@export var ndma_rule: String = "Maintain at least 10 meters distance from fallen wires. Water conducts electricity rapidly. Report to Aaranya Electricity Board."
@export var description: String = "Downed 11kV distribution line hanging over wet road surface. High risk of fatal electrocution."

var inspected: bool = false
var pulse_time: float = 0.0
var player_in_range: bool = false
var _arc_timer: float = 0.8
var _flash_time: float = 0.0
var _arc_light: PointLight2D
var _spark_particles: GPUParticles2D
var _smoke_particles: GPUParticles2D
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	shape.shape = circle
	add_child(shape)
	
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_build_local_effects()

func _build_local_effects() -> void:
	if hazard_type == "ELECTRICAL":
		_arc_light = PointLight2D.new()
		_arc_light.texture = _make_light_texture()
		_arc_light.color = Color(0.55, 0.88, 1.0)
		_arc_light.texture_scale = 1.2
		_arc_light.energy = 0.0
		_arc_light.shadow_enabled = false
		add_child(_arc_light)

		_spark_particles = _create_particles(16, 0.32, Color(1.0, 0.66, 0.24, 0.95), 95.0, 280.0)
		_spark_particles.one_shot = true
		_spark_particles.explosiveness = 1.0
		_spark_particles.emitting = false
		add_child(_spark_particles)
	elif hazard_type in ["STRUCTURAL", "FIRE"]:
		_smoke_particles = _create_particles(24, 2.4, Color(0.48, 0.48, 0.46, 0.28), 5.0, 20.0)
		_smoke_particles.explosiveness = 0.0
		add_child(_smoke_particles)

func _create_particles(amount: int, lifetime: float, particle_color: Color, speed_min: float, speed_max: float) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.texture = _make_particle_texture(particle_color)
	particles.visibility_rect = Rect2(-100, -130, 200, 180)
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 8.0
	process_material.direction = Vector3(0, -1, 0)
	process_material.spread = 180.0
	process_material.initial_velocity_min = speed_min
	process_material.initial_velocity_max = speed_max
	process_material.gravity = Vector3(0, -24, 0)
	process_material.scale_min = 0.6
	process_material.scale_max = 1.7
	process_material.color = particle_color
	particles.process_material = process_material
	return particles

func _make_light_texture() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var distance := Vector2(x - 31.5, y - 31.5).length() / 32.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(maxf(0.0, 1.0 - distance), 2.0)))
	return ImageTexture.create_from_image(image)

func _make_particle_texture(particle_color: Color) -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	for y in range(8):
		for x in range(8):
			var alpha := clampf(1.0 - Vector2(x - 3.5, y - 3.5).length() / 4.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(particle_color.r, particle_color.g, particle_color.b, particle_color.a * alpha))
	return ImageTexture.create_from_image(image)

func _on_area_entered(area: Area2D) -> void:
	if area.name == "InteractionDetector" or area.get_parent() is PlayerController:
		if not player_in_range and not inspected:
			SoundManager.play_hazard_alert()
		player_in_range = true

func _on_area_exited(area: Area2D) -> void:
	if area.name == "InteractionDetector" or area.get_parent() is PlayerController:
		player_in_range = false

func _process(delta: float) -> void:
	pulse_time += delta * 3.5
	if hazard_type == "ELECTRICAL":
		_arc_timer -= delta
		_flash_time = maxf(0.0, _flash_time - delta)
		if _arc_light != null:
			_arc_light.energy = 1.65 if _flash_time > 0.0 else 0.0
		if _arc_timer <= 0.0:
			_arc_timer = _random.randf_range(GameConfig.ELECTRICAL_ARC_INTERVAL_MIN, GameConfig.ELECTRICAL_ARC_INTERVAL_MAX)
			_flash_time = 0.11
			_spark_particles.emitting = true
			_spark_particles.restart()
			SoundManager.play_electric_arc()
	queue_redraw()

func _draw() -> void:
	# If any modal is active on screen, suppress world space text
	var show_labels := (player_in_range or Campaign.tactical_scan_active) and not Campaign.modal_active
	var pulse := (sin(pulse_time) + 1.0) * 0.5
	
	if not inspected:
		# Concentric pulsing radar rings
		var halo_color := Color(0.95, 0.25, 0.2, 0.15 + pulse * 0.2)
		draw_arc(Vector2.ZERO, 46.0 + pulse * 14.0, 0, TAU, 32, halo_color, 2.0)
		draw_arc(Vector2.ZERO, 36.0 + pulse * 8.0, 0, TAU, 28, Color(0.95, 0.25, 0.2, 0.35 + pulse * 0.2), 2.0)
		
		# Inner badge base
		draw_circle(Vector2.ZERO, 25.0, Color("#13090A", 0.95))
		draw_circle(Vector2.ZERO, 22.0, Color("#B71C1C"))
		draw_circle(Vector2.ZERO, 19.0, Color("#1C1517"))
		
		# Icon inside
		match hazard_type:
			"ELECTRICAL":
				var pts: PackedVector2Array = [
					Vector2(2, -13), Vector2(-6, -1), Vector2(1, -1),
					Vector2(-3, 13), Vector2(7, -1), Vector2(0, -1)
				]
				draw_colored_polygon(pts, Color("#FFD54F"))
			"STRUCTURAL":
				draw_line(Vector2(-10, -10), Vector2(-2, 0), Color("#FFD54F"), 3.0)
				draw_line(Vector2(-2, 0), Vector2(8, -4), Color("#FFD54F"), 3.0)
				draw_line(Vector2(-2, 0), Vector2(2, 12), Color("#FFD54F"), 3.0)
			"WATER":
				draw_arc(Vector2(-6, 0), 6.0, PI, TAU, 8, Color("#4FC3F7"), 3.0)
				draw_arc(Vector2(6, 0), 6.0, PI, TAU, 8, Color("#4FC3F7"), 3.0)
			"FIRE":
				var pts: PackedVector2Array = [
					Vector2(0, -13), Vector2(8, 4), Vector2(4, 11),
					Vector2(-4, 11), Vector2(-8, 4)
				]
				draw_colored_polygon(pts, Color("#FF7043"))
			_:
				draw_line(Vector2(0, -10), Vector2(0, 2), Color("#FFD54F"), 4.0)
				draw_circle(Vector2(0, 8), 2.5, Color("#FFD54F"))
		
		# Clean non-overlapping status pill: only when in range or scan active
		if show_labels:
			var pill_rect := Rect2(-54, -40, 108, 18)
			draw_rect(pill_rect, Color("#160809", 0.92))
			draw_rect(pill_rect, Color("#E53935"), false, 1.5)
			draw_string(ThemeDB.fallback_font, Vector2(-54, -26), "ACTIVE HAZARD", HORIZONTAL_ALIGNMENT_CENTER, 108, 10, Color("#FF8A80"))
	else:
		# Inspected & Barricaded state (Secured)
		draw_line(Vector2(-38, -30), Vector2(38, -30), Color("#D32F2F"), 4.0)
		for tape_x in range(-34, 35, 14):
			draw_line(Vector2(tape_x, -33), Vector2(tape_x + 9, -27), Color("#F4B860"), 2.5)
		for cone_x in [-42.0, 42.0]:
			var cone := Vector2(cone_x, -22)
			draw_colored_polygon(PackedVector2Array([
				cone + Vector2(-5, 9), cone + Vector2(5, 9), cone + Vector2(0, -6)
			]), Color("#F07832"))
		draw_arc(Vector2.ZERO, 30.0, 0, TAU, 24, Color(0.18, 0.8, 0.44, 0.25), 1.5)
		draw_circle(Vector2.ZERO, 20.0, Color("#081A12", 0.95))
		draw_circle(Vector2.ZERO, 17.0, Color("#1E824C"))
		draw_circle(Vector2.ZERO, 14.0, Color("#0B2318"))
		
		# Crisp checkmark
		draw_line(Vector2(-6, 0), Vector2(-1, 5), Color("#A7F3D0"), 2.5)
		draw_line(Vector2(-1, 5), Vector2(7, -5), Color("#A7F3D0"), 2.5)
		
		if show_labels:
			var pill_rect := Rect2(-54, -36, 108, 18)
			draw_rect(pill_rect, Color("#071910", 0.92))
			draw_rect(pill_rect, Color("#2ECC71"), false, 1.5)
			draw_string(ThemeDB.fallback_font, Vector2(-54, -22), "SECURED", HORIZONTAL_ALIGNMENT_CENTER, 108, 10, Color("#69F0AE"))

func inspect_hazard() -> Dictionary:
	if not inspected:
		inspected = true
		FeedbackManager.impact(global_position, Color("#E8C66A"), Vector2.ZERO, true)
		FeedbackManager.show_score_popup(global_position, "+250  HAZARD SECURED", Color("#E8C66A"))
		SoundManager.play_barricade_success()
		var data := {
			"id": hazard_id,
			"title": hazard_title,
			"type": hazard_type,
			"threat": threat_level,
			"ndma_rule": ndma_rule,
			"description": description
		}
		hazard_inspected.emit(data)
		queue_redraw()
		return data
	return {}

extends Node

var _hit_stop_generation: int = 0
var _hit_stop_active: bool = false
var _original_time_scale: float = 1.0
var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
var _flash_tween: Tween
var _particle_texture: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 15
	add_child(_flash_layer)

	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color.TRANSPARENT
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(_flash_rect)
	_particle_texture = _make_particle_texture()

func hit_stop(duration: float = -1.0) -> void:
	if duration <= 0.0:
		duration = GameConfig.HIT_STOP_DURATION
	if not _hit_stop_active:
		_original_time_scale = Engine.time_scale
		_hit_stop_active = true
	_hit_stop_generation += 1
	var generation := _hit_stop_generation
	Engine.time_scale = minf(Engine.time_scale, GameConfig.HIT_STOP_TIME_SCALE)
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(_restore_time_scale.bind(generation), CONNECT_ONE_SHOT)

func _restore_time_scale(generation: int) -> void:
	if generation != _hit_stop_generation or not _hit_stop_active:
		return
	Engine.time_scale = _original_time_scale
	_hit_stop_active = false

func cancel_hit_stop() -> void:
	if not _hit_stop_active:
		return
	Engine.time_scale = _original_time_scale
	_hit_stop_active = false
	_hit_stop_generation += 1

func impact(
	world_position: Vector2,
	tint: Color,
	inherited_velocity: Vector2 = Vector2.ZERO,
	heavy: bool = false
) -> void:
	spawn_burst(world_position, tint, inherited_velocity)
	flash(tint)
	if heavy:
		hit_stop()

func flash(tint: Color) -> void:
	if not is_instance_valid(_flash_rect):
		return
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	_flash_rect.color = Color(tint.r, tint.g, tint.b, GameConfig.IMPACT_FLASH_ALPHA)
	_flash_tween = create_tween()
	_flash_tween.set_trans(Tween.TRANS_CUBIC)
	_flash_tween.set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, GameConfig.IMPACT_FLASH_DURATION)

func spawn_burst(
	world_position: Vector2,
	tint: Color,
	inherited_velocity: Vector2 = Vector2.ZERO
) -> void:
	var scene := get_tree().current_scene
	if not (scene is Node2D):
		return

	var particles := CPUParticles2D.new()
	particles.position = world_position
	particles.z_index = 5
	particles.amount = GameConfig.IMPACT_PARTICLE_COUNT
	particles.lifetime = GameConfig.IMPACT_PARTICLE_LIFETIME
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.texture = _particle_texture
	particles.color = tint
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 4.0
	particles.direction = Vector2.UP + inherited_velocity.normalized() * 0.55
	particles.spread = 155.0
	particles.initial_velocity_min = GameConfig.IMPACT_PARTICLE_SPEED_MIN
	particles.initial_velocity_max = GameConfig.IMPACT_PARTICLE_SPEED_MAX
	particles.gravity = Vector2.DOWN * GameConfig.IMPACT_PARTICLE_GRAVITY
	particles.scale_amount_min = 0.65
	particles.scale_amount_max = 1.25
	particles.finished.connect(particles.queue_free, CONNECT_ONE_SHOT)
	scene.add_child(particles)
	particles.emitting = true

func show_score_popup(world_position: Vector2, message: String, tint: Color) -> void:
	var scene := get_tree().current_scene
	if not (scene is Node2D):
		return

	var popup := Label.new()
	popup.position = world_position + Vector2(-105, -36)
	popup.size = Vector2(210, 26)
	popup.z_index = 15
	popup.text = message
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 13)
	popup.add_theme_color_override("font_color", tint)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(popup)

	var tween := popup.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "position:y", popup.position.y - 32.0, GameConfig.SCORE_POPUP_DURATION)
	var fade := tween.parallel().tween_property(
		popup, "modulate:a", 0.0, GameConfig.SCORE_POPUP_DURATION
	)
	fade.set_delay(0.16)
	tween.tween_callback(popup.queue_free)

func _make_particle_texture() -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(8):
		for x in range(8):
			var distance := Vector2(x - 3.5, y - 3.5).length()
			var alpha := clampf(1.0 - distance / 4.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)

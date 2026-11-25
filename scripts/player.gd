extends CharacterBody2D
class_name PlayerController

# 2D Top-Down Emergency Response Coordinator Controller
# Handles WASD/Arrow movement, facing orientation, flashlight beam, and escort chain.

signal interaction_requested(target: Node2D)

const MOVE_SPEED: float = 230.0
const FOOTSTEP_INTERVAL: float = 0.32

var can_move: bool = true
var facing_direction: Vector2 = Vector2.DOWN
var walk_anim_time: float = 0.0
var footstep_time_remaining: float = 0.0
var breadcrumbs: Array[Vector2] = []
var max_breadcrumbs: int = 120

var nearby_interactable: Node2D = null

var interaction_detector: Area2D
var visuals: PlayerVisuals

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1 | 2 | 8 # Player collides with world geometry
	
	# Body collider
	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	body_shape.shape = circle
	add_child(body_shape)
	
	# Proximity interaction detector area
	interaction_detector = Area2D.new()
	interaction_detector.name = "InteractionDetector"
	interaction_detector.collision_layer = 0
	interaction_detector.collision_mask = 2 | 4 | 8 # Hazards (2), Supplies (4), Residents (8)
	var int_shape := CollisionShape2D.new()
	var int_circle := CircleShape2D.new()
	int_circle.radius = 65.0
	int_shape.shape = int_circle
	interaction_detector.add_child(int_shape)
	interaction_detector.area_entered.connect(_on_area_entered)
	interaction_detector.area_exited.connect(_on_area_exited)
	add_child(interaction_detector)
	
	# High quality NDRF First Responder visuals
	visuals = PlayerVisuals.new()
	visuals.name = "Visuals"
	add_child(visuals)

func _physics_process(delta: float) -> void:
	if not can_move or Campaign.modal_active:
		velocity = Vector2.ZERO
		move_and_slide()
		if is_instance_valid(visuals):
			visuals.is_moving = false
		return
		
	var input_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vec.length_squared() > 0.0:
		facing_direction = input_vec
		velocity = input_vec * MOVE_SPEED
		walk_anim_time += delta * 10.0
		
		# Record breadcrumbs for escort train
		if breadcrumbs.is_empty() or breadcrumbs.back().distance_to(global_position) > 12.0:
			breadcrumbs.append(global_position)
			if breadcrumbs.size() > max_breadcrumbs:
				breadcrumbs.pop_front()
				
		if is_instance_valid(visuals):
			visuals.facing_direction = facing_direction
			visuals.walk_anim_time = walk_anim_time
			visuals.is_moving = true
		footstep_time_remaining -= delta
		if footstep_time_remaining <= 0.0:
			var surface := _detect_surface()
			SoundManager.play_footstep(surface)
			footstep_time_remaining = FOOTSTEP_INTERVAL
	else:
		velocity = Vector2.ZERO
		footstep_time_remaining = 0.0
		if is_instance_valid(visuals):
			visuals.is_moving = false
		
	move_and_slide()
	
	# Keep the entire player collider inside the map bounds.
	global_position.x = clampf(global_position.x, 18.0, 2382.0)
	global_position.y = clampf(global_position.y, 18.0, 1582.0)
	
	_update_nearest_interactable()

func _detect_surface() -> String:
	# In Mission 1 (Flood), Gandhi Marg East (x >= 1200, y between 690 and 910) or South Nehru (y >= 900) is flooded water
	if Campaign.mission_id == 1:
		if (global_position.x >= 1200.0 and global_position.y >= 690.0 and global_position.y <= 920.0) or (global_position.x >= 970.0 and global_position.x <= 1230.0 and global_position.y >= 890.0):
			return "water"
	return "asphalt"

func _unhandled_input(event: InputEvent) -> void:
	if can_move and not Campaign.modal_active and (event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E)):
		if is_instance_valid(nearby_interactable):
			SoundManager.play_ui_click()
			interaction_requested.emit(nearby_interactable)
			get_viewport().set_input_as_handled()

func _on_area_entered(_area: Area2D) -> void:
	_update_nearest_interactable()

func _on_area_exited(_area: Area2D) -> void:
	_update_nearest_interactable()

func _update_nearest_interactable() -> void:
	var areas := interaction_detector.get_overlapping_areas()
	var closest: Node2D = null
	var min_dist := 9999.0
	for a in areas:
		if a is Hazard or a is SupplyItem or a.get_parent() is Resident:
			var target_node: Node2D = a.get_parent() if a.get_parent() is Resident else a
			var d := global_position.distance_to(target_node.global_position)
			if d < min_dist:
				min_dist = d
				closest = target_node
	nearby_interactable = closest

func register_escorted_resident(res: Node2D) -> void:
	if is_instance_valid(visuals) and not visuals.escorted_residents.has(res):
		visuals.escorted_residents.append(res)

func unregister_escorted_resident(res: Node2D) -> void:
	if is_instance_valid(visuals):
		visuals.escorted_residents.erase(res)

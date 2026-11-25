extends CharacterBody2D
class_name Resident

# Community Vulnerability System: In-world resident requiring guidance and evacuation

signal resident_rescued(resident_data: Dictionary)
signal resident_reached_safety(resident_data: Dictionary)

enum State { WAITING, FOLLOWING, SAFE }

@export var resident_name: String = "Mrs. Anandi Sharma"
@export var age: int = 72
@export var vulnerability: String = "Severe Osteoarthritis / Reduced Mobility"
@export var initial_dialogue: String = "Oh son! The ground shook so terribly... my knees are aching and I cannot run fast. Please help me get to the open grounds!"
@export var safe_dialogue: String = "Bless you! We are out in the open away from the buildings. You saved my life!"
@export var resident_color: Color = Color("#E57373") # Distinctive clothing color

var current_state: State = State.WAITING
var target_to_follow: Node2D = null
var follow_distance: float = 55.0
var move_speed: float = 190.0
var walk_anim_time: float = 0.0
var player_in_range: bool = false

var interaction_area: Area2D

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	body_shape.shape = circle
	add_child(body_shape)
	
	# Area2D for player proximity interaction
	interaction_area = Area2D.new()
	interaction_area.name = "ResidentArea"
	interaction_area.collision_layer = 8
	interaction_area.collision_mask = 1
	var area_shape := CollisionShape2D.new()
	var area_circle := CircleShape2D.new()
	area_circle.radius = 48.0
	area_shape.shape = area_circle
	interaction_area.add_child(area_shape)
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)
	add_child(interaction_area)

func _on_area_entered(area: Area2D) -> void:
	if area.name == "InteractionDetector" or area.get_parent() is PlayerController:
		player_in_range = true

func _on_area_exited(area: Area2D) -> void:
	if area.name == "InteractionDetector" or area.get_parent() is PlayerController:
		player_in_range = false

func _physics_process(delta: float) -> void:
	match current_state:
		State.WAITING:
			velocity = Vector2.ZERO
		State.FOLLOWING:
			if is_instance_valid(target_to_follow):
				var dist := global_position.distance_to(target_to_follow.global_position)
				if dist > follow_distance:
					var dir := (target_to_follow.global_position - global_position).normalized()
					velocity = dir * move_speed
					walk_anim_time += delta * 8.0
					move_and_slide()
				else:
					velocity = Vector2.ZERO
		State.SAFE:
			velocity = Vector2.ZERO
			
	queue_redraw()

func _draw() -> void:
	var bob := sin(walk_anim_time) * 2.0 if current_state == State.FOLLOWING and velocity.length() > 5.0 else 0.0
	
	# Character base shadow
	draw_circle(Vector2(0, 10), 13.0, Color(0, 0, 0, 0.35))
	
	# Body / Clothing
	draw_circle(Vector2(0, bob), 14.0, resident_color)
	draw_circle(Vector2(0, bob), 10.0, resident_color.darkened(0.25))
	
	# Head & Hair
	draw_circle(Vector2(0, -12 + bob), 7.0, Color("#E8C6A3"))
	draw_arc(Vector2(0, -14 + bob), 5.0, PI, TAU, 8, Color("#303030"), 3.0)
	
	var show_labels := (player_in_range or Campaign.tactical_scan_active) and not Campaign.modal_active
	
	match current_state:
		State.WAITING:
			# Pulsing alert bubble
			var pulse := (sin(walk_anim_time * 0.5 + Time.get_ticks_msec() * 0.005) + 1.0) * 0.5
			draw_circle(Vector2(0, -28), 9.0 + pulse * 2.0, Color(0.9, 0.2, 0.2, 0.9))
			draw_string(ThemeDB.fallback_font, Vector2(-4, -23), "!", HORIZONTAL_ALIGNMENT_CENTER, 8, 14, Color.WHITE)
			
			if show_labels:
				var box_w := 170.0
				var box_h := 34.0
				var box_rect := Rect2(-box_w * 0.5, -68, box_w, box_h)
				draw_rect(box_rect, Color("#13090A", 0.92))
				draw_rect(box_rect, Color("#E57373"), false, 1.2)
				draw_string(ThemeDB.fallback_font, Vector2(-box_w * 0.5, -53), resident_name, HORIZONTAL_ALIGNMENT_CENTER, box_w, 11, Color("#FFCDD2"))
				draw_string(ThemeDB.fallback_font, Vector2(-box_w * 0.5, -39), vulnerability, HORIZONTAL_ALIGNMENT_CENTER, box_w, 9, Color("#E0E0E0"))
		State.FOLLOWING:
			draw_circle(Vector2(0, -26), 6.0, Color(0.2, 0.7, 0.9, 0.9))
			if show_labels:
				var pill_w := 140.0
				var pill_rect := Rect2(-pill_w * 0.5, -46, pill_w, 18)
				draw_rect(pill_rect, Color("#081522", 0.92))
				draw_rect(pill_rect, Color("#4EA8DE"), false, 1.2)
				draw_string(ThemeDB.fallback_font, Vector2(-pill_w * 0.5, -33), resident_name + " (Escorted)", HORIZONTAL_ALIGNMENT_CENTER, pill_w, 10, Color("#80D8FF"))
		State.SAFE:
			draw_circle(Vector2(0, -26), 8.0, Color(0.2, 0.8, 0.3, 0.9))
			draw_line(Vector2(-3, -26), Vector2(-1, -23), Color.WHITE, 2.0)
			draw_line(Vector2(-1, -23), Vector2(4, -29), Color.WHITE, 2.0)
			if show_labels:
				var pill_w := 140.0
				var pill_rect := Rect2(-pill_w * 0.5, -46, pill_w, 18)
				draw_rect(pill_rect, Color("#071910", 0.92))
				draw_rect(pill_rect, Color("#2ECC71"), false, 1.2)
				draw_string(ThemeDB.fallback_font, Vector2(-pill_w * 0.5, -33), resident_name + " (SAFE)", HORIZONTAL_ALIGNMENT_CENTER, pill_w, 10, Color("#69F0AE"))

func assist_resident(leader: Node2D) -> Dictionary:
	if current_state == State.WAITING:
		current_state = State.FOLLOWING
		target_to_follow = leader
		SoundManager.play_escort_link()
		var data := {
			"name": resident_name,
			"age": age,
			"vulnerability": vulnerability,
			"initial_dialogue": initial_dialogue,
			"safe_dialogue": safe_dialogue
		}
		resident_rescued.emit(data)
		return data
	return {}

func mark_safe() -> void:
	if current_state == State.FOLLOWING:
		current_state = State.SAFE
		target_to_follow = null
		SoundManager.play_sfx("success")
		resident_reached_safety.emit({
			"name": resident_name,
			"age": age,
			"safe_dialogue": safe_dialogue
		})

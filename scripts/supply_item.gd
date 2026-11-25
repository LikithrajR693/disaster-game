extends Area2D
class_name SupplyItem

# In-world collectable emergency supply kit with NDMA preparedness purpose

signal supply_collected(item_data: Dictionary)

@export var item_id: String = "kit_firstaid"
@export var item_name: String = "NDMA Trauma First Aid Kit"
@export var item_type: String = "MEDICAL" # MEDICAL, LIGHT, COMMS, RESCUE, DOCS, FIRE
@export var ndma_purpose: String = "Essential for field triage, stopping severe bleeding, and bandaging injuries when emergency medical services are overwhelmed."
@export var is_essential: bool = true

var float_offset: float = 0.0
var anim_time: float = 0.0
var player_in_range: bool = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 42.0
	shape.shape = circle
	add_child(shape)
	
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if area.name == "InteractionDetector" or area.get_parent() is PlayerController:
		player_in_range = true

func _on_area_exited(area: Area2D) -> void:
	if area.name == "InteractionDetector" or area.get_parent() is PlayerController:
		player_in_range = false

func _process(delta: float) -> void:
	anim_time += delta * 2.8
	float_offset = sin(anim_time) * 3.5
	queue_redraw()

func _draw() -> void:
	var pos := Vector2(0, float_offset)
	
	# Floor contact shadow & subtle tactical ring
	draw_circle(Vector2(0, 10), 18.0, Color(0, 0, 0, 0.35))
	draw_arc(pos, 22.0, 0, TAU, 24, Color(0.2, 0.7, 0.9, 0.3), 1.5)
	
	# Circular dark-navy badge base
	draw_circle(pos, 19.0, Color("#091726", 0.95))
	draw_circle(pos, 16.5, Color("#F4B860") if is_essential else Color("#5A738E"))
	draw_circle(pos, 14.0, Color("#0D2235"))
	
	# Custom vector icons
	match item_type:
		"MEDICAL":
			# First aid cross
			draw_rect(Rect2(pos + Vector2(-7, -2.5), Vector2(14, 5)), Color("#E53935"))
			draw_rect(Rect2(pos + Vector2(-2.5, -7), Vector2(5, 14)), Color("#E53935"))
		"LIGHT":
			# Flashlight head + beam
			draw_rect(Rect2(pos + Vector2(-3, 0), Vector2(6, 8)), Color("#FFD54F"))
			draw_circle(pos + Vector2(0, -3), 4.5, Color.WHITE)
			var pts: PackedVector2Array = [
				pos + Vector2(-2, -5), pos + Vector2(-7, -11),
				pos + Vector2(7, -11), pos + Vector2(2, -5)
			]
			draw_colored_polygon(pts, Color(1, 1, 0.7, 0.45))
		"COMMS":
			# Radio antenna & body
			draw_line(pos + Vector2(0, -10), pos + Vector2(0, -1), Color.WHITE, 2.0)
			draw_arc(pos + Vector2(0, -10), 4.5, -PI * 0.75, -PI * 0.25, 4, Color("#4FC3F7"), 2.0)
			draw_rect(Rect2(pos + Vector2(-5, -1), Vector2(10, 9)), Color("#0288D1"))
		"DOCS":
			# Sealed document pouch
			draw_rect(Rect2(pos + Vector2(-6, -5), Vector2(12, 10)), Color("#ECEFF1"))
			draw_line(pos + Vector2(-6, -5), pos + Vector2(0, 0), Color("#78909C"), 1.5)
			draw_line(pos + Vector2(6, -5), pos + Vector2(0, 0), Color("#78909C"), 1.5)
		"FIRE":
			# Red fire extinguisher
			draw_rect(Rect2(pos + Vector2(-3.5, -6), Vector2(7, 13)), Color("#E53935"))
			draw_rect(Rect2(pos + Vector2(-2, -9), Vector2(4, 3)), Color.WHITE)
		_:
			draw_rect(Rect2(pos + Vector2(-5, -5), Vector2(10, 10)), Color("#00ACC1"))
			
	# Proximity or Tactical Scan label (suppressed when modal is open)
	var show_labels := (player_in_range or Campaign.tactical_scan_active) and not Campaign.modal_active
	if show_labels:
		var pill_w := 140.0
		var pill_rect := Rect2(-pill_w * 0.5, pos.y - 32, pill_w, 18)
		draw_rect(pill_rect, Color("#081522", 0.92))
		draw_rect(pill_rect, Color("#4EA8DE"), false, 1.2)
		draw_string(ThemeDB.fallback_font, Vector2(-pill_w * 0.5, pos.y - 19), item_name, HORIZONTAL_ALIGNMENT_CENTER, pill_w, 10, Color("#F4B860"))

func collect() -> Dictionary:
	SoundManager.play_pickup()
	var data := {
		"id": item_id,
		"name": item_name,
		"type": item_type,
		"purpose": ndma_purpose,
		"essential": is_essential
	}
	supply_collected.emit(data)
	queue_free()
	return data

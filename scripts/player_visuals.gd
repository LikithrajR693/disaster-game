extends Node2D
class_name PlayerVisuals

# Detailed, multi-layered procedural vector CanvasItem character representing an
# NDRF / Emergency First Responder:
# - High-visibility orange / navy rescue uniform shoulders & torso
# - Tactical helmet with glowing headlamp unit
# - Tactical backpack rig & radio antenna
# - Volumetric soft layered flashlight cone smoothly rotating toward movement direction
# - Walk cycle shoulder-sway and bobbing
# - Cyan/amber ground tactical ring showing interaction reach

var facing_direction: Vector2 = Vector2.DOWN
var smooth_facing_angle: float = 0.0
var walk_anim_time: float = 0.0
var is_moving: bool = false
var interaction_radius: float = 65.0
var escorted_residents: Array[Node2D] = []
var headlamp: PointLight2D

func _ready() -> void:
	headlamp = PointLight2D.new()
	headlamp.texture = _make_headlamp_texture()
	headlamp.color = Color(1.0, 0.91, 0.67)
	headlamp.energy = 1.15
	headlamp.texture_scale = 2.5
	headlamp.scale = Vector2(1.75, 0.72)
	headlamp.shadow_enabled = false
	add_child(headlamp)

func _process(delta: float) -> void:
	if facing_direction.length_squared() > 0.01:
		var target_angle := facing_direction.angle()
		smooth_facing_angle = lerp_angle(smooth_facing_angle, target_angle, 1.0 - exp(-14.0 * delta))
	headlamp.position = Vector2(cos(smooth_facing_angle), sin(smooth_facing_angle)) * 52.0
	headlamp.rotation = smooth_facing_angle
	queue_redraw()

func _make_headlamp_texture() -> Texture2D:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in range(96):
		for x in range(96):
			var distance := Vector2(x - 47.5, y - 47.5).length() / 48.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(maxf(0.0, 1.0 - distance), 2.0)))
	return ImageTexture.create_from_image(image)

func _draw() -> void:
	# 1. Escort Guidance Tethers: Clean dashed glowing cyan line connecting to each escorted civilian
	for res in escorted_residents:
		if is_instance_valid(res):
			var local_target := to_local(res.global_position)
			_draw_dashed_line(Vector2.ZERO, local_target, Color(0.2, 0.85, 0.95, 0.65), 2.5, 8.0, 6.0)

	# 2. Ground Tactical Ring (Interaction reach indicator)
	var ring_pulse := (sin(walk_anim_time * 2.0) + 1.0) * 0.5
	var ring_radius := GameConfig.PLAYER_INTERACTION_RADIUS
	var ring_color := Color(0.2, 0.85, 0.95, 0.22 + ring_pulse * 0.12) if not Campaign.tactical_scan_active else Color(0.95, 0.72, 0.3, 0.35 + ring_pulse * 0.15)
	draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 36, ring_color, 1.5)
	# 4 compass crosshair ticks on tactical ring
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var tick_dir := Vector2(cos(a), sin(a))
		draw_line(tick_dir * (ring_radius - 4), tick_dir * (ring_radius + 4), ring_color, 1.5)

	# 3. Dynamic Volumetric Flashlight Cone (Layered soft-edged warm-white beam)
	var cone_len := 155.0
	var cone_angle := deg_to_rad(34.0)
	var p_left := Vector2(cos(smooth_facing_angle - cone_angle), sin(smooth_facing_angle - cone_angle)) * cone_len
	var p_right := Vector2(cos(smooth_facing_angle + cone_angle), sin(smooth_facing_angle + cone_angle)) * cone_len
	
	# Layer 1: Wide soft ambient falloff
	var wide_angle := deg_to_rad(45.0)
	var p_w_left := Vector2(cos(smooth_facing_angle - wide_angle), sin(smooth_facing_angle - wide_angle)) * (cone_len * 0.75)
	var p_w_right := Vector2(cos(smooth_facing_angle + wide_angle), sin(smooth_facing_angle + wide_angle)) * (cone_len * 0.75)
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, p_w_left, p_w_right]), Color(1.0, 0.95, 0.75, 0.06))
	
	# Layer 2: Main beam cone
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, p_left, p_right]), Color(1.0, 0.96, 0.82, 0.15))
	
	# Layer 3: Concentrated core beam
	var core_angle := deg_to_rad(16.0)
	var p_c_left := Vector2(cos(smooth_facing_angle - core_angle), sin(smooth_facing_angle - core_angle)) * (cone_len * 1.1)
	var p_c_right := Vector2(cos(smooth_facing_angle + core_angle), sin(smooth_facing_angle + core_angle)) * (cone_len * 1.1)
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, p_c_left, p_c_right]), Color(1.0, 1.0, 0.9, 0.22))
	draw_arc(Vector2.ZERO, cone_len, smooth_facing_angle - cone_angle, smooth_facing_angle + cone_angle, 16, Color(1.0, 0.95, 0.8, 0.28), 1.5)

	# 4. Drop Shadow beneath responder
	draw_circle(Vector2(0, 11), 16.0, Color(0, 0, 0, 0.42))

	# 5. Character Tactical Model (Oriented toward smooth_facing_angle)
	# Shoulder sway and bob
	var bob := sin(walk_anim_time) * 2.0 if is_moving else 0.0
	var sway := sin(walk_anim_time) * 0.12 if is_moving else 0.0

	# Transform for rotated body rendering
	var stretch := Vector2.ONE
	if is_moving:
		var stride := absf(cos(walk_anim_time))
		stretch = Vector2(1.0 + stride * 0.025, 1.0 - stride * 0.035)
	var xform := Transform2D(smooth_facing_angle + sway, stretch, 0.0, Vector2(0, bob))

	# Tactical backpack rig (behind torso)
	var bp_rect := Rect2(-10, -7, 7, 14)
	_draw_xformed_rect(xform, bp_rect, Color("#101C26"), Color("#203548"))
	# Radio antenna on backpack
	var ant_base := xform * Vector2(-9, -6)
	var ant_tip := xform * Vector2(-15, -16)
	draw_line(ant_base, ant_tip, Color("#78909C"), 2.0)
	draw_circle(ant_tip, 1.5, Color("#FF5252"))

	# NDRF Tactical Uniform: Broad rescue orange shoulders & deep navy combat pants
	# Left & Right Shoulders
	_draw_xformed_circle(xform, Vector2(2, -11), 7.5, Color("#E65100")) # High-vis Rescue Orange
	_draw_xformed_circle(xform, Vector2(2, 11), 7.5, Color("#E65100"))
	# Silver reflective shoulder bands
	_draw_xformed_line(xform, Vector2(0, -14), Vector2(4, -8), Color("#ECEFF1"), 2.5)
	_draw_xformed_line(xform, Vector2(0, 14), Vector2(4, 8), Color("#ECEFF1"), 2.5)

	# Main Torso (Deep Navy tactical vest with hi-vis orange cross-harness)
	_draw_xformed_circle(xform, Vector2(1, 0), 13.0, Color("#0D1E2D"))
	_draw_xformed_circle(xform, Vector2(1, 0), 10.5, Color("#E65100")) # Orange chest plate
	_draw_xformed_line(xform, Vector2(-4, -6), Vector2(6, 6), Color("#FFFFFF"), 2.0)
	_draw_xformed_line(xform, Vector2(-4, 6), Vector2(6, -6), Color("#FFFFFF"), 2.0)

	# Tactical Helmet (White/amber high-impact composite)
	_draw_xformed_circle(xform, Vector2(2, 0), 8.5, Color("#ECEFF1"))
	_draw_xformed_circle(xform, Vector2(2, 0), 7.0, Color("#F4B860"))
	# Helmet ridge
	_draw_xformed_line(xform, Vector2(-4, 0), Vector2(8, 0), Color("#D35400"), 2.0)

	# Glowing LED Headlamp Unit (front of helmet)
	var lamp_pos := xform * Vector2(9, 0)
	draw_circle(lamp_pos, 3.5, Color(1, 1, 1, 0.95))
	draw_circle(lamp_pos, 6.0, Color(1, 0.95, 0.7, 0.45))

func _draw_xformed_circle(xform: Transform2D, center: Vector2, radius: float, color: Color) -> void:
	draw_circle(xform * center, radius, color)

func _draw_xformed_line(xform: Transform2D, p1: Vector2, p2: Vector2, color: Color, width: float) -> void:
	draw_line(xform * p1, xform * p2, color, width)

func _draw_xformed_rect(xform: Transform2D, rect: Rect2, bg: Color, border: Color) -> void:
	var p1 := xform * rect.position
	var p2 := xform * Vector2(rect.position.x + rect.size.x, rect.position.y)
	var p3 := xform * (rect.position + rect.size)
	var p4 := xform * Vector2(rect.position.x, rect.position.y + rect.size.y)
	var pts := PackedVector2Array([p1, p2, p3, p4])
	draw_colored_polygon(pts, bg)
	draw_line(p1, p2, border, 1.5)
	draw_line(p2, p3, border, 1.5)
	draw_line(p3, p4, border, 1.5)
	draw_line(p4, p1, border, 1.5)

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float, gap_len: float) -> void:
	var diff := to - from
	var dist := diff.length()
	if dist < 1.0:
		return
	var dir := diff / dist
	var curr := 0.0
	while curr < dist:
		var end_d: float = minf(curr + dash_len, dist)
		draw_line(from + dir * curr, from + dir * end_d, color, width)
		curr += dash_len + gap_len

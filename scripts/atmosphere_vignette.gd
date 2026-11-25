extends CanvasLayer
class_name AtmosphereVignette

var _material: ShaderMaterial
var _time: float = 0.0
var _mission_id: int = 0
var _in_hazard: bool = false
var _near_flood: bool = false
var _trauma: float = 0.0

func setup(mission: int) -> void:
	_mission_id = mission
	layer = 5
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec3 tint : source_color = vec3(0.10, 0.14, 0.20);
uniform float strength = 0.22;
void fragment() {
	vec2 p = abs(UV - vec2(0.5)) * 2.0;
	float edge = max(p.x, p.y);
	float vignette = smoothstep(0.30, 1.0, edge);
	COLOR = vec4(tint, vignette * strength);
}
"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	shade.material = _material
	add_child(shade)

func set_world_context(player_position: Vector2, hazards: Array[Hazard], tremor: float) -> void:
	_in_hazard = false
	_near_flood = false
	for hazard in hazards:
		if not is_instance_valid(hazard):
			continue
		var distance := player_position.distance_to(hazard.global_position)
		if distance < 90.0 and hazard.hazard_type in ["ELECTRICAL", "FIRE", "STRUCTURAL"]:
			_in_hazard = true
		if distance < 360.0 and hazard.hazard_type == "WATER":
			_near_flood = true
	_trauma = maxf(_trauma, tremor)

func _process(delta: float) -> void:
	_time += delta
	_trauma = maxf(0.0, _trauma - delta * 0.32)
	var tint := Color(0.10, 0.14, 0.20)
	var strength := 0.22
	if _mission_id == 0 and _trauma > 0.0:
		tint = Color(0.72, 0.38, 0.12)
		strength += (0.10 + 0.08 * (0.5 + 0.5 * sin(_time * 9.0))) * _trauma
	elif _near_flood:
		tint = Color(0.18, 0.46, 0.62)
		strength += 0.12
	if _in_hazard:
		tint = Color(0.68, 0.08, 0.10)
		strength += 0.10 + 0.08 * (0.5 + 0.5 * sin(_time * 5.0))
	_material.set_shader_parameter("tint", tint)
	_material.set_shader_parameter("strength", strength)

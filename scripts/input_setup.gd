extends Node

func _ready() -> void:
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_button("interact", JOY_BUTTON_A)
	_add_button("open_inventory", JOY_BUTTON_X)
	_add_button("open_map", JOY_BUTTON_Y)
	_add_button("open_objectives", JOY_BUTTON_BACK)
	_add_button("pause", JOY_BUTTON_START)
	_add_button("pause", JOY_BUTTON_B)

func _add_axis(action: StringName, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)

func _add_button(action: StringName, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

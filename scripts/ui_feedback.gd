class_name UIFeedback
extends RefCounted

static func attach(
	button: Button,
	accent: Color = Color("#E8C66A"),
	play_click: bool = true
) -> void:
	if button.has_meta("ui_feedback_attached"):
		return
	button.set_meta("ui_feedback_attached", true)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_focus_color", accent)

	var state: Dictionary = {
		"tween": null,
		"hovered": false,
		"focused": false
	}
	button.mouse_entered.connect(func():
		state["hovered"] = true
		_animate(button, state, GameConfig.UI_HOVER_SCALE, GameConfig.UI_HOVER_DURATION)
		SoundManager.play_ui_hover()
	)
	button.mouse_exited.connect(func():
		state["hovered"] = false
		_animate(button, state, _resting_scale(state), GameConfig.UI_HOVER_DURATION)
	)
	button.focus_entered.connect(func():
		state["focused"] = true
		_animate(button, state, GameConfig.UI_HOVER_SCALE, GameConfig.UI_HOVER_DURATION)
		SoundManager.play_ui_hover()
	)
	button.focus_exited.connect(func():
		state["focused"] = false
		_animate(button, state, _resting_scale(state), GameConfig.UI_HOVER_DURATION)
	)
	button.button_down.connect(func():
		_animate(button, state, GameConfig.UI_PRESS_SCALE, GameConfig.UI_PRESS_DURATION)
	)
	button.button_up.connect(func():
		var target_scale := GameConfig.UI_HOVER_SCALE if state["hovered"] or state["focused"] else 1.0
		_animate(button, state, target_scale, GameConfig.UI_HOVER_DURATION)
	)
	if play_click:
		button.pressed.connect(SoundManager.play_ui_click)

static func _animate(
	button: Button,
	state: Dictionary,
	target_scale: float,
	duration: float
) -> void:
	if not is_instance_valid(button):
		return
	if state["tween"] is Tween:
		var previous: Tween = state["tween"]
		if previous.is_running():
			previous.kill()
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE * target_scale, duration)
	state["tween"] = tween

static func _resting_scale(state: Dictionary) -> float:
	return GameConfig.UI_HOVER_SCALE if state["hovered"] or state["focused"] else 1.0

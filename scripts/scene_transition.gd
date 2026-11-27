extends Node

var _transitioning: bool = false
var _overlay: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)

	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color.BLACK
	_overlay.color.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)

func change_scene(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	FeedbackManager.cancel_hit_stop()
	get_tree().paused = true
	await _fade_to(1.0, GameConfig.SCENE_TRANSITION_OUT_DURATION)
	var result := get_tree().change_scene_to_file(path)
	if result != OK:
		push_error("Scene transition failed for '%s': %s" % [path, error_string(result)])
		get_tree().paused = false
		await _fade_to(0.0, GameConfig.SCENE_TRANSITION_IN_DURATION)
		_transitioning = false
		return

	await get_tree().scene_changed
	get_tree().paused = false
	await _fade_to(0.0, GameConfig.SCENE_TRANSITION_IN_DURATION)
	_transitioning = false

func reload_scene() -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene) or scene.scene_file_path.is_empty():
		push_error("Cannot reload the current scene because it has no scene file path.")
		return
	change_scene(scene.scene_file_path)

func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_overlay, "color:a", alpha, duration)
	await tween.finished

class_name SceneRouterNode
extends Node
## Switches screens with a very short fade and routes the Android back button
## to the current screen's `go_back()` (quits if the screen has none).

const MENU: String = "res://scenes/menu/main_menu.tscn"
const GAME: String = "res://scenes/game/game.tscn"
const FADE_TIME: float = 0.1
## One back press can arrive as more than one request (seen on the phone:
## the pause menu opened and closed again at once); later ones are ignored.
const BACK_DEBOUNCE_MS: int = 300

var _fade: ColorRect
var _busy: bool = false
var _last_back_ms: int = -100000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func is_busy() -> bool:
	return _busy


func go_to(path: String, fade: bool = true) -> void:
	if _busy:
		return
	_busy = true
	# Swallow taps while the screen changes.
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if fade:
		await _fade_to(1.0)
	get_tree().paused = false
	var err: Error = get_tree().change_scene_to_file(path)
	if err == OK:
		await get_tree().scene_changed
	else:
		push_error("SceneRouter: cannot open %s (%s)" % [path, error_string(err)])
	if fade:
		await _fade_to(0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade_to(alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or _busy:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_back_ms < BACK_DEBOUNCE_MS:
		return
	_last_back_ms = now
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("go_back"):
		scene.call("go_back")
	else:
		get_tree().quit()

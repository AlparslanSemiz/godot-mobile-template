class_name TapButton
extends Button
## Button that fires on finger-down (no wait for release), gives a small
## squash, a click sound and a haptic tick. Use it for every menu button.

const PRESS_SCALE: Vector2 = Vector2(0.94, 0.94)

var _tween: Tween


func _ready() -> void:
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	focus_mode = Control.FOCUS_NONE
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	resized.connect(_center_pivot)
	_center_pivot()


## Godot 4.7 buttons handle touches themselves, and with emulate_mouse_from_touch
## the same touch also arrives as an emulated mouse click. In ACTION_MODE_BUTTON_PRESS
## both fire `pressed`, so one tap would act twice. Swallow the emulated copy;
## real mouse clicks on desktop are not emulated and still work.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		accept_event()


func _center_pivot() -> void:
	pivot_offset = size / 2.0


func _on_down() -> void:
	AudioService.play_sfx(AudioService.click_sound)
	SettingsService.vibrate(15)
	_animate_scale(PRESS_SCALE, 0.05)


func _on_up() -> void:
	_animate_scale(Vector2.ONE, 0.12)


func _animate_scale(target: Vector2, duration: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", target, duration)

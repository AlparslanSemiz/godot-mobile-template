class_name PauseMenu
extends Control
## In-game pause menu: Resume, Restart, Settings, Main menu. "Main menu" asks
## "Leave this run?" in the card itself. Runs while the tree is paused.

signal resume_pressed
signal restart_pressed
signal leave_confirmed

@onready var _card: Control = %Card
@onready var _buttons: VBoxContainer = %Buttons
@onready var _confirm: VBoxContainer = %Confirm
@onready var _resume: TapButton = %ResumeButton
@onready var _restart: TapButton = %RestartButton
@onready var _settings_button: TapButton = %SettingsButton
@onready var _menu: TapButton = %MenuButton
@onready var _leave: TapButton = %LeaveButton
@onready var _stay: TapButton = %StayButton
@onready var _settings: SettingsPanel = %SettingsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_resume.pressed.connect(resume_pressed.emit)
	_restart.pressed.connect(restart_pressed.emit)
	_settings_button.pressed.connect(_settings.open)
	_menu.pressed.connect(_ask_leave.bind(true))
	_stay.pressed.connect(_ask_leave.bind(false))
	_leave.pressed.connect(leave_confirmed.emit)
	# The settings panel has its own dim: hide the pause card under it, so
	# its title does not show through (Gemini review).
	_settings.visibility_changed.connect(func() -> void: _card.visible = not _settings.visible)


func open() -> void:
	_ask_leave(false)
	_settings.close()
	show()
	modulate.a = 0.0
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.92, 0.92)
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.2)


func close() -> void:
	_settings.close()
	hide()


## Android back while the menu is open: closes the innermost layer first
## (settings, then the leave question); on the plain menu it resumes.
func back() -> void:
	if _settings.visible:
		_settings.close()
	elif _confirm.visible:
		_ask_leave(false)
	else:
		resume_pressed.emit()


func is_confirming() -> bool:
	return _confirm.visible


func settings_open() -> bool:
	return _settings.visible


func menu_button() -> TapButton:
	return _menu


func settings_button() -> TapButton:
	return _settings_button


func restart_button() -> TapButton:
	return _restart


func _ask_leave(asking: bool) -> void:
	_confirm.visible = asking
	_buttons.visible = not asking

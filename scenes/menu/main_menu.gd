extends Control
## Main menu: Play and Settings.

@onready var _title: Label = %Title
@onready var _best: Label = %Best
@onready var _play: TapButton = %PlayButton
@onready var _settings_button: TapButton = %SettingsButton
@onready var _settings: SettingsPanel = %SettingsPanel
@onready var _version: Label = %Version


func _ready() -> void:
	_title.text = GameConfig.app_name()
	_version.text = "v" + GameConfig.version_name()
	_show_best()
	# Settings "Reset best scores" saves: show the new value.
	SaveService.saved.connect(_show_best)
	_play.pressed.connect(_on_play)
	_settings_button.pressed.connect(_settings.open)


func _show_best() -> void:
	_best.text = "Best: %d" % SaveService.get_int("best_score")


func _on_play() -> void:
	SceneRouter.go_to(SceneRouter.GAME)


## Android back button: close settings first, otherwise leave the app.
func go_back() -> void:
	if _settings.visible:
		_settings.close()
	else:
		get_tree().quit()

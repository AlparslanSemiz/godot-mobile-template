class_name SettingsServiceNode
extends Node
## Player settings: sound effects, music, haptics (vibration) and tilt
## steering. Stored inside the save file.

signal changed

## Overridable in tests; defaults to the SaveService autoload.
var save: SaveServiceNode


func _ready() -> void:
	if save == null:
		save = SaveService


func is_sound_enabled() -> bool:
	return save.get_setting("sound")


func set_sound_enabled(enabled: bool) -> void:
	_store("sound", enabled)


## Music has its own switch ("sound" is the sound effects).
func is_music_enabled() -> bool:
	return save.get_setting("music")


func set_music_enabled(enabled: bool) -> void:
	_store("music", enabled)


func is_vibration_enabled() -> bool:
	return save.get_setting("vibration")


func set_vibration_enabled(enabled: bool) -> void:
	_store("vibration", enabled)


## Links: steer the falling chain by tilting the phone (off unless chosen).
func is_tilt_enabled() -> bool:
	var settings: Dictionary = save.data.get("settings", {})
	return bool(settings.get("tilt", false))


func set_tilt_enabled(enabled: bool) -> void:
	if is_tilt_enabled() == enabled:
		return
	save.set_setting("tilt", enabled)
	save.save()
	changed.emit()


## Links metals color set ("A".."D", "" = the tuning default).
func links_metals() -> String:
	return str(save.data.get("links_metals", ""))


func set_links_metals(metals_set: String) -> void:
	if links_metals() == metals_set:
		return
	save.data["links_metals"] = metals_set
	save.save()
	changed.emit()


## Links chain size ("S".."XL", "" = the tuning default). Applies from the
## next game.
func links_size() -> String:
	return str(save.data.get("links_size", ""))


func set_links_size(size: String) -> void:
	if links_size() == size:
		return
	save.data["links_size"] = size
	save.save()
	changed.emit()


## Short haptic tick. Does nothing when vibration is off or on desktop.
func vibrate(duration_ms: int = 20) -> void:
	if is_vibration_enabled():
		Input.vibrate_handheld(duration_ms)


func _store(key: String, value: bool) -> void:
	if save.get_setting(key) == value:
		return
	save.set_setting(key, value)
	save.save()
	changed.emit()

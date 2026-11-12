class_name SaveServiceNode
extends Node
## Persists game data as JSON in user://save.json.
##
## The file always carries a "version" field. When the layout changes, bump
## SAVE_VERSION and add a step to _migrate(). Writes go to a temp file first
## and are then renamed, so a killed app never leaves a half-written save.

signal saved

const SAVE_VERSION: int = 1
const DEFAULT_PATH: String = "user://save.json"

var path: String = DEFAULT_PATH
var data: Dictionary = {}


func _ready() -> void:
	load_data()


static func defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"best_score": 0,
		"runs": 0,
		"ads_removed": false,
		"settings": {"sound": true, "vibration": true},
	}


func load_data() -> void:
	data = defaults()
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	var err: Error = json.parse(FileAccess.get_file_as_string(path))
	if err != OK or json.data is not Dictionary:
		# Keep the broken file for debugging instead of silently overwriting it.
		var backup: String = path.get_basename() + ".corrupt.json"
		DirAccess.rename_absolute(path, backup)
		push_warning("SaveService: %s was unreadable (line %d: %s), moved to %s and reset."
				% [path, json.get_error_line(), json.get_error_message(), backup])
		return
	data = _migrate(json.data as Dictionary)


func save() -> bool:
	data["version"] = SAVE_VERSION
	var tmp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot write %s (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err: Error = DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		push_error("SaveService: cannot replace %s (%s)" % [path, error_string(err)])
		return false
	saved.emit()
	return true


func get_int(key: String) -> int:
	return int(data.get(key, 0))


func set_int(key: String, value: int) -> void:
	data[key] = value


## Settings "Reset best scores": every best score (the overall one and the
## per-mode ones, keys starting with "best") back to 0, then saved.
func reset_best_scores() -> void:
	for key: Variant in data.keys():
		if str(key).begins_with("best"):
			data[key] = 0
	save()


func get_bool(key: String) -> bool:
	return bool(data.get(key, false))


func set_bool(key: String, value: bool) -> void:
	data[key] = value


func get_setting(key: String) -> bool:
	var settings: Dictionary = data.get("settings", {})
	return bool(settings.get(key, true))


func set_setting(key: String, value: bool) -> void:
	var settings: Dictionary = data.get("settings", {})
	settings[key] = value
	data["settings"] = settings


## Brings any older save up to SAVE_VERSION. Unknown keys are kept.
static func _migrate(loaded: Dictionary) -> Dictionary:
	var result: Dictionary = defaults()
	# Version 0 = saves written before the version field existed.
	var from_version: int = int(loaded.get("version", 0))
	for key: String in loaded:
		if key == "settings" and loaded[key] is Dictionary:
			var merged: Dictionary = result["settings"]
			merged.merge(loaded[key] as Dictionary, true)
		else:
			result[key] = loaded[key]
	# JSON stores every number as float; restore ints.
	result["best_score"] = int(result["best_score"])
	result["runs"] = int(result["runs"])
	if from_version < 1:
		pass  # Add real migration steps here, e.g. renaming a key.
	result["version"] = SAVE_VERSION
	return result

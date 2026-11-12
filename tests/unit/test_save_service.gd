extends GutTest

const SaveScript: GDScript = preload("res://autoload/save_service.gd")
const PATH: String = "user://test_save.json"

var save: SaveServiceNode


func before_each() -> void:
	_delete(PATH)
	_delete("user://test_save.corrupt.json")
	save = SaveScript.new()
	save.path = PATH
	save.load_data()


func after_each() -> void:
	save.free()
	_delete(PATH)
	_delete("user://test_save.corrupt.json")


func test_starts_from_defaults_without_file() -> void:
	assert_eq(save.get_int("best_score"), 0)
	assert_true(save.get_setting("sound"))
	assert_eq(int(save.data["version"]), SaveServiceNode.SAVE_VERSION)


func test_round_trip_keeps_values_and_types() -> void:
	save.set_int("best_score", 17)
	save.set_setting("vibration", false)
	assert_true(save.save())
	var other: SaveServiceNode = SaveScript.new()
	other.path = PATH
	other.load_data()
	assert_eq(other.get_int("best_score"), 17)
	assert_typeof(other.data["best_score"], TYPE_INT)
	assert_false(other.get_setting("vibration"))
	assert_true(other.get_setting("sound"))
	other.free()


func test_file_has_version_field() -> void:
	save.save()
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(int(parsed["version"]), SaveServiceNode.SAVE_VERSION)


func test_migrates_save_without_version() -> void:
	_write(PATH, '{"best_score": 5, "settings": {"sound": false}}')
	save.load_data()
	assert_eq(save.get_int("best_score"), 5)
	assert_false(save.get_setting("sound"))
	assert_true(save.get_setting("vibration"), "missing keys get defaults")
	assert_eq(int(save.data["version"]), SaveServiceNode.SAVE_VERSION)


func test_corrupt_file_is_moved_aside_and_reset() -> void:
	_write(PATH, "{not json")
	save.load_data()
	assert_push_warning("unreadable")
	assert_eq(save.get_int("best_score"), 0)
	assert_false(FileAccess.file_exists(PATH))
	assert_true(FileAccess.file_exists("user://test_save.corrupt.json"))


func test_save_leaves_no_temp_file() -> void:
	save.save()
	assert_false(FileAccess.file_exists(PATH + ".tmp"))


func _write(file_path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _delete(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)

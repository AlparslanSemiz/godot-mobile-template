extends GutTest
## In-game pause (feedback round 1): the pause button and Android back open
## the pause menu, back again resumes, "Main menu" asks first, and returning
## from the background shows the menu instead of the running game.

var _game: Node


func before_each() -> void:
	_game = (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	add_child_autofree(_game)


func after_each() -> void:
	get_tree().paused = false


func _pause_menu() -> PauseMenu:
	return _game.get_node("%PauseMenu") as PauseMenu


func test_back_opens_the_pause_menu_and_back_again_resumes() -> void:
	assert_false(_pause_menu().visible, "closed while playing")
	_game.call("go_back")
	assert_true(_pause_menu().visible, "back opens the pause menu")
	assert_true(get_tree().paused, "and freezes the run")
	_game.call("go_back")
	assert_false(_pause_menu().visible, "back again closes it")
	assert_false(get_tree().paused, "and the run goes on")


func test_main_menu_asks_first_and_back_cancels_the_question() -> void:
	_game.call("pause")
	_pause_menu().menu_button().pressed.emit()
	assert_true(_pause_menu().is_confirming(), "\"Leave this run?\" in the menu itself")
	assert_true(_pause_menu().visible, "the run is not left yet")
	_game.call("go_back")
	assert_false(_pause_menu().is_confirming(), "back cancels the question")
	assert_true(_pause_menu().visible, "and keeps the pause menu")


func test_settings_open_from_the_pause_menu_and_back_closes_them_first() -> void:
	_game.call("pause")
	_pause_menu().settings_button().pressed.emit()
	assert_true(_pause_menu().settings_open(), "settings open over the pause menu")
	_game.call("go_back")
	assert_false(_pause_menu().settings_open(), "back closes the settings")
	assert_true(_pause_menu().visible, "and returns to the pause menu")


func test_returning_from_the_background_shows_the_pause_menu() -> void:
	_game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(get_tree().paused, "frozen in the background")
	_game.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(_pause_menu().visible, "back in front: the pause menu, not the running game")
	assert_true(get_tree().paused)


func test_restart_starts_a_new_run_and_resumes() -> void:
	var before: Node = _game.get_node("World").get_child(0)
	_game.call("pause")
	_pause_menu().restart_button().pressed.emit()
	assert_false(_pause_menu().visible)
	assert_false(get_tree().paused)
	assert_ne(_game.get_node("World").get_child(-1), before, "a new run")


## Settings "Reset best scores" asks in the panel itself (no system dialog):
## the first press only asks, the second resets.
func test_reset_best_scores_asks_in_the_panel_first() -> void:
	var kept: Dictionary = SaveService.data.duplicate(true)
	SaveService.set_int("best_links", 500)
	var panel: SettingsPanel = _pause_menu().get_node("%SettingsPanel") as SettingsPanel
	panel.open()
	panel.reset_button().pressed.emit()
	assert_eq(SaveService.get_int("best_links"), 500, "the first press only asks")
	assert_string_contains(panel.reset_button().text, "?", "and says so on the button")
	panel.reset_button().pressed.emit()
	assert_eq(SaveService.get_int("best_links"), 0, "the second press resets")
	SaveService.data = kept
	SaveService.save()


## Reviews (fresh Claude, Codex): during the death beat before the game-over
## card, back or a focus change opened the pause menu over a finished run.
func test_no_pause_menu_once_the_run_has_ended() -> void:
	var run: Node = _game.get_node("World").get_child(-1)
	run.emit_signal("finished", 0)
	_game.call("go_back")
	assert_false(_pause_menu().visible, "back after the run ended does not pause")
	_game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_game.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(_pause_menu().visible, "nor does coming back from the background")
	assert_false(get_tree().paused)
	assert_false((_game.get_node("%PauseButton") as Control).visible, "the pause button is gone")


## Reviews: a finger down when the game pauses never sends its release to
## the paused game, so a drag, grab or pour stayed active after Resume.
## Pausing cancels the touch.
func test_pausing_cancels_a_touch_in_progress() -> void:
	var run: Node = _game.get_node("World").get_child(-1)
	if not run.has_method("cancel_input"):
		pass_test("this game has no cancel_input hook (optional)")
		return
	run.set("_touch_on", true)
	run.set("_drag_slot", -1)
	_game.call("pause")
	assert_false(run.get("_touch_on"), "the touch is cancelled")
	assert_eq(run.get("_drag_slot"), -1)

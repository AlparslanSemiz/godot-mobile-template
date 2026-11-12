extends Node
## Hosts the game scene from game.cfg, records the result, shows an
## interstitial every N runs, then the game-over screen. During a run, the
## pause button, Android back and coming back from the background open the
## pause menu (the run is frozen while it is open).

## Pause before the game-over screen, so the death reads clearly.
const DEATH_BEAT: float = 0.35

@onready var _world: Node = $World
@onready var _game_over: GameOverScreen = %GameOver
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _pause_button: TapButton = %PauseButton

var _game: Node
var _fixed_seed: int = -1
var _run_index: int = 0
## Set from `finished` until the next run starts (the death beat, an
## interstitial, the game-over card): no pausing then.
var _run_over: bool = false
## Bumped per run, so a finished run's delayed game-over card is dropped if a
## new run started meanwhile.
var _run_gen: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_fixed_seed = int(arg.trim_prefix("--seed="))
	_game_over.retry_pressed.connect(_start_run)
	_game_over.menu_pressed.connect(_to_menu)
	_pause_button.pressed.connect(pause)
	_pause_menu.resume_pressed.connect(resume)
	_pause_menu.restart_pressed.connect(_start_run)
	_pause_menu.leave_confirmed.connect(_to_menu)
	_start_run()


func _start_run() -> void:
	_game_over.close()
	_run_over = false
	_run_gen += 1
	resume()
	if _game != null:
		_world.remove_child(_game)
		_game.queue_free()
	var packed: PackedScene = load(GameConfig.game_scene()) as PackedScene
	if packed == null:
		push_error("Game: game.cfg [game] scene is not a scene: %s" % GameConfig.game_scene())
		_to_menu()
		return
	_game = packed.instantiate()
	_game.connect("finished", _on_finished)
	if _game.has_signal("restarted"):
		_game.connect("restarted", _game_over.close)
	_world.add_child(_game)
	var rng_seed: int = _fixed_seed + _run_index if _fixed_seed >= 0 else randi()
	_run_index += 1
	_game.call("start", rng_seed)
	AnalyticsService.log_event("run_start")


func _on_finished(score: int) -> void:
	_run_over = true
	_pause_button.hide()
	var gen: int = _run_gen
	# A game with several modes can keep one best score per mode.
	var best_key: String = str(_game.call("best_score_key")) if _game.has_method("best_score_key") else "best_score"
	var previous_best: int = SaveService.get_int(best_key)
	var runs: int = SaveService.get_int("runs") + 1
	SaveService.set_int(best_key, maxi(previous_best, score))
	SaveService.set_int("best_score", maxi(SaveService.get_int("best_score"), score))
	SaveService.set_int("runs", runs)
	SaveService.save()
	AnalyticsService.log_event("run_end", {"score": score, "runs": runs})
	await get_tree().create_timer(DEATH_BEAT).timeout
	if gen != _run_gen:
		return
	var every: int = GameConfig.interstitial_every_n_runs()
	if every > 0 and runs % every == 0:
		AdService.show_interstitial()
		await AdService.interstitial_closed
		if gen != _run_gen:
			return
	# Optional: the game styles the card (Chain Drop: visual themes).
	if _game.has_method("style_game_over"):
		_game.call("style_game_over", _game_over)
	_game_over.open(score, maxi(previous_best, score), score > previous_best)
	# Optional: the game adds its own controls to the card (Chain Drop: mode buttons).
	if _game.has_method("game_over_extras"):
		_game.call("game_over_extras", _game_over.extras(), _start_run)
		_game_over.guard_extras()


## Opens the pause menu and freezes the run (not on the game-over card).
func pause() -> void:
	if _run_over or SceneRouter.is_busy():
		return
	_cancel_input()
	get_tree().paused = true
	if not _pause_menu.visible:
		_pause_menu.open()


func resume() -> void:
	_pause_menu.close()
	_pause_button.visible = not _run_over
	get_tree().paused = false
	# Settings may have changed under the pause menu (e.g. best scores reset).
	if _game != null and _game.has_method("refresh_hud"):
		_game.call("refresh_hud")


## A finger that is down when the game pauses would send its release to the
## paused game, which never sees it: the game drops the touch now (optional
## game hook `cancel_input`).
func _cancel_input() -> void:
	if _game != null and _game.has_method("cancel_input"):
		_game.call("cancel_input")


## Android back: on the game-over card, to the menu; during a run, opens the
## pause menu, or (when it is open) closes its innermost layer or resumes.
## It never ends a run by itself.
func go_back() -> void:
	if _game_over.visible:
		_to_menu()
	elif _pause_menu.visible:
		_pause_menu.back()
	else:
		pause()


func _to_menu() -> void:
	SceneRouter.go_to(SceneRouter.MENU)


func _notification(what: int) -> void:
	# Freeze the run in the background; back in front, the pause menu shows
	# instead of the running game.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_input()
		get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _run_over:
			get_tree().paused = false
		else:
			pause()

extends Node
## Scripted play session for `make smoke` and `make capture`.
##
## Added by scenes/boot/boot.gd when the game runs with
## `-- --driver=res://tests/smoke/smoke_driver.gd --seed=N`.
## It taps Play like a finger would, then plays the game for DURATION seconds
## with taps chosen by a simple autopilot plus seeded random noise, retries
## after each death, and quits. Exit code 1 if anything went wrong or if any
## error or warning was logged. Runs are reproducible because the game runs at
## a fixed tick rate and every random choice comes from the seed.

const DURATION: float = 10.0
const MIN_TAP_GAP: float = 0.18
const MENU_WAIT: float = 1.0

var _logger: SmokeLogger
var _rng := RandomNumberGenerator.new()
var _game_time: float = 0.0
var _last_tap: float = -1.0
var _taps: int = 0
var _entered_game: bool = false
var _menu_tapped: bool = false
var _menu_time: float = 0.0
var _aim_offset: float = 120.0
var _done: bool = false


func _init() -> void:
	_logger = SmokeLogger.new()
	OS.add_logger(_logger)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng_seed: int = 1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			rng_seed = int(arg.trim_prefix("--seed="))
	_rng.seed = rng_seed
	# Never touch the real save; start every session from a clean one.
	SaveService.path = "user://smoke_save.json"
	DirAccess.remove_absolute(SaveService.path)
	SaveService.load_data()
	print("smoke: driver ready, seed=%d" % rng_seed)


func _physics_process(delta: float) -> void:
	if _done:
		return
	var scene: Node = get_tree().current_scene
	if scene == null or SceneRouter.is_busy():
		return
	if scene.name == "MainMenu" and not _menu_tapped:
		# Linger a second so captures include a clean menu shot.
		_menu_time += delta
		if _menu_time < MENU_WAIT:
			return
		_menu_tapped = true
		_tap_control(scene.find_child("PlayButton") as Control)
		return
	if scene.name != "Game":
		return
	if not _entered_game:
		_entered_game = true
		print("smoke: entered game scene")
	_game_time += delta
	if _game_time >= DURATION:
		_finish()
		return
	var game_over: GameOverScreen = scene.find_child("GameOver") as GameOverScreen
	if game_over.visible:
		if not game_over.retry_button().disabled and _game_time - _last_tap > 0.3:
			_tap_control(game_over.retry_button())
		return
	var hop: Hop = scene.find_child("Hop", true, false) as Hop
	if hop != null:
		_autopilot(hop)


## Taps when the player falls below an aim point inside the next gap. A hop
## rises ~233 px (JUMP_VELOCITY² / 2·GRAVITY), so aiming 20–215 px below the
## gap center keeps the whole arc inside the gap. The seeded jitter makes the
## autopilot miss now and then, so game over and Retry get exercised too.
func _autopilot(hop: Hop) -> void:
	var state: Dictionary = hop.debug_state()
	if int(state["state"]) == Hop.State.DEAD:
		return
	if int(state["state"]) == Hop.State.READY:
		if _game_time > 0.5:
			_tap_at(get_viewport().get_visible_rect().size / 2.0)
		return
	var target: float = float(state["next_gap_center"]) + _aim_offset
	var falling: bool = float(state["velocity_y"]) > 0.0
	if falling and float(state["player_y"]) > target and _game_time - _last_tap > MIN_TAP_GAP:
		_tap_at(Vector2(get_viewport().get_visible_rect().size.x / 2.0, float(state["player_y"])))
		_aim_offset = _rng.randf_range(10.0, 235.0)


func _tap_control(control: Control) -> void:
	_tap_at(control.get_global_rect().get_center())


## Sends a finger press + release at a point in viewport coordinates.
## Input events are in window pixels, so map through the stretch transform.
func _tap_at(viewport_point: Vector2) -> void:
	var window_point: Vector2 = get_tree().root.get_final_transform() * viewport_point
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = window_point
		touch.pressed = pressed
		Input.parse_input_event(touch)
	_taps += 1
	_last_tap = _game_time


func _finish() -> void:
	_done = true
	var runs: int = SaveService.get_int("runs")
	var problems: PackedStringArray = _logger.problems()
	var ok: bool = _entered_game and _taps >= 10 and problems.is_empty()
	print("smoke: %s — taps=%d, runs finished=%d, errors/warnings=%d" % ["PASS" if ok else "FAIL", _taps, runs, problems.size()])
	for problem: String in problems:
		print("smoke:   ", problem)
	# Let the audio thread release stopped playbacks (real time, not game
	# time), otherwise they are reported as leaked objects at exit.
	AudioService.stop_all()
	OS.delay_msec(250)
	get_tree().quit(0 if ok else 1)


## Counts every error and warning the engine or scripts log.
class SmokeLogger:
	extends Logger

	var _mutex := Mutex.new()
	var _problems: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var kind: String = "WARNING" if error_type == ERROR_TYPE_WARNING else "ERROR"
		_mutex.lock()
		_problems.append("%s: %s (%s at %s:%d)" % [kind, rationale if rationale != "" else code, function, file, line])
		_mutex.unlock()

	func problems() -> PackedStringArray:
		_mutex.lock()
		var copy: PackedStringArray = _problems.duplicate()
		_mutex.unlock()
		return copy

class_name Hop
extends Node2D
## Demo game: tap to hop through the gaps. Ported from the Phase 0 prototype.
##
## Contract with scenes/game/game.gd (every game scene must follow it):
##   start(rng_seed: int)   called once after the scene enters the tree
##   signal finished(score) emitted once when the run ends
##
## All game logic runs in _physics_process at a fixed 120 Hz, so a run is
## exactly reproducible from its seed. Physics interpolation (project
## setting) draws nodes smoothly between ticks at any display refresh rate.

signal finished(score: int)

enum State { READY, PLAYING, DEAD }

const PLAYER_COLOR: Color = Color(1.0, 0.85, 0.2)
const CLOUD_COUNT: int = 4

var state: State = State.READY
var score: int = 0
var velocity_y: float = 0.0

var _rng := RandomNumberGenerator.new()
## Separate stream for cosmetic randomness, so effects never change gameplay.
var _fx_rng := RandomNumberGenerator.new()
var _spawn_timer: float = 0.0
var _ready_time: float = 0.0
var _obstacles: Array[HopObstacle] = []
var _clouds: Array[HopCloud] = []
var _score_tween: Tween

@onready var _player: Node2D = $Player
@onready var _player_body: Node2D = $Player/Body
@onready var _obstacle_root: Node2D = $Obstacles
@onready var _cloud_root: Node2D = $Clouds
@onready var _score_label: Label = %Score
@onready var _hint: Label = %Hint
@onready var _flash: ColorRect = %Flash

var _jump_sound: AudioStreamWAV = Tones.jump()
var _score_sound: AudioStreamWAV = Tones.score()
var _hit_sound: AudioStreamWAV = Tones.hit()


func start(rng_seed: int) -> void:
	_rng.seed = rng_seed
	_fx_rng.seed = hash(rng_seed)
	var screen: Vector2 = _screen()
	_player.position = Vector2(screen.x / 3.0, screen.y / 2.0)
	_player.reset_physics_interpolation()
	for i: int in CLOUD_COUNT:
		var cloud := HopCloud.new()
		cloud.position = Vector2(_rng.randf_range(0.0, screen.x), _rng.randf_range(150.0, screen.y - 300.0))
		cloud.speed = _rng.randf_range(40.0, 90.0)
		cloud.scale = Vector2.ONE * _rng.randf_range(0.7, 1.3)
		_cloud_root.add_child(cloud)
		cloud.reset_physics_interpolation()
		_clouds.append(cloud)
	_score_label.text = "0"
	_flash.color.a = 0.0


## Snapshot for the smoke/capture autopilot. Not used by the game itself.
func debug_state() -> Dictionary:
	var next_gap: float = _screen().y / 2.0
	for obstacle: HopObstacle in _obstacles:
		if obstacle.position.x + HopRules.OBSTACLE_WIDTH > _player.position.x - HopRules.PLAYER_SIZE / 2.0:
			next_gap = obstacle.gap_center
			break
	return {
		"state": state,
		"player_y": _player.position.y,
		"velocity_y": velocity_y,
		"next_gap_center": next_gap,
	}


func _unhandled_input(event: InputEvent) -> void:
	# Desktop mouse clicks also arrive as touches (emulate_touch_from_mouse).
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null and touch.pressed:
		_on_tap()
		get_viewport().set_input_as_handled()


func _on_tap() -> void:
	match state:
		State.READY:
			state = State.PLAYING
			_spawn_timer = HopRules.SPAWN_INTERVAL
			_hint.hide()
			_jump()
		State.PLAYING:
			_jump()


func _jump() -> void:
	velocity_y = HopRules.JUMP_VELOCITY
	AudioService.play_sfx(_jump_sound, _fx_rng.randf_range(0.95, 1.08))
	_squash(Vector2(0.78, 1.25))


func _physics_process(delta: float) -> void:
	var screen: Vector2 = _screen()
	_move_clouds(delta, screen)
	match state:
		State.READY:
			# Idle bob, so the screen never looks frozen.
			_ready_time += delta
			_player.position.y = screen.y / 2.0 + sin(_ready_time * 4.0) * 18.0
		State.PLAYING:
			_step(delta, screen)


func _step(delta: float, screen: Vector2) -> void:
	velocity_y += HopRules.GRAVITY * delta
	_player.position.y += velocity_y * delta
	_player.rotation = lerp_angle(_player.rotation, clampf(velocity_y / 2600.0, -0.35, 1.0), 0.25)

	_spawn_timer += delta
	if _spawn_timer >= HopRules.SPAWN_INTERVAL:
		_spawn_timer -= HopRules.SPAWN_INTERVAL
		_spawn(screen)

	var player_rect: Rect2 = HopRules.player_rect(_player.position)
	for obstacle: HopObstacle in _obstacles:
		obstacle.position.x -= HopRules.SCROLL_SPEED * delta
		if not obstacle.scored and obstacle.position.x + HopRules.OBSTACLE_WIDTH < player_rect.position.x:
			obstacle.scored = true
			_add_point()
		if HopRules.hits_obstacle(player_rect, obstacle.position.x, obstacle.gap_center, screen.y):
			_die()
			return
	_despawn_offscreen()
	if HopRules.out_of_bounds(player_rect, screen.y):
		_die()


func _spawn(screen: Vector2) -> void:
	var gap_range: Vector2 = HopRules.gap_center_range(screen.y)
	var obstacle := HopObstacle.new()
	_obstacle_root.add_child(obstacle)
	obstacle.setup(screen.x, _rng.randf_range(gap_range.x, gap_range.y), screen.y)
	_obstacles.append(obstacle)


func _despawn_offscreen() -> void:
	while not _obstacles.is_empty() and _obstacles[0].position.x + HopRules.OBSTACLE_WIDTH + HopObstacle.LIP_OVERHANG < 0.0:
		var gone: HopObstacle = _obstacles.pop_front()
		gone.queue_free()


func _move_clouds(delta: float, screen: Vector2) -> void:
	for cloud: HopCloud in _clouds:
		cloud.position.x -= cloud.speed * delta
		if cloud.position.x < -200.0:
			cloud.position.x = screen.x + 200.0
			cloud.reset_physics_interpolation()


func _add_point() -> void:
	score += 1
	_score_label.text = str(score)
	AudioService.play_sfx(_score_sound)
	if _score_tween != null:
		_score_tween.kill()
	_score_label.pivot_offset = _score_label.size / 2.0
	_score_label.scale = Vector2(1.35, 1.35)
	_score_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_score_tween.tween_property(_score_label, "scale", Vector2.ONE, 0.25)


func _die() -> void:
	state = State.DEAD
	AudioService.play_sfx(_hit_sound)
	SettingsService.vibrate(60)
	_squash(Vector2(1.3, 0.7))
	_flash.color.a = 0.6
	create_tween().tween_property(_flash, "color:a", 0.0, 0.3)
	finished.emit(score)


## Squash-and-stretch on the visual only. Body has physics interpolation off
## because the tween runs per rendered frame, not per physics tick.
func _squash(amount: Vector2) -> void:
	_player_body.scale = amount
	create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT) \
		.tween_property(_player_body, "scale", Vector2.ONE, 0.35)


func _screen() -> Vector2:
	return get_viewport_rect().size

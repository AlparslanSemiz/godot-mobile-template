extends GutTest

const SCREEN_H: float = 1920.0


func test_gap_range_keeps_gap_inside_margins() -> void:
	var gap_range: Vector2 = HopRules.gap_center_range(SCREEN_H)
	assert_eq(gap_range.x - HopRules.GAP_HEIGHT / 2.0, HopRules.GAP_MARGIN)
	assert_eq(gap_range.y + HopRules.GAP_HEIGHT / 2.0, SCREEN_H - HopRules.GAP_MARGIN)


func test_player_in_gap_does_not_hit() -> void:
	var player: Rect2 = HopRules.player_rect(Vector2(400.0, 960.0))
	assert_false(HopRules.hits_obstacle(player, 380.0, 960.0, SCREEN_H))


func test_player_touching_pipe_hits() -> void:
	var player: Rect2 = HopRules.player_rect(Vector2(400.0, 960.0 - HopRules.GAP_HEIGHT / 2.0))
	assert_true(HopRules.hits_obstacle(player, 380.0, 960.0, SCREEN_H))


func test_far_obstacle_does_not_hit() -> void:
	var player: Rect2 = HopRules.player_rect(Vector2(400.0, 100.0))
	assert_false(HopRules.hits_obstacle(player, 900.0, 960.0, SCREEN_H))


func test_screen_edges_are_out_of_bounds() -> void:
	assert_true(HopRules.out_of_bounds(HopRules.player_rect(Vector2(400.0, 10.0)), SCREEN_H))
	assert_true(HopRules.out_of_bounds(HopRules.player_rect(Vector2(400.0, SCREEN_H - 10.0)), SCREEN_H))
	assert_false(HopRules.out_of_bounds(HopRules.player_rect(Vector2(400.0, 960.0)), SCREEN_H))


func test_same_seed_gives_same_run() -> void:
	assert_eq(_simulate(99), _simulate(99))
	assert_ne(_simulate(99), _simulate(100))


## Runs the hop scene for 4 s of fixed ticks with taps every 0.3 s and
## returns a fingerprint of where everything ended up.
func _simulate(rng_seed: int) -> String:
	var hop: Hop = (load("res://games/hop/hop.tscn") as PackedScene).instantiate() as Hop
	add_child(hop)
	hop.start(rng_seed)
	var dt: float = 1.0 / 120.0
	for tick: int in 480:
		if tick % 36 == 0:
			hop.call("_on_tap")
		hop.call("_physics_process", dt)
	var gaps: PackedStringArray = []
	for obstacle: HopObstacle in hop.find_children("*", "HopObstacle", true, false):
		gaps.append("%.2f" % obstacle.gap_center)
	var fingerprint: String = "%d|%.2f|%s" % [hop.score, hop.velocity_y, ",".join(gaps)]
	hop.set_physics_process(false)
	remove_child(hop)
	hop.free()
	return fingerprint

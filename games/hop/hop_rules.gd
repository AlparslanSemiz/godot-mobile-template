class_name HopRules
extends RefCounted
## Pure rules of the hop game (no nodes), so unit tests can check them.
## Sizes are in 1080x1920 reference pixels; same constants as Phase 0.

const GRAVITY: float = 4200.0
const JUMP_VELOCITY: float = -1400.0
const PLAYER_SIZE: float = 90.0
const OBSTACLE_WIDTH: float = 180.0
const GAP_HEIGHT: float = 520.0
const GAP_MARGIN: float = 160.0
const SCROLL_SPEED: float = 420.0
const SPAWN_INTERVAL: float = 1.6


static func player_rect(center: Vector2) -> Rect2:
	var half: float = PLAYER_SIZE / 2.0
	return Rect2(center.x - half, center.y - half, PLAYER_SIZE, PLAYER_SIZE)


## Range for the gap center, keeping the whole gap GAP_MARGIN away from the edges.
static func gap_center_range(screen_height: float) -> Vector2:
	var lo: float = GAP_MARGIN + GAP_HEIGHT / 2.0
	return Vector2(lo, maxf(lo, screen_height - lo))


## Top and bottom pipe of an obstacle whose left edge is at `x`.
static func obstacle_rects(x: float, gap_center: float, screen_height: float) -> Array[Rect2]:
	var gap_top: float = gap_center - GAP_HEIGHT / 2.0
	var gap_bottom: float = gap_center + GAP_HEIGHT / 2.0
	return [
		Rect2(x, 0.0, OBSTACLE_WIDTH, gap_top),
		Rect2(x, gap_bottom, OBSTACLE_WIDTH, screen_height - gap_bottom),
	]


static func hits_obstacle(player: Rect2, x: float, gap_center: float, screen_height: float) -> bool:
	for rect: Rect2 in obstacle_rects(x, gap_center, screen_height):
		if player.intersects(rect):
			return true
	return false


static func out_of_bounds(player: Rect2, screen_height: float) -> bool:
	return player.position.y < 0.0 or player.end.y > screen_height

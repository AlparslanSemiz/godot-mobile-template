class_name HopObstacle
extends Node2D
## One pipe pair. Moved by Hop in _physics_process; physics interpolation smooths it.

const COLOR: Color = Color(0.2, 0.7, 0.3)
const LIP_COLOR: Color = Color(0.15, 0.55, 0.24)
const LIP_HEIGHT: float = 48.0
const LIP_OVERHANG: float = 14.0

var gap_center: float = 0.0
var scored: bool = false
var _screen_height: float = 0.0


func setup(left_x: float, center: float, screen_height: float) -> void:
	position = Vector2(left_x, 0.0)
	gap_center = center
	_screen_height = screen_height
	reset_physics_interpolation()
	queue_redraw()


func _draw() -> void:
	# Drawn in local space; the node's x is the obstacle's left edge.
	for rect: Rect2 in HopRules.obstacle_rects(0.0, gap_center, _screen_height):
		draw_rect(rect, COLOR)
	var gap_top: float = gap_center - HopRules.GAP_HEIGHT / 2.0
	var gap_bottom: float = gap_center + HopRules.GAP_HEIGHT / 2.0
	var lip_width: float = HopRules.OBSTACLE_WIDTH + LIP_OVERHANG * 2.0
	draw_rect(Rect2(-LIP_OVERHANG, gap_top - LIP_HEIGHT, lip_width, LIP_HEIGHT), LIP_COLOR)
	draw_rect(Rect2(-LIP_OVERHANG, gap_bottom, lip_width, LIP_HEIGHT), LIP_COLOR)

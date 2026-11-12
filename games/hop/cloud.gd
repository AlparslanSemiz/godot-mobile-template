class_name HopCloud
extends Node2D
## Background decoration; scrolls slower than the pipes for depth.

# Opaque (sky blended with white): overlapping translucent shapes would show seams.
const COLOR: Color = Color(0.86, 0.94, 0.98)

var speed: float = 60.0


func _draw() -> void:
	draw_circle(Vector2(-70.0, 10.0), 55.0, COLOR)
	draw_circle(Vector2(0.0, -20.0), 75.0, COLOR)
	draw_circle(Vector2(80.0, 12.0), 50.0, COLOR)
	draw_rect(Rect2(-120.0, 10.0, 250.0, 55.0), COLOR)

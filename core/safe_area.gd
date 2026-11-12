class_name SafeArea
extends MarginContainer
## Keeps its children out of notches, rounded corners and system bars.
## Put HUD and menus inside one of these; backgrounds can stay full screen.

## Extra space on every side, in reference pixels (1080x1920 space).
@export var padding: int = 32

## Test hook: `-- --fake-safe-area=top,bottom` simulates insets (in window pixels) on desktop.
static var fake_insets: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	get_tree().root.size_changed.connect(_update)
	_update()


func _update() -> void:
	var window_size: Vector2i = DisplayServer.window_get_size()
	var viewport_size: Vector2 = get_viewport_rect().size
	var safe: Rect2i = Rect2i(Vector2i.ZERO, window_size)
	if fake_insets.x >= 0:
		safe = Rect2i(0, fake_insets.x, window_size.x, window_size.y - fake_insets.x - fake_insets.y)
	elif OS.has_feature("mobile"):
		safe = DisplayServer.get_display_safe_area()
	var margins: Array[int] = compute_margins(safe, window_size, viewport_size)
	add_theme_constant_override("margin_left", margins[0] + padding)
	add_theme_constant_override("margin_top", margins[1] + padding)
	add_theme_constant_override("margin_right", margins[2] + padding)
	add_theme_constant_override("margin_bottom", margins[3] + padding)


## Converts a safe rect in window pixels into [left, top, right, bottom]
## margins in viewport (stretched) pixels.
static func compute_margins(safe: Rect2i, window_size: Vector2i, viewport_size: Vector2) -> Array[int]:
	if window_size.x <= 0 or window_size.y <= 0:
		return [0, 0, 0, 0]
	var ratio: Vector2 = viewport_size / Vector2(window_size)
	var left: float = maxf(safe.position.x, 0) * ratio.x
	var top: float = maxf(safe.position.y, 0) * ratio.y
	var right: float = maxf(window_size.x - safe.end.x, 0) * ratio.x
	var bottom: float = maxf(window_size.y - safe.end.y, 0) * ratio.y
	return [ceili(left), ceili(top), ceili(right), ceili(bottom)]

extends GutTest
## Godot 4.7 buttons handle touches natively; the mouse event emulated from the
## same touch must not press a TapButton a second time.


func test_one_touch_presses_once() -> void:
	var button := TapButton.new()
	button.position = Vector2(100, 100)
	button.size = Vector2(300, 120)
	add_child_autofree(button)
	await wait_process_frames(1)
	watch_signals(button)
	var window_point: Vector2 = get_tree().root.get_final_transform() * button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = window_point
		touch.pressed = pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
	await wait_process_frames(2)
	assert_signal_emit_count(button, "pressed", 1)

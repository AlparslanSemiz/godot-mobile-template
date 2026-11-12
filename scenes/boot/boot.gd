extends Control
## First scene. Autoload services are already loaded at this point.
## Applies debug-only command-line hooks, then opens the main menu.


func _ready() -> void:
	_apply_debug_args()
	AnalyticsService.log_event("app_open")
	SceneRouter.go_to.call_deferred(SceneRouter.MENU, false)


## Debug builds only (tests and captures use these; release builds ignore them):
##   --driver=res://path/to/driver.gd   adds that script's node to the root
##   --fake-safe-area=TOP,BOTTOM        fakes a notch on desktop (window pixels)
func _apply_debug_args() -> void:
	if not OS.is_debug_build():
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--driver="):
			var script: GDScript = load(arg.trim_prefix("--driver=")) as GDScript
			var driver: Node = script.new() as Node
			get_tree().root.add_child.call_deferred(driver)
		elif arg.begins_with("--fake-safe-area="):
			var parts: PackedStringArray = arg.trim_prefix("--fake-safe-area=").split(",")
			SafeArea.fake_insets = Vector2i(int(parts[0]), int(parts[1]))

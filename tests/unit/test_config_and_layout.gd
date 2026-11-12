extends GutTest


func test_game_cfg_is_applied() -> void:
	# Fails when someone edits game.cfg but forgets `make config`.
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://game.cfg"), OK)
	assert_eq(ProjectSettings.get_setting("application/config/name"), cfg.get_value("app", "name"))
	assert_eq(GameConfig.version_name(), cfg.get_value("app", "version_name"))
	assert_eq(GameConfig.game_scene(), cfg.get_value("game", "scene"))
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	for section: String in presets.get_sections():
		if presets.get_value(section, "platform", "") == "Android":
			assert_eq(presets.get_value(section + ".options", "package/unique_name"), cfg.get_value("app", "package"))
			assert_eq(presets.get_value(section + ".options", "version/code"), cfg.get_value("app", "version_code"))


func test_monetization_switches_match_editor_plugins() -> void:
	# A plugin that is switched off in game.cfg must not be enabled, so its
	# export plugin adds no SDK, permission or iOS framework to the build.
	var plugins: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	assert_eq(plugins.has("res://addons/admob/plugin.cfg"), GameConfig.ads_enabled())
	assert_eq(plugins.has("res://addons/GodotGooglePlayBilling/plugin.cfg"), GameConfig.iap_enabled())


func test_switched_off_services_use_no_op_backends() -> void:
	if GameConfig.ads_enabled() or GameConfig.iap_enabled():
		pass_test("switches are on in this checkout")
		return
	var ads: AdServiceNode = (load("res://autoload/ad_service.gd") as GDScript).new()
	var store: PurchaseServiceNode = (load("res://autoload/purchase_service.gd") as GDScript).new()
	var ad_backend: AdBackend = ads.call("_platform_backend")
	var store_backend: PurchaseBackend = store.call("_platform_backend")
	assert_eq(ad_backend.get_script(), AdBackend)
	assert_eq(store_backend.get_script(), PurchaseBackend)
	ads.free()
	store.free()


func test_game_scene_follows_contract() -> void:
	var game: Node = (load(GameConfig.game_scene()) as PackedScene).instantiate()
	assert_true(game.has_signal("finished"))
	assert_true(game.has_method("start"))
	game.free()


func test_safe_area_margins_scale_to_viewport() -> void:
	# Phone 1200x2670 with a 100 px notch and 60 px gesture bar, viewport 1080x2403.
	var margins: Array[int] = SafeArea.compute_margins(Rect2i(0, 100, 1200, 2510), Vector2i(1200, 2670), Vector2(1080, 2403))
	assert_eq(margins, [0, 90, 0, 54] as Array[int])


func test_safe_area_full_screen_has_no_margins() -> void:
	var margins: Array[int] = SafeArea.compute_margins(Rect2i(0, 0, 540, 960), Vector2i(540, 960), Vector2(1080, 1920))
	assert_eq(margins, [0, 0, 0, 0] as Array[int])


func test_buses_exist() -> void:
	assert_ne(AudioServer.get_bus_index(&"SFX"), -1)
	assert_ne(AudioServer.get_bus_index(&"Music"), -1)

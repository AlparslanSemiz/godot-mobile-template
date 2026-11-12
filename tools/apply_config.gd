extends SceneTree
## Copies game.cfg into project.godot and export_presets.cfg.
## The [ads]/[iap] `enabled` switches also add or remove the AdMob/Billing
## editor plugins (so their export plugins add no SDKs, permissions or iOS
## frameworks) and exclude the unused plugin files from every export preset.
## Run: godot --headless --path . --script res://tools/apply_config.gd
## With `-- --check` it changes nothing and exits 1 if anything is out of date.

const CONFIG_PATH: String = "res://game.cfg"
const PRESETS_PATH: String = "res://export_presets.cfg"

# Values are DisplayServer.ScreenOrientation.
const ORIENTATIONS: Dictionary = {
	"landscape": DisplayServer.SCREEN_LANDSCAPE,
	"portrait": DisplayServer.SCREEN_PORTRAIT,
	"sensor_landscape": DisplayServer.SCREEN_SENSOR_LANDSCAPE,
	"sensor_portrait": DisplayServer.SCREEN_SENSOR_PORTRAIT,
	"sensor": DisplayServer.SCREEN_SENSOR,
}
const LANDSCAPE_ORIENTATIONS: Array[String] = ["landscape", "sensor_landscape"]
const ADMOB_PLUGIN: String = "res://addons/admob/plugin.cfg"
const BILLING_PLUGIN: String = "res://addons/GodotGooglePlayBilling/plugin.cfg"
const BASE_EXCLUDE: String = "tests/*, tools/*, docs/*, patches/*, addons/gut/*, addons/admob/gdscript/sample/*, addons/admob/csharp/*, addons/admob/skills/*, addons/admob/docs/*"
const ADS_OFF_EXCLUDE: String = "addons/admob/*, services/admob_ad_backend.gd"
const IAP_OFF_EXCLUDE: String = "addons/GodotGooglePlayBilling/*, services/play_billing_backend.gd"
# Defaults of the AdMob plugin (addons/admob/internal/services/project_settings_service.gd).
const ADMOB_DEFAULTS: Dictionary = {
	"admob/general/android/app_id": "ca-app-pub-3940256099942544~3347511713",
	"admob/general/ios/app_id": "ca-app-pub-3940256099942544~1458002511",
}


func _initialize() -> void:
	var check_only: bool = OS.get_cmdline_user_args().has("--check")
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		printerr("apply_config: cannot read ", CONFIG_PATH)
		quit(1)
		return
	var orientation: String = str(cfg.get_value("app", "orientation", "portrait"))
	if not ORIENTATIONS.has(orientation):
		printerr("apply_config: unknown orientation '%s', use one of %s" % [orientation, ORIENTATIONS.keys()])
		quit(1)
		return
	var game_scene: String = str(cfg.get_value("game", "scene", ""))
	if not ResourceLoader.exists(game_scene, "PackedScene"):
		printerr("apply_config: [game] scene '%s' does not exist or is not a scene" % game_scene)
		quit(1)
		return
	var landscape: bool = LANDSCAPE_ORIENTATIONS.has(orientation)
	var ads_enabled: bool = bool(cfg.get_value("ads", "enabled", false))
	var iap_enabled: bool = bool(cfg.get_value("iap", "enabled", false))
	# Keep any other editor plugins; the two managed ones follow the switches.
	var plugins: PackedStringArray = []
	for path: String in ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray()):
		if path != ADMOB_PLUGIN and path != BILLING_PLUGIN:
			plugins.append(path)
	if iap_enabled:
		plugins.append(BILLING_PLUGIN)
	if ads_enabled:
		plugins.append(ADMOB_PLUGIN)
	var exclude_filter: String = BASE_EXCLUDE
	if not ads_enabled:
		exclude_filter += ", " + ADS_OFF_EXCLUDE
	if not iap_enabled:
		exclude_filter += ", " + IAP_OFF_EXCLUDE
	var project_values: Dictionary = {
		"application/config/name": str(cfg.get_value("app", "name")),
		"application/config/version": str(cfg.get_value("app", "version_name")),
		"display/window/handheld/orientation": ORIENTATIONS[orientation],
		"display/window/size/viewport_width": 1920 if landscape else 1080,
		"display/window/size/viewport_height": 1080 if landscape else 1920,
		"display/window/size/window_width_override": 960 if landscape else 540,
		"display/window/size/window_height_override": 540 if landscape else 960,
		"game/config/scene": str(cfg.get_value("game", "scene")),
		"game/ads/interstitial_every_n_runs": int(cfg.get_value("ads", "interstitial_every_n_runs", 0)),
		"game/iap/remove_ads_product_id": str(cfg.get_value("iap", "remove_ads_product_id")),
		"game/ads/enabled": ads_enabled,
		"game/iap/enabled": iap_enabled,
		"game/feedback/url": str(cfg.get_value("feedback", "url", "")),
		"editor_plugins/enabled": plugins,
	}
	# Optional ad keys: a game without ads drops them from game.cfg, and then
	# they are removed from project.godot too (null = remove), so no stale ids remain.
	for key: String in ["android_interstitial", "android_rewarded", "ios_interstitial", "ios_rewarded",
			"debug_consent_eea", "test_device_hashed_ids"]:
		project_values["game/ads/" + key] = cfg.get_value("ads", key) if cfg.has_section_key("ads", key) else null
	for platform: String in ["android", "ios"]:
		var cfg_key: String = platform + "_app_id"
		var app_id: Variant = null
		if cfg.has_section_key("ads", cfg_key):
			app_id = str(cfg.get_value("ads", cfg_key))
		project_values["admob/general/%s/app_id" % platform] = app_id
	var preset_values: Dictionary = {
		"Android": {
			"package/unique_name": str(cfg.get_value("app", "package")),
			"package/name": str(cfg.get_value("app", "name")),
			"version/code": int(cfg.get_value("app", "version_code")),
			"version/name": str(cfg.get_value("app", "version_name")),
		},
		"iOS": {
			"application/bundle_identifier": str(cfg.get_value("app", "package")),
			"application/short_version": str(cfg.get_value("app", "version_name")),
			"application/version": str(cfg.get_value("app", "version_code")),
		},
	}

	var stale: PackedStringArray = []
	for key: String in project_values:
		# The AdMob editor plugin removes its settings from project.godot when they
		# equal its defaults (Google's sample app ids) and re-adds them in memory;
		# both states count as "the default" here.
		var current: Variant = ProjectSettings.get_setting(key) if ProjectSettings.has_setting(key) else null
		if ADMOB_DEFAULTS.has(key) and current == ADMOB_DEFAULTS[key]:
			current = null
		var wanted: Variant = project_values[key]
		if ADMOB_DEFAULTS.has(key) and wanted == ADMOB_DEFAULTS[key]:
			wanted = null
		if current == wanted:
			continue
		stale.append("project.godot " + key)
		ProjectSettings.set_setting(key, project_values[key])

	var presets := ConfigFile.new()
	if presets.load(PRESETS_PATH) != OK:
		printerr("apply_config: cannot read ", PRESETS_PATH)
		quit(1)
		return
	for section: String in presets.get_sections():
		if section.ends_with(".options") or not presets.has_section_key(section, "platform"):
			continue
		var platform: String = str(presets.get_value(section, "platform"))
		if presets.get_value(section, "exclude_filter", "") != exclude_filter:
			stale.append("export_presets.cfg %s exclude_filter" % presets.get_value(section, "name"))
			presets.set_value(section, "exclude_filter", exclude_filter)
		if not preset_values.has(platform):
			continue
		var values: Dictionary = preset_values[platform]
		for key: String in values:
			if presets.get_value(section + ".options", key) != values[key]:
				stale.append("export_presets.cfg %s %s" % [platform, key])
				presets.set_value(section + ".options", key, values[key])

	if stale.is_empty():
		print("apply_config: up to date")
		quit(0)
		return
	if check_only:
		printerr("apply_config: out of date, run `make config`:\n  " + "\n  ".join(stale))
		quit(1)
		return
	ProjectSettings.save()
	presets.save(PRESETS_PATH)
	print("apply_config: updated\n  " + "\n  ".join(stale))
	quit(0)

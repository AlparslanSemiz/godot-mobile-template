class_name GameConfig
extends RefCounted
## Read-only access to the per-game values from game.cfg.
## tools/apply_config.gd copies them into project.godot under "game/".


static func app_name() -> String:
	return str(ProjectSettings.get_setting("application/config/name", ""))


static func version_name() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


static func game_scene() -> String:
	return str(ProjectSettings.get_setting("game/config/scene", "res://games/hop/hop.tscn"))


## game.cfg [ads] enabled. When false nothing may load the AdMob plugin.
static func ads_enabled() -> bool:
	return bool(ProjectSettings.get_setting("game/ads/enabled", false))


## game.cfg [iap] enabled. When false nothing may load the billing plugin.
static func iap_enabled() -> bool:
	return bool(ProjectSettings.get_setting("game/iap/enabled", false))


static func interstitial_every_n_runs() -> int:
	return int(ProjectSettings.get_setting("game/ads/interstitial_every_n_runs", 0))


static func remove_ads_product_id() -> String:
	return str(ProjectSettings.get_setting("game/iap/remove_ads_product_id", "remove_ads"))


## game.cfg [feedback] url: the Settings "Send feedback" link ("" = no button).
static func feedback_url() -> String:
	return str(ProjectSettings.get_setting("game/feedback/url", ""))


## The feedback URL with {version} and {device} filled in (URL-encoded), so a
## form can prefill them; also their percent-encoded forms (%7Bversion%7D), as
## a Google Forms pre-filled link stores them. Nothing personal is added.
static func feedback_link(url: String, version: String, device: String) -> String:
	var link: String = url
	for key: String in ["version", "device"]:
		var value: String = (version if key == "version" else device).uri_encode()
		link = link.replace("{%s}" % key, value).replacen("%%7B%s%%7D" % key, value)
	return link

extends GutTest
## Settings "Send feedback" (release prep): hidden when game.cfg [feedback] url
## is empty; otherwise opens the URL with the version and device model filled
## into {version} and {device} (URL-encoded). No personal data.

const KEY: String = "game/feedback/url"

var _kept: Variant


func before_each() -> void:
	_kept = ProjectSettings.get_setting(KEY, "")


func after_each() -> void:
	ProjectSettings.set_setting(KEY, _kept)


func test_link_fills_version_and_device_encoded() -> void:
	var link: String = GameConfig.feedback_link("https://example.com/form?v={version}&d={device}", "0.1.0", "Pixel 8 Pro")
	assert_eq(link, "https://example.com/form?v=0.1.0&d=Pixel%208%20Pro")


## Review finding (Codex): a Google Forms pre-filled link stores the answer
## "{version}" percent-encoded as %7Bversion%7D, which was left as it was.
func test_link_fills_percent_encoded_placeholders_too() -> void:
	var link: String = GameConfig.feedback_link("https://docs.google.com/forms/d/e/x/viewform?entry.1=%7Bversion%7D&entry.2=%7bdevice%7d", "0.1.0", "Pixel 8")
	assert_eq(link, "https://docs.google.com/forms/d/e/x/viewform?entry.1=0.1.0&entry.2=Pixel%208")


func test_link_without_placeholders_stays_as_is() -> void:
	assert_eq(GameConfig.feedback_link("https://example.com/form", "0.1.0", "X"), "https://example.com/form")


func test_button_hidden_when_the_url_is_empty_and_shown_when_set() -> void:
	ProjectSettings.set_setting(KEY, "")
	var panel: SettingsPanel = (load("res://scenes/menu/settings_panel.tscn") as PackedScene).instantiate()
	add_child_autofree(panel)
	panel.open()
	assert_false(panel.feedback_button().visible, "hidden without a URL")
	ProjectSettings.set_setting(KEY, "https://example.com/form?v={version}")
	panel.open()
	assert_true(panel.feedback_button().visible, "shown with a URL")
	assert_eq(GameConfig.feedback_url(), "https://example.com/form?v={version}")


## Review finding (fresh Claude): the press path itself was untested. The
## button opens exactly the configured link with this build's version.
func test_the_button_opens_the_configured_link() -> void:
	ProjectSettings.set_setting(KEY, "https://example.com/f?v={version}&d={device}")
	var panel: SettingsPanel = (load("res://scenes/menu/settings_panel.tscn") as PackedScene).instantiate()
	add_child_autofree(panel)
	assert_eq(panel.feedback_target(), GameConfig.feedback_link(GameConfig.feedback_url(), GameConfig.version_name(), OS.get_model_name()))
	assert_string_contains(panel.feedback_target(), "v=" + GameConfig.version_name().uri_encode())


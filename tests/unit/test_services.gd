extends GutTest
## Settings, ads, purchases and analytics with their default (no-op) backends.

const SaveScript: GDScript = preload("res://autoload/save_service.gd")
const SettingsScript: GDScript = preload("res://autoload/settings_service.gd")
const AdScript: GDScript = preload("res://autoload/ad_service.gd")
const PurchaseScript: GDScript = preload("res://autoload/purchase_service.gd")
const PATH: String = "user://test_services_save.json"

var save: SaveServiceNode


func before_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	save = SaveScript.new()
	save.path = PATH
	save.load_data()


func after_each() -> void:
	save.free()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func test_settings_toggle_persists_and_signals() -> void:
	var settings: SettingsServiceNode = SettingsScript.new()
	settings.save = save
	add_child_autofree(settings)
	watch_signals(settings)
	settings.set_sound_enabled(false)
	assert_false(settings.is_sound_enabled())
	assert_signal_emit_count(settings, "changed", 1)
	settings.set_sound_enabled(false)
	assert_signal_emit_count(settings, "changed", 1, "no signal when nothing changes")
	var reloaded: SaveServiceNode = SaveScript.new()
	reloaded.path = PATH
	reloaded.load_data()
	assert_false(reloaded.get_setting("sound"))
	reloaded.free()


## Feedback round 1: music is its own switch (on by default), and "reset best
## scores" clears every best (per mode too) but nothing else.
func test_music_setting_is_separate_and_on_by_default() -> void:
	var settings: SettingsServiceNode = SettingsScript.new()
	settings.save = save
	add_child_autofree(settings)
	assert_true(settings.is_music_enabled(), "on by default")
	settings.set_music_enabled(false)
	assert_false(settings.is_music_enabled())
	assert_true(settings.is_sound_enabled(), "sound effects keep their own switch")


func test_reset_best_scores_clears_every_best_and_keeps_the_rest() -> void:
	save.set_int("best_score", 900)
	save.set_int("best_links", 400)
	save.set_int("best_sand", 300)
	save.set_int("runs", 12)
	save.reset_best_scores()
	assert_eq(save.get_int("best_score"), 0)
	assert_eq(save.get_int("best_links"), 0)
	assert_eq(save.get_int("best_sand"), 0)
	assert_eq(save.get_int("runs"), 12, "other numbers stay")
	var reloaded: SaveServiceNode = SaveScript.new()
	reloaded.path = PATH
	reloaded.load_data()
	assert_eq(reloaded.get_int("best_links"), 0, "saved")
	reloaded.free()


func test_default_ads_close_immediately_and_never_reward() -> void:
	var ads: AdServiceNode = AdScript.new()
	ads.save = save
	add_child_autofree(ads)
	watch_signals(ads)
	ads.show_interstitial()
	ads.show_rewarded()
	await wait_physics_frames(2)
	assert_signal_emitted(ads, "interstitial_closed")
	assert_signal_emitted_with_parameters(ads, "rewarded_finished", [false])


func test_interstitial_skipped_when_ads_removed() -> void:
	save.set_bool("ads_removed", true)
	var ads: AdServiceNode = AdScript.new()
	ads.save = save
	add_child_autofree(ads)
	var backend := CountingAdBackend.new()
	ads.set_backend(backend)
	assert_true(ads.ads_removed())
	ads.show_interstitial()
	await wait_physics_frames(2)
	assert_eq(backend.interstitials, 0)


func test_default_purchase_fails_cleanly() -> void:
	var store: PurchaseServiceNode = PurchaseScript.new()
	store.save = save
	add_child_autofree(store)
	watch_signals(store)
	store.buy_remove_ads()
	store.restore_purchases()
	await wait_physics_frames(2)
	assert_signal_emitted_with_parameters(store, "purchase_failed", ["remove_ads", "store_unavailable"])
	assert_signal_emitted(store, "restore_finished")
	assert_false(save.get_bool("ads_removed"))
	assert_false(store.is_store_available(), "no store on desktop, so Settings hides the store buttons")


func test_successful_remove_ads_purchase_is_saved() -> void:
	var store: PurchaseServiceNode = PurchaseScript.new()
	store.save = save
	add_child_autofree(store)
	store.set_backend(InstantStoreBackend.new())
	store.buy_remove_ads()
	await wait_physics_frames(2)
	assert_true(save.get_bool("ads_removed"))


func test_store_sync_revokes_refunded_remove_ads() -> void:
	save.set_bool("ads_removed", true)
	var store: PurchaseServiceNode = PurchaseScript.new()
	store.save = save
	add_child_autofree(store)
	var backend := PurchaseBackend.new()
	store.set_backend(backend)
	backend.entitlements_synced.emit(PackedStringArray())
	assert_false(save.get_bool("ads_removed"), "refunded purchase is taken back")
	backend.entitlements_synced.emit(PackedStringArray(["remove_ads"]))
	assert_true(save.get_bool("ads_removed"))


func test_analytics_default_accepts_events() -> void:
	AnalyticsService.log_event("unit_test", {"value": 1})
	pass_test("no-op backend did not crash")


class CountingAdBackend:
	extends AdBackend
	var interstitials: int = 0

	func show_interstitial() -> void:
		interstitials += 1
		super.show_interstitial()


class InstantStoreBackend:
	extends PurchaseBackend

	func purchase(product_id: String) -> void:
		purchased.emit.call_deferred(product_id)

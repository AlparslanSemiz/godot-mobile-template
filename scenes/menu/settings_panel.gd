class_name SettingsPanel
extends Control
## Sound effects, music and haptics toggles, "Reset best scores" (asks on the
## button first), "Send feedback" (game.cfg [feedback] url; hidden when
## empty), plus the store buttons. Games add their own rows here. Used from the main menu and from the in-game pause menu.

## "Reset best scores" asks this long before it falls back (seconds).
const RESET_ASK_TIME: float = 3.0
var _asking_reset: bool = false
## Which question a timer belongs to (an old timer must not end a newer one).
var _ask_id: int = 0

@onready var _sound: TapButton = %SoundButton
@onready var _music: TapButton = %MusicButton
@onready var _vibration: TapButton = %VibrationButton
@onready var _reset: TapButton = %ResetBestButton
@onready var _feedback: TapButton = %FeedbackButton
@onready var _remove_ads: TapButton = %RemoveAdsButton
@onready var _restore: TapButton = %RestoreButton
@onready var _privacy: TapButton = %PrivacyButton
@onready var _test_interstitial: TapButton = %TestInterstitialButton
@onready var _test_rewarded: TapButton = %TestRewardedButton
@onready var _close: TapButton = %CloseButton
@onready var _status: Label = %Status
@onready var _card: Control = %Card


func _ready() -> void:
	hide()
	_sound.pressed.connect(func() -> void: SettingsService.set_sound_enabled(not SettingsService.is_sound_enabled()))
	_music.pressed.connect(func() -> void: SettingsService.set_music_enabled(not SettingsService.is_music_enabled()))
	_vibration.pressed.connect(func() -> void: SettingsService.set_vibration_enabled(not SettingsService.is_vibration_enabled()))
	_reset.pressed.connect(_on_reset)
	_feedback.pressed.connect(func() -> void: OS.shell_open(feedback_target()))
	_remove_ads.pressed.connect(_on_remove_ads)
	_restore.pressed.connect(_on_restore)
	_close.pressed.connect(close)
	_privacy.pressed.connect(AdService.show_privacy_options)
	# Debug builds with ads on only: fire ads directly, for testing on a phone.
	_test_interstitial.visible = OS.is_debug_build() and GameConfig.ads_enabled()
	_test_rewarded.visible = OS.is_debug_build() and GameConfig.ads_enabled()
	_test_interstitial.pressed.connect(_on_test_interstitial)
	_test_rewarded.pressed.connect(_on_test_rewarded)
	AdService.interstitial_closed.connect(func() -> void: _status.text = "Interstitial closed")
	AdService.rewarded_finished.connect(func(earned: bool) -> void:
		_status.text = "Rewarded finished, earned=%s" % earned)
	SettingsService.changed.connect(_refresh)
	PurchaseService.purchase_succeeded.connect(_on_purchase_succeeded)
	PurchaseService.purchase_failed.connect(_on_purchase_failed)
	PurchaseService.restore_finished.connect(_on_restore_finished)
	_refresh()


func open() -> void:
	_status.text = ""
	_asking_reset = false
	_refresh()
	show()
	modulate.a = 0.0
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.92, 0.92)
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.2)


func close() -> void:
	hide()


func _refresh() -> void:
	_sound.text = "Sound effects: " + ("On" if SettingsService.is_sound_enabled() else "Off")
	_music.text = "Music: " + ("On" if SettingsService.is_music_enabled() else "Off")
	_vibration.text = "Haptics: " + ("On" if SettingsService.is_vibration_enabled() else "Off")
	_reset.text = "Reset best scores? Tap again" if _asking_reset else "Reset best scores"
	_feedback.visible = GameConfig.feedback_url() != ""
	_remove_ads.visible = PurchaseService.is_store_available() and not AdService.ads_removed()
	_restore.visible = PurchaseService.is_store_available()
	_privacy.visible = AdService.privacy_options_required()


## First press asks (on the button itself), the second resets; the question
## goes away after RESET_ASK_TIME.
func _on_reset() -> void:
	if not _asking_reset:
		_asking_reset = true
		_ask_id += 1
		var asked: int = _ask_id
		_refresh()
		get_tree().create_timer(RESET_ASK_TIME).timeout.connect(func() -> void:
			if asked == _ask_id:
				_asking_reset = false
				_refresh())
		return
	_asking_reset = false
	SaveService.reset_best_scores()
	_status.text = "Best scores reset"
	_refresh()


func reset_button() -> TapButton:
	return _reset


func feedback_button() -> TapButton:
	return _feedback


## The link "Send feedback" opens: the configured URL with this build's
## version and the phone model filled in.
func feedback_target() -> String:
	return GameConfig.feedback_link(GameConfig.feedback_url(), GameConfig.version_name(), OS.get_model_name())


func _on_test_interstitial() -> void:
	_status.text = "Showing interstitial…"
	AdService.show_interstitial()


func _on_test_rewarded() -> void:
	_status.text = "Showing rewarded…"
	AdService.show_rewarded()


func _on_remove_ads() -> void:
	_status.text = "Contacting store…"
	PurchaseService.buy_remove_ads()


func _on_restore() -> void:
	_status.text = "Restoring…"
	PurchaseService.restore_purchases()


func _on_purchase_succeeded(_product_id: String) -> void:
	_status.text = "Thanks! Ads removed."
	_refresh()


func _on_purchase_failed(_product_id: String, reason: String) -> void:
	_status.text = "Purchase failed (%s)" % reason


func _on_restore_finished(product_ids: PackedStringArray) -> void:
	_status.text = "Restored %d purchase(s)" % product_ids.size()
	_refresh()

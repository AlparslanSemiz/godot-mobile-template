extends AdBackend
## Google AdMob through the Poing Studios plugin (addons/admob, v5.1.0).
## AdService loads this only when the native plugin exists (Android/iOS builds).
##
## Order follows Google's guidance: update consent (UMP) first, show the
## consent form if required, then initialize the Mobile Ads SDK and preload
## one interstitial and one rewarded ad. Ad unit ids come from game.cfg [ads].
## Ads are requested only while consent is OBTAINED or NOT_REQUIRED (the plugin
## has no canRequestAds(), so this is the equivalent check).

const RETRY_SECONDS: float = 30.0

var _host: Node
var _interstitial_unit: String = ""
var _rewarded_unit: String = ""
var _sdk_started: bool = false
var _interstitial: InterstitialAd
var _rewarded: RewardedAd
var _interstitial_loading: bool = false
var _rewarded_loading: bool = false
## A full-screen ad is on screen; overlapping show calls are ignored (the ad
## already showing will emit its own finished signal).
var _showing: bool = false
var _reward_earned: bool = false


func attach(host: Node) -> void:
	_host = host


func initialize() -> void:
	var platform: String = "ios" if OS.get_name() == "iOS" else "android"
	_interstitial_unit = str(ProjectSettings.get_setting("game/ads/%s_interstitial" % platform, ""))
	_rewarded_unit = str(ProjectSettings.get_setting("game/ads/%s_rewarded" % platform, ""))
	_request_consent()


func privacy_options_required() -> bool:
	return UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options() -> void:
	UserMessagingPlatform.show_privacy_options_form(func(error: FormError) -> void:
		if error != null:
			print("AdMob: privacy options form error: ", error.message)
		_start_sdk_if_allowed())


func show_interstitial() -> void:
	if _showing:
		print("AdMob: an ad is already showing, ignoring show_interstitial()")
		return
	if _interstitial == null:
		print("AdMob: interstitial not ready")
		interstitial_closed.emit.call_deferred()
		_load_interstitial()
		return
	var ad: InterstitialAd = _interstitial
	_interstitial = null
	_showing = true
	var callback := FullScreenContentCallback.new()
	callback.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_showing = false
		interstitial_closed.emit()
		_load_interstitial()
	callback.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		print("AdMob: interstitial failed to show: ", error.message)
		ad.destroy()
		_showing = false
		interstitial_closed.emit()
		_load_interstitial()
	ad.full_screen_content_callback = callback
	ad.show()


func show_rewarded() -> void:
	if _showing:
		print("AdMob: an ad is already showing, ignoring show_rewarded()")
		return
	if _rewarded == null:
		print("AdMob: rewarded not ready")
		rewarded_finished.emit.call_deferred(false)
		_load_rewarded()
		return
	var ad: RewardedAd = _rewarded
	_rewarded = null
	_reward_earned = false
	_showing = true
	var callback := FullScreenContentCallback.new()
	callback.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_showing = false
		rewarded_finished.emit(_reward_earned)
		_load_rewarded()
	callback.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		print("AdMob: rewarded failed to show: ", error.message)
		ad.destroy()
		_showing = false
		rewarded_finished.emit(false)
		_load_rewarded()
	ad.full_screen_content_callback = callback
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(item: RewardedItem) -> void:
		print("AdMob: reward earned: %d %s" % [item.amount, item.type])
		_reward_earned = true
	ad.show(listener)


func _request_consent() -> void:
	var request := ConsentRequestParameters.new()
	if OS.is_debug_build():
		var debug := ConsentDebugSettings.new()
		if bool(ProjectSettings.get_setting("game/ads/debug_consent_eea", false)):
			debug.debug_geography = DebugGeography.Values.EEA
		for id: String in str(ProjectSettings.get_setting("game/ads/test_device_hashed_ids", "")).split(",", false):
			debug.test_device_hashed_ids.append(id.strip_edges())
		request.consent_debug_settings = debug
		print("AdMob: consent debug geography=%d, test devices=%d" % [debug.debug_geography, debug.test_device_hashed_ids.size()])
	UserMessagingPlatform.consent_information.update(request, _on_consent_updated, _on_consent_failed)


func _on_consent_updated() -> void:
	var status: int = UserMessagingPlatform.consent_information.get_consent_status()
	print("AdMob: consent info updated, status=%d, form available=%s" % [
		status, UserMessagingPlatform.consent_information.get_is_consent_form_available()])
	if status == ConsentInformation.ConsentStatus.REQUIRED \
			and UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_consent_form_loaded, _on_consent_failed)
	else:
		_start_sdk_if_allowed()


func _on_consent_form_loaded(form: ConsentForm) -> void:
	print("AdMob: showing consent form")
	form.show(func(error: FormError) -> void:
		if error != null:
			print("AdMob: consent form error: ", error.message)
		print("AdMob: consent form closed, status=%d" % UserMessagingPlatform.consent_information.get_consent_status())
		_start_sdk_if_allowed())


## When the consent request fails, the status stored from an earlier session
## still counts; with no usable status ads simply stay off this session.
func _on_consent_failed(error: FormError) -> void:
	print("AdMob: consent error %d: %s" % [error.error_code, error.message])
	_start_sdk_if_allowed()


func _can_request_ads() -> bool:
	var status: int = UserMessagingPlatform.consent_information.get_consent_status()
	return status == ConsentInformation.ConsentStatus.OBTAINED \
		or status == ConsentInformation.ConsentStatus.NOT_REQUIRED


func _start_sdk_if_allowed() -> void:
	if _sdk_started:
		return
	if not _can_request_ads():
		print("AdMob: no usable consent (status=%d), ads stay off" % UserMessagingPlatform.consent_information.get_consent_status())
		return
	_sdk_started = true
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		print("AdMob: SDK initialized")
		_load_interstitial()
		_load_rewarded()
	MobileAds.initialize(listener)


func _load_interstitial() -> void:
	if not _sdk_started or _interstitial_unit.is_empty() or _interstitial != null or _interstitial_loading:
		return
	_interstitial_loading = true
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		print("AdMob: interstitial loaded")
		_interstitial_loading = false
		_interstitial = ad
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		print("AdMob: interstitial failed to load: ", error.message)
		_retry(func() -> void:
			_interstitial_loading = false
			_load_interstitial())
	InterstitialAdLoader.new().load(_interstitial_unit, AdRequest.new(), callback)


func _load_rewarded() -> void:
	if not _sdk_started or _rewarded_unit.is_empty() or _rewarded != null or _rewarded_loading:
		return
	_rewarded_loading = true
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		print("AdMob: rewarded loaded")
		_rewarded_loading = false
		_rewarded = ad
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		print("AdMob: rewarded failed to load: ", error.message)
		_retry(func() -> void:
			_rewarded_loading = false
			_load_rewarded())
	RewardedAdLoader.new().load(_rewarded_unit, AdRequest.new(), callback)


## Runs `action` (which clears the loading flag and loads again) after a delay.
## The loading flag stays set until then, so only one retry is ever pending.
func _retry(action: Callable) -> void:
	if _host != null and _host.is_inside_tree():
		_host.get_tree().create_timer(RETRY_SECONDS).timeout.connect(action)

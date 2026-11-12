class_name AdServiceNode
extends Node
## The only door to ads. Game code calls this, never an ad plugin.
## The default backend shows nothing and reports "closed" / "not earned".

signal interstitial_closed
signal rewarded_finished(earned: bool)

## Real backend, used only when ads are enabled in game.cfg and the native
## plugin is present (Android/iOS builds).
const ADMOB_BACKEND: String = "res://services/admob_ad_backend.gd"
const ADMOB_SINGLETON: String = "PoingGodotAdMob"

## Overridable in tests; defaults to the SaveService autoload.
var save: SaveServiceNode
var _backend: AdBackend


func _ready() -> void:
	if save == null:
		save = SaveService
	set_backend(_platform_backend())


func _platform_backend() -> AdBackend:
	# Check the switch first: with ads off, neither the singleton nor any
	# plugin script may be touched.
	if not GameConfig.ads_enabled():
		return AdBackend.new()
	if Engine.has_singleton(ADMOB_SINGLETON) and ResourceLoader.exists(ADMOB_BACKEND):
		return (load(ADMOB_BACKEND) as GDScript).new() as AdBackend
	return AdBackend.new()


func set_backend(backend: AdBackend) -> void:
	if _backend != null:
		_backend.interstitial_closed.disconnect(_on_interstitial_closed)
		_backend.rewarded_finished.disconnect(_on_rewarded_finished)
	_backend = backend
	_backend.interstitial_closed.connect(_on_interstitial_closed)
	_backend.rewarded_finished.connect(_on_rewarded_finished)
	_backend.attach(self)
	_backend.initialize()


## Shows a full-screen ad unless the player bought "remove ads".
## Always ends with interstitial_closed, so callers can simply await it.
func show_interstitial() -> void:
	if ads_removed():
		interstitial_closed.emit.call_deferred()
		return
	_backend.show_interstitial()


## Opt-in ad; still offered after "remove ads". Ends with rewarded_finished.
func show_rewarded() -> void:
	_backend.show_rewarded()


func ads_removed() -> bool:
	return save.get_bool("ads_removed")


## Settings shows a "Privacy options" button when this is true (GDPR).
func privacy_options_required() -> bool:
	return _backend.privacy_options_required()


func show_privacy_options() -> void:
	_backend.show_privacy_options()


func _on_interstitial_closed() -> void:
	interstitial_closed.emit()


func _on_rewarded_finished(earned: bool) -> void:
	rewarded_finished.emit(earned)

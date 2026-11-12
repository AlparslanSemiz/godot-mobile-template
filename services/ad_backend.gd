class_name AdBackend
extends RefCounted
## No-op ad backend. A real SDK backend extends this, overrides the methods
## and emits the signals when the SDK reports back. Only AdService uses it.

@warning_ignore("unused_signal")
signal interstitial_closed
@warning_ignore("unused_signal")
signal rewarded_finished(earned: bool)


## Called once by AdService; `host` is AdService itself, for backends that need nodes or timers.
func attach(_host: Node) -> void:
	pass


func initialize() -> void:
	pass


## True when the consent SDK says the player must be able to reopen the consent choices.
func privacy_options_required() -> bool:
	return false


func show_privacy_options() -> void:
	pass


func show_interstitial() -> void:
	interstitial_closed.emit.call_deferred()


func show_rewarded() -> void:
	rewarded_finished.emit.call_deferred(false)

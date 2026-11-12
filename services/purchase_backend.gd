class_name PurchaseBackend
extends RefCounted
## No-op store backend. A real store backend extends this and emits the
## signals when the store reports back. Only PurchaseService uses it.

@warning_ignore("unused_signal")
signal purchased(product_id: String)
@warning_ignore("unused_signal")
signal purchase_failed(product_id: String, reason: String)
@warning_ignore("unused_signal")
signal restored(product_ids: PackedStringArray)
## The store answered "these are ALL products this player owns right now".
## Emitted only on a successful query; PurchaseService grants and revokes from it.
@warning_ignore("unused_signal")
signal entitlements_synced(owned: PackedStringArray)


## Called once by PurchaseService; `host` is PurchaseService itself.
func attach(_host: Node) -> void:
	pass


func initialize(_product_ids: PackedStringArray) -> void:
	pass


## False when this platform has no store; Settings then hides the store buttons.
func is_available() -> bool:
	return false


func purchase(product_id: String) -> void:
	purchase_failed.emit.call_deferred(product_id, "store_unavailable")


func restore() -> void:
	restored.emit.call_deferred(PackedStringArray())

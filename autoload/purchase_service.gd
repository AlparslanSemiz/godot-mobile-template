class_name PurchaseServiceNode
extends Node
## The only door to in-app purchases. Game code calls this, never a store plugin.
## The default backend reports every purchase as failed ("store_unavailable").

signal purchase_succeeded(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal restore_finished(product_ids: PackedStringArray)

## Real backend, used only when IAP is enabled in game.cfg and the native
## plugin is present (Android builds).
const PLAY_BILLING_BACKEND: String = "res://services/play_billing_backend.gd"
const PLAY_BILLING_SINGLETON: String = "GodotGooglePlayBilling"

## Overridable in tests; defaults to the SaveService autoload.
var save: SaveServiceNode
var remove_ads_id: String = GameConfig.remove_ads_product_id()
var _backend: PurchaseBackend


func _ready() -> void:
	if save == null:
		save = SaveService
	set_backend(_platform_backend())


func _platform_backend() -> PurchaseBackend:
	# Check the switch first: with IAP off, neither the singleton nor any
	# plugin script may be touched.
	if not GameConfig.iap_enabled():
		return PurchaseBackend.new()
	if Engine.has_singleton(PLAY_BILLING_SINGLETON) and ResourceLoader.exists(PLAY_BILLING_BACKEND):
		return (load(PLAY_BILLING_BACKEND) as GDScript).new() as PurchaseBackend
	return PurchaseBackend.new()


func set_backend(backend: PurchaseBackend) -> void:
	if _backend != null:
		_backend.purchased.disconnect(_on_purchased)
		_backend.purchase_failed.disconnect(_on_purchase_failed)
		_backend.restored.disconnect(_on_restored)
		_backend.entitlements_synced.disconnect(_on_entitlements_synced)
	_backend = backend
	_backend.purchased.connect(_on_purchased)
	_backend.purchase_failed.connect(_on_purchase_failed)
	_backend.restored.connect(_on_restored)
	_backend.entitlements_synced.connect(_on_entitlements_synced)
	_backend.attach(self)
	_backend.initialize(PackedStringArray([remove_ads_id]))


func is_store_available() -> bool:
	return _backend.is_available()


func buy_remove_ads() -> void:
	_backend.purchase(remove_ads_id)


func restore_purchases() -> void:
	_backend.restore()


func _on_purchased(product_id: String) -> void:
	_grant(product_id)
	purchase_succeeded.emit(product_id)


func _on_purchase_failed(product_id: String, reason: String) -> void:
	purchase_failed.emit(product_id, reason)


func _on_restored(product_ids: PackedStringArray) -> void:
	for product_id: String in product_ids:
		_grant(product_id)
	restore_finished.emit(product_ids)


## Refunded or revoked purchases disappear from the store's list; take them back.
func _on_entitlements_synced(owned: PackedStringArray) -> void:
	for product_id: String in owned:
		_grant(product_id)
	if not owned.has(remove_ads_id) and save.get_bool("ads_removed"):
		save.set_bool("ads_removed", false)
		save.save()


func _grant(product_id: String) -> void:
	if product_id == remove_ads_id and not save.get_bool("ads_removed"):
		save.set_bool("ads_removed", true)
		save.save()

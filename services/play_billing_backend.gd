extends PurchaseBackend
## Google Play Billing through Godot's official plugin
## (addons/GodotGooglePlayBilling, v3.3.0, Billing Library 9.1).
## PurchaseService loads this only when the native plugin exists (Android builds).
##
## On connect it queries product details (required before purchase) and the
## player's existing purchases, so "remove ads" comes back after a reinstall.
## One-time purchases are acknowledged, otherwise Google refunds them after 3 days.
## A failed acknowledgement is retried on the next purchases query (every app start),
## and a successful query also revokes refunded purchases (entitlements_synced).

var _client: BillingClient
var _product_ids: PackedStringArray = []
var _products_ready: bool = false
var _pending_product: String = ""


func attach(host: Node) -> void:
	_client = BillingClient.new()
	host.add_child(_client)


func initialize(product_ids: PackedStringArray) -> void:
	_product_ids = product_ids
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_product_details)
	_client.query_purchases_response.connect(_on_purchases_queried)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.acknowledge_purchase_response.connect(_on_acknowledged)
	print("Billing: connecting")
	_client.start_connection()


func purchase(product_id: String) -> void:
	if not _client.is_ready() or not _products_ready:
		purchase_failed.emit.call_deferred(product_id, "store_not_ready")
		return
	_pending_product = product_id
	var result: Dictionary = _client.purchase(product_id)
	var code: int = int(result.get("response_code", -999))
	if code != BillingClient.BillingResponseCode.OK:
		print("Billing: purchase flow failed to launch: %d %s" % [code, result.get("debug_message", "")])
		_pending_product = ""
		purchase_failed.emit(product_id, "launch_failed_%d" % code)


func is_available() -> bool:
	return true


func restore() -> void:
	if not _client.is_ready():
		restored.emit.call_deferred(PackedStringArray())
		return
	_client.query_purchases(BillingClient.ProductType.INAPP)


func _on_connected() -> void:
	print("Billing: connected")
	_client.query_product_details(_product_ids, BillingClient.ProductType.INAPP)
	_client.query_purchases(BillingClient.ProductType.INAPP)


func _on_disconnected() -> void:
	print("Billing: disconnected")
	_products_ready = false


func _on_connect_error(code: int, message: String) -> void:
	print("Billing: connect error %d: %s" % [code, message])


func _on_product_details(response: Dictionary) -> void:
	var code: int = int(response.get("response_code", -999))
	var details: Array = response.get("product_details", [])
	print("Billing: product details response=%d, products=%d %s" % [code, details.size(), response.get("debug_message", "")])
	_products_ready = code == BillingClient.BillingResponseCode.OK and not details.is_empty()


func _on_purchases_queried(response: Dictionary) -> void:
	var code: int = int(response.get("response_code", -999))
	print("Billing: purchases query response=%d" % code)
	if code != BillingClient.BillingResponseCode.OK:
		restored.emit(PackedStringArray())
		return
	var owned: PackedStringArray = _owned_product_ids(response.get("purchases", []))
	entitlements_synced.emit(owned)
	restored.emit(owned)


func _on_purchase_updated(response: Dictionary) -> void:
	var code: int = int(response.get("response_code", -999))
	print("Billing: purchase updated response=%d" % code)
	var product: String = _pending_product
	_pending_product = ""
	if code == BillingClient.BillingResponseCode.OK:
		for product_id: String in _owned_product_ids(response.get("purchases", [])):
			purchased.emit(product_id)
	elif code == BillingClient.BillingResponseCode.USER_CANCELED:
		purchase_failed.emit(product, "canceled")
	elif code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
		purchased.emit(product)
	else:
		purchase_failed.emit(product, "error_%d" % code)


func _on_acknowledged(response: Dictionary) -> void:
	print("Billing: acknowledge response=%d" % int(response.get("response_code", -999)))


## Product ids of completed purchases. Acknowledges any that are not yet
## acknowledged. Pending purchases are skipped until they complete.
func _owned_product_ids(purchases: Array) -> PackedStringArray:
	var owned: PackedStringArray = []
	for entry: Dictionary in purchases:
		if int(entry.get("purchase_state", 0)) != BillingClient.PurchaseState.PURCHASED:
			continue
		if not bool(entry.get("is_acknowledged", false)):
			_client.acknowledge_purchase(str(entry.get("purchase_token", "")))
		for product_id: String in entry.get("product_ids", PackedStringArray()):
			owned.append(product_id)
	return owned

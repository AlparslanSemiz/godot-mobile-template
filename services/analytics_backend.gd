class_name AnalyticsBackend
extends RefCounted
## No-op analytics backend. Only AnalyticsService uses it.


func log_event(_event_name: String, _params: Dictionary) -> void:
	pass

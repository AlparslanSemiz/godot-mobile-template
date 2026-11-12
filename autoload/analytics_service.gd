class_name AnalyticsServiceNode
extends Node
## Game code logs events here; the backend decides where they go (nowhere by default).

var backend: AnalyticsBackend = AnalyticsBackend.new()


func log_event(event_name: String, params: Dictionary = {}) -> void:
	backend.log_event(event_name, params)

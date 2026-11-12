class_name GameOverScreen
extends Control
## Score, best, Retry and Menu.

signal retry_pressed
signal menu_pressed

## Buttons ignore taps this long, so a late in-game tap cannot hit Retry.
const INPUT_GUARD: float = 0.4

@onready var _card: Control = %Card
@onready var _score: Label = %Score
@onready var _best: Label = %Best
@onready var _new_best: Label = %NewBest
@onready var _retry: TapButton = %RetryButton
@onready var _menu: TapButton = %MenuButton
@onready var _extras: VBoxContainer = %Extras
@onready var _dim: ColorRect = $Dim

@onready var _default_dim: Color = _dim.color
@onready var _default_new_best: Color = _new_best.get_theme_color("font_color")


func _ready() -> void:
	hide()
	_retry.pressed.connect(retry_pressed.emit)
	_menu.pressed.connect(menu_pressed.emit)


func open(score: int, best: int, is_new_best: bool) -> void:
	for child: Node in _extras.get_children():
		_extras.remove_child(child)
		child.queue_free()
	_score.text = str(score)
	_best.text = "Best: %d" % best
	_new_best.visible = is_new_best
	_retry.disabled = true
	_menu.disabled = true
	show()
	modulate.a = 0.0
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.85, 0.85)
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.3)
	await get_tree().create_timer(INPUT_GUARD).timeout
	_retry.disabled = false
	_menu.disabled = false
	_set_extras_disabled(false)


## Optional look from the game: a Theme for the card (null = the project
## theme; Retry then uses the theme's "PrimaryButton" variation), the dim color
## and the "New best!" color (alpha 0 = the defaults).
func style(look: Theme, dim_color: Color, new_best_color: Color) -> void:
	theme = look
	_retry.theme_type_variation = &"PrimaryButton" if look != null else &""
	_dim.color = dim_color if dim_color.a > 0.0 else _default_dim
	_new_best.add_theme_color_override("font_color", new_best_color if new_best_color.a > 0.0 else _default_new_best)


func close() -> void:
	hide()


## Call after adding controls to extras(): their buttons follow the same input
## guard as Retry and Menu.
func guard_extras() -> void:
	_set_extras_disabled(_retry.disabled)


func _set_extras_disabled(value: bool) -> void:
	for button: Node in _extras.find_children("*", "BaseButton", true, false):
		(button as BaseButton).disabled = value


## Empty box on the card for game-specific controls; cleared on every open().
func extras() -> VBoxContainer:
	return _extras


## Smoke/capture driver uses this to find where to tap.
func retry_button() -> TapButton:
	return _retry

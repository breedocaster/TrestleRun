## Coin icon + live wallet amount.
extends Control

const Icons := preload("res://scripts/game/icons.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")

var _shown := -1
var _pulse := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(max(custom_minimum_size.x, 64), 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.money_changed.connect(func(_m): _pulse = 1.0)
	_shown = GameState.money()


func _process(delta: float) -> void:
	var target := GameState.money()
	if _shown != target:
		var diff := target - _shown
		_shown += signi(diff) * maxi(1, absi(diff) / 12)
	_pulse = maxf(0.0, _pulse - delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var font: Font = GameState.font
	var text := str(_shown)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w := tw + 24.0
	var x0 := size.x - w
	var y0 := floorf(size.y * 0.5 - 8)
	draw_rect(Rect2(x0, y0, w, 16), Color(UITheme.INK, 0.85))
	draw_rect(Rect2(x0, y0, w, 16), UITheme.GOLD if _pulse > 0.0 else Color("5a4a6e"), false, 1.0)
	Icons.coin(self, Vector2(x0 + 9, y0 + 8), 1.0)
	draw_string(font, Vector2(x0 + 17, y0 + 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UITheme.CREAM)

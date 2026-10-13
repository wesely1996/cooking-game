extends Control
## The loading screen: the Night Forge logo on the night sky, continuing the
## boot splash. It fades out into the cover after a moment; a tap skips it.

const HOLD_SECONDS := 1.6
const FADE_SECONDS := 0.35

var _time := 0.0
var _leaving := false
var _logo: Texture2D


func _ready() -> void:
	_logo = Brand.logo()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _time >= HOLD_SECONDS + FADE_SECONDS:
		_leave()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	Game.goto(Game.SCENE_MENU)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Brand.NIGHT)
	if _logo == null:
		return
	# A soft glow behind the logo, gently breathing.
	var center := size * 0.5
	var side := minf(size.y * 0.78, size.x * 0.6)
	for i in 6:
		var radius := side * (0.18 + i * 0.05) * (1.0 + 0.03 * sin(_time * 3.0))
		draw_circle(center + Vector2(0, -side * 0.12), radius, Color(Brand.GLOW, 0.035))
	var fade := clampf(_time / 0.3, 0.0, 1.0) * clampf((HOLD_SECONDS + FADE_SECONDS - _time) / FADE_SECONDS, 0.0, 1.0)
	draw_texture_rect(_logo, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color(1, 1, 1, fade))

class_name ChefPortrait
extends Control
## Shows a chef (see ChefLook) filling this control.

var look := {}:
	set(value):
		look = value
		queue_redraw()
var mood := 1.0


func _draw() -> void:
	ChefLook.draw(self, size * 0.5 + Vector2(0, size.y * 0.08), size.y * 0.78, look, mood)

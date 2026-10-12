class_name ChefView
extends SubViewportContainer
## A player's 3D chef (Models.chef) with the comic look, standing in a little
## world of its own, for menus: the cover, the profile page, the lobby.

## The chef's look (see ChefLook). Setting it rebuilds the chef.
var look := {}:
	set(value):
		look = value
		_rebuild()
## How much shows, in chef heights: 1.5 is the whole chef and the hat.
var framing := 1.5:
	set(value):
		framing = value
		_place_camera()

var _viewport: SubViewport
var _camera: Camera3D
var _chef: Node3D


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 28.0
	_viewport.add_child(_camera)
	_camera.current = true
	_place_camera()


## Plays one of the character animations ("emote-yes", "pick-up"...).
func act(animation: String) -> void:
	if _chef:
		Models.animate(_chef, animation)


func _rebuild() -> void:
	if _chef:
		_chef.queue_free()
	_chef = Models.chef(look)
	_chef.rotation.y = -0.35
	_viewport.add_child(_chef)
	Models.animate(_chef, "idle", true)


func _place_camera() -> void:
	var height := Models.CHARACTER_HEIGHT
	# The hat sits well above the head: centre a little high.
	var target := Vector3(0, height * 0.62, 0)
	var distance := height * framing / (2.0 * tan(deg_to_rad(_camera.fov) * 0.5)) * 1.15
	var eye := target + Vector3(0, height * 0.12, distance)
	_camera.transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)

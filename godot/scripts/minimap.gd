extends Control
signal selected(point: Vector2)
var world: NativeWorld
var texture: Texture2D=load("res://assets/map/paper.webp")
func _process(_delta: float):
	queue_redraw()
func map_rect() -> Rect2:
	if world==null:
		return Rect2()
	var factor=minf((size.x-12)/world.map.width,(size.y-10)/world.map.height)
	var extent=Vector2(world.map.width,world.map.height)*factor
	return Rect2((size-extent)/2,extent)
func _draw():
	if world==null:
		return
	draw_style_box(_panel(),Rect2(Vector2.ZERO,size))
	var rectangle=map_rect()
	draw_texture_rect(texture,rectangle,false,Color(1,1,1,.75))
	var p=rectangle.position+world.player.position*rectangle.size/Vector2(world.map.width,world.map.height)
	draw_circle(p,3,Color("#cc7d48"))
func _panel() -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=Color("#edf0e4")
	style.corner_radius_top_left=7
	style.corner_radius_top_right=7
	style.corner_radius_bottom_left=7
	style.corner_radius_bottom_right=7
	return style
func _gui_input(event: InputEvent):
	if world!=null and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var rectangle=map_rect()
		if rectangle.has_point(event.position):
			selected.emit((event.position-rectangle.position)/rectangle.size*Vector2(world.map.width,world.map.height))

extends SubViewportContainer
signal destination(point: Vector2)
signal pan_requested(delta: Vector2)
signal zoom_requested(factor: float,at: Vector2)
var camera: Camera2D
var dragging=false
var last_mouse=Vector2.ZERO
func _gui_input(event: InputEvent):
	if camera==null:
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
			dragging=event.pressed
			last_mouse=event.position
			accept_event()
		elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:
			zoom_requested.emit(1.2,event.position)
			accept_event()
		elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			zoom_requested.emit(1.0/1.2,event.position)
			accept_event()
		elif event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			var viewport=get_child(0) as SubViewport
			var point=viewport.get_canvas_transform().affine_inverse()*event.position
			destination.emit(point)
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		pan_requested.emit(event.position-last_mouse)
		last_mouse=event.position
		accept_event()

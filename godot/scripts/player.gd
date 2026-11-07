class_name NativePlayer
extends CharacterBody2D
signal events_fired(events: Array)
var map: NativeMapData
var state: NativeRules
var speed=110.0
var radius=.65
var paused=false
var route=PackedVector2Array()
var route_index=0
var assistance=true
var last_input=Vector2.ZERO
var moved_total=0.0
func configure(data: NativeMapData,rules: NativeRules):
	map=data
	state=rules
	position=state.position
	collision_layer=2
	collision_mask=1
	motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	safe_margin=.02
	var shape=CircleShape2D.new()
	shape.radius=radius
	var collider=CollisionShape2D.new()
	collider.shape=shape
	add_child(collider)
func set_route(points: PackedVector2Array):
	route=points
	route_index=0
func cancel_route():
	route=PackedVector2Array()
	route_index=0
func desired_motion(manual: Vector2,delta: float) -> Vector2:
	if manual.length_squared()>.001:
		cancel_route()
		var direction=manual.normalized()
		if assistance and not map.near_junction(position):
			var center=map.center_at(position)
			var toward=center-position
			if toward.length()>.1 and toward.length()<3.0 and map.segment_clear(position,center,state):
				var lateral=toward-direction*toward.dot(direction)
				direction=(direction+lateral.limit_length(1.0)*.16).normalized()
		return direction*speed*delta
	while route_index<route.size() and position.distance_to(route[route_index])<.12:
		route_index+=1
	if route_index>=route.size():
		return Vector2.ZERO
	return (route[route_index]-position).limit_length(speed*delta)
func advance(manual: Vector2,delta: float) -> Array:
	if paused or state.won:
		return []
	last_input=manual
	var result=[]
	var remaining_time=delta
	var pieces=0
	while remaining_time>.000001 and pieces<128 and not state.won:
		pieces+=1
		var motion=desired_motion(manual,remaining_time)
		if motion.length_squared()<.0001:
			break
		var events=_move_piece(motion,manual==Vector2.ZERO)
		result.append_array(events)
		remaining_time-=motion.length()/speed
		if manual.length_squared()>.001 or events.any(func(e):return e.type in ["portal","wall","locked","goalLocked","routeBlocked"]):
			break
	return result
func _move_piece(motion: Vector2,automatic: bool) -> Array:
	var result=state.open_near(position)
	if not result.is_empty():
		events_fired.emit(result)
	var before=position
	var remaining=motion
	var guard=0
	while remaining.length()>.0001 and guard<4:
		guard+=1
		var collision=move_and_collide(remaining,false,safe_margin)
		if collision==null:
			break
		remaining=collision.get_remainder().slide(collision.get_normal())
	var events=state.move_to(position)
	if not events.is_empty() and events[0].type in ["wall","locked","goalLocked"]:
		position=before
		state.position=before
	else:
		position=state.position
		if events.any(func(e):return e.type=="portal"):
			cancel_route()
	moved_total+=before.distance_to(position)
	if route_index<route.size() and before.distance_to(position)<minf(.005,motion.length()*.1) and automatic:
		cancel_route()
		events.append({"type":"routeBlocked"})
	result.append_array(events)
	if not events.is_empty():
		events_fired.emit(events)
	return result

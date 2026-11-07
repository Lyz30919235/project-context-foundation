class_name NativeWorld
extends Node2D
var map: NativeMapData
var state: NativeRules
var player: NativePlayer
var camera: Camera2D
var door_bodies: Dictionary={}
var goal_body: StaticBody2D
var visual: Node2D
func configure(data: NativeMapData,rules: NativeRules,with_visual: bool=true):
	map=data
	state=rules
	for chunk in map.collisions.values():
		var body=StaticBody2D.new()
		body.collision_layer=1
		body.collision_mask=2
		var shape=ConcavePolygonShape2D.new()
		var segments=PackedVector2Array()
		segments.resize(chunk.size()/2)
		for i in range(0,chunk.size(),2):
			segments[i/2]=Vector2(chunk[i],chunk[i+1])
		shape.segments=segments
		var collider=CollisionShape2D.new()
		collider.shape=shape
		body.add_child(collider)
		add_child(body)
	for door in state.level.doors:
		var body=StaticBody2D.new()
		body.collision_layer=1
		body.collision_mask=2
		var rectangle=state.rect(door)
		body.position=rectangle.get_center()
		var shape=RectangleShape2D.new()
		shape.size=rectangle.size
		var collider=CollisionShape2D.new()
		collider.shape=shape
		body.add_child(collider)
		add_child(body)
		door_bodies[str(door.id)]=body
	goal_body=StaticBody2D.new()
	goal_body.position=map.point(state.level.goal)
	goal_body.collision_layer=1
	goal_body.collision_mask=2
	var goal_shape=CircleShape2D.new()
	goal_shape.radius=float(state.level.goal.get("radius",4))
	var goal_collision=CollisionShape2D.new()
	goal_collision.shape=goal_shape
	goal_body.add_child(goal_collision)
	add_child(goal_body)
	player=NativePlayer.new()
	add_child(player)
	player.configure(map,state)
	player.events_fired.connect(_on_events)
	camera=Camera2D.new()
	camera.position=player.position
	camera.position_smoothing_enabled=true
	camera.position_smoothing_speed=12
	add_child(camera)
	if with_visual:
		var sprite=Sprite2D.new()
		sprite.texture=load("res://assets/map/paper.webp")
		sprite.centered=false
		sprite.z_index=-5
		add_child(sprite)
		visual=load("res://scripts/visual.gd").new()
		visual.world=self
		add_child(visual)
	sync_doors()
func _on_events(_events: Array):
	sync_doors()
func sync_doors():
	for id in door_bodies:
		door_bodies[id].collision_layer=0 if state.opened.has(id) else 1
	if goal_body!=null:
		goal_body.collision_layer=0 if state.all_stars() else 1

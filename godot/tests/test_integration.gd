extends SceneTree
var failures=[]
var checks=0
func expect(condition: bool,name: String):
	checks+=1
	if condition:
		print("PASS: ",name)
	else:
		failures.append(name)
		push_error(name)
func _initialize():
	call_deferred("run")
func run():
	var scene=load("res://main.tscn")
	var app=scene.instantiate()
	app.save_path="user://automated-native-test.json"
	root.add_child(app)
	while not app.ready_game:
		await process_frame
	app._restart()
	await process_frame
	expect(app.camera_zoom*app.map.height<=app.viewport.size.y+1,"overview fits complete map height")
	expect(app.world.camera.position.distance_to(Vector2(app.map.width,app.map.height)/2)<1,"overview centered")
	expect(app.font.has_char(0x8ff7) and app.font.has_char(0x661f),"bundled font has maze and star Chinese glyphs")
	app._start()
	var initial=app.world.player.position
	var event=InputEventKey.new()
	event.physical_keycode=KEY_D
	event.keycode=KEY_D
	event.pressed=true
	Input.parse_input_event(event)
	for i in range(12):
		await physics_frame
	event.pressed=false
	Input.parse_input_event(event)
	expect(app.state.distance>0 or app.world.player.position!=initial,"keyboard events drive physical player")
	app.world.player.set_route(PackedVector2Array([app.state.position,app.state.position+Vector2(1,0)]))
	app.world.player.desired_motion(Vector2.LEFT,.016)
	expect(app.world.player.route.is_empty(),"keyboard takes over click route")
	app._pause()
	var before=app.world.player.position
	var elapsed_before=app.elapsed
	for i in range(5):
		await physics_frame
	expect(app.world.player.position==before and is_equal_approx(app.elapsed,elapsed_before),"pause stops movement and timer")
	expect(app.modal.visible,"pause screen visible")
	app._resume()
	expect(not app.paused and not app.modal.visible,"resume closes pause screen")
	app._zoom(1.2,app.board.size/2)
	expect(app.camera_zoom>2.8,"mouse zoom changes scale")
	app._locate()
	var half=Vector2(app.viewport.size)/(2*app.camera_zoom)
	expect(app.world.camera.position.x>=half.x-.01 and app.world.camera.position.y<=app.map.height-half.y+.01,"follow camera clamped to map")
	app._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(app.paused and not Input.is_action_pressed("map_right"),"focus loss pauses and releases input")
	app.elapsed=125
	app.state.keys["2"]=true
	app._save()
	var saved=JSON.parse_string(FileAccess.get_file_as_string(app.save_path))
	expect(saved.state.keys.has("2") and saved.elapsed==125,"native save persists progress to disk")
	app.state=NativeRules.new(app.map)
	app._restore()
	expect(app.state.keys.has("2") and app.elapsed==125,"native save restores progress")
	var report={"suite":"native_ui_integration","checks":checks,"failures":failures,"window_size":[root.size.x,root.size.y],"viewport_size":[app.viewport.size.x,app.viewport.size.y],"board_size":[app.board.size.x,app.board.size.y]}
	print(JSON.stringify(report))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

extends SceneTree
var world: NativeWorld
var nav: NativeNavigation
var events_seen=[]
func _initialize():
	call_deferred("run")
func run():
	var started=Time.get_ticks_msec()
	var map=NativeMapData.new()
	var state=NativeRules.new(map)
	world=NativeWorld.new()
	root.add_child(world)
	world.configure(map,state,false)
	nav=NativeNavigation.new(map,state)
	world.player.events_fired.connect(func(events):
		for event in events:
			events_seen.append(event)
	)
	await physics_frame
	await process_frame
	var landing_checks=[]
	for portal in state.level.portals:
		var query=PhysicsShapeQueryParameters2D.new()
		query.shape=world.player.get_child(0).shape
		query.transform=Transform2D(0,map.point(portal))
		query.collision_mask=1
		var hits=world.get_world_2d().direct_space_state.intersect_shape(query)
		landing_checks.append({"portal":int(portal.number),"clear":hits.is_empty()})
		if not hits.is_empty():
			push_error("Portal landing intersects native collision: "+str(portal.number))
			world.queue_free()
			await process_frame
			quit(1)
			return
	var moves=0
	var stages=[]
	var failed=""
	for phase in range(70):
		if state.won:
			break
		nav.refresh_access()
		var targets=[]
		for item in state.level.keys:
			if not state.keys.has(str(item.id)):
				targets.append(item)
		for item in state.level.stars:
			if not state.stars.has(str(item.id)):
				targets.append(item)
		if state.all_stars():
			var goal=state.level.goal.duplicate()
			goal.id="goal"
			targets.append(goal)
		targets.sort_custom(func(a,b):return map.point(a).distance_squared_to(state.position)<map.point(b).distance_squared_to(state.position))
		var progressed=false
		var last_stuck={}
		for target in targets:
			var before_count=state.keys.size()+state.stars.size()+state.opened.size()
			var path=nav.path_to(map.point(target))
			if path.is_empty():
				continue
			world.player.set_route(path)
			var iterations=0
			var teleported=false
			var old_events=events_seen.size()
			while world.player.route_index<world.player.route.size() and iterations<250000 and not state.won:
				iterations+=1
				moves+=1
				var events=world.player.advance(Vector2.ZERO,1.0/240.0)
				if events.any(func(e):return e.type=="door"):
					await physics_frame
					await process_frame
				if events.any(func(e):return e.type=="portal"):
					teleported=true
					break
				if events.any(func(e):return e.type=="routeBlocked"):
					last_stuck={"target":str(target.id),"position":[world.player.position.x,world.player.position.y],"point":str(path[mini(world.player.route_index,path.size()-1)])}
					break
			var gain=state.keys.size()+state.stars.size()+state.opened.size()>before_count or state.won
			stages.append({"target":str(target.id),"iterations":iterations,"progress":gain,"teleport":teleported,"position":[world.player.position.x,world.player.position.y]})
			print("STAGE ",JSON.stringify(stages[-1]))
			if gain or teleported:
				progressed=true
				break
		if not progressed:
			failed="No further physical route: "+JSON.stringify(last_stuck)
			break
	var report={"won":state.won,"stars":state.stars.keys(),"keys":state.keys.keys(),"doors":state.opened.keys(),"physical_steps":moves,"distance":state.distance,"stages":stages,"failure":failed,"duration_ms":Time.get_ticks_msec()-started,"radius":world.player.radius,"portal_landings":landing_checks}
	var output=FileAccess.open("res://../work/native/full-map-report.json",FileAccess.WRITE)
	if output!=null:
		output.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	world.queue_free()
	await process_frame
	quit(0 if state.won and state.keys.size()==5 else 1)

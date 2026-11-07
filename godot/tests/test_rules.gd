extends SceneTree
var failures=[]
var checks=0
func _initialize():
	call_deferred("run")
func expect(condition: bool,name: String):
	checks+=1
	if not condition:
		failures.append(name)
		push_error("FAILED: "+name)
	else:
		print("PASS: "+name)
func fixture(extra: Dictionary={}) -> NativeRules:
	var level={"version":"test","width":12,"height":5,"walls":PackedByteArray([0,0,0,0,0,0,0,0]),"start":{"x":0,"y":2},"goal":{"x":11,"y":2,"radius":1},"stars":[{"id":"s1","x":3,"y":2,"radius":1}],"keys":[],"doors":[],"portals":[],"questions":[]}
	level.merge(extra,true)
	return NativeRules.new(NativeMapData.new(level))
func run():
	var s=fixture()
	s.map.walls[3]=s.map.walls[3]|2
	expect(s.move_to(Vector2(1,2))[0].type=="wall" and s.position==Vector2(0,2),"01 walls block movement")
	s=fixture()
	expect(s.move_to(Vector2(10,2))[0].type=="goalLocked","02 goal locked before collection")
	s.stars["s1"]=true
	expect(s.move_to(Vector2(10,2)).any(func(e):return e.type=="win"),"03 goal unlocks after all stars")
	s=fixture()
	s.position=Vector2(3,2)
	expect(s.interact().size()==1 and s.interact().is_empty(),"04 stars collected only once")
	s=fixture({"doors":[{"id":"2","key":"2","rect":[4,0,1,5]}]})
	s.keys["1"]=true
	expect(s.move_to(Vector2(4,2))[0].type=="locked" and s.keys.has("1"),"05 wrong key cannot open door")
	s.keys["2"]=true
	expect(s.move_to(Vector2(4,2))[0].type=="door" and s.keys.has("2") and s.opened.has("2"),"06 matching key remains reusable")
	s=fixture({"doors":[{"id":"345","requiredKeys":["3","4","5"],"rect":[4,0,1,5]}]})
	s.keys={"3":true,"4":true}
	expect(s.move_to(Vector2(4,2))[0].keys==["5"],"07 multi-key gate requires all keys")
	s.keys["5"]=true
	expect(s.move_to(Vector2(4,2))[0].type=="door" and s.keys.size()==3,"08 multi-key gate preserves keys")
	s=fixture({"portals":[{"id":"p1","number":1,"x":1,"y":2,"radius":1},{"id":"p2","number":2,"x":5,"y":2,"radius":1},{"id":"p3","number":3,"x":9,"y":2,"radius":1}]})
	s.move_to(Vector2(1,2))
	s.interact()
	expect(s.position==Vector2(5,2),"09 portal lands n+1 without chained jumps")
	s.position=Vector2(7,0)
	s.interact()
	s.position=Vector2(5,2)
	s.interact()
	expect(s.position==Vector2(9,2) and s.interact().is_empty(),"10 leave/reenter and last portal")
	s=fixture({"questions":[{"id":"q1","x":1,"y":2,"radius":1}]})
	var events=s.move_to(Vector2(1,2))
	expect(events.any(func(e):return e.type=="question") and s.keys.is_empty() and s.stars.is_empty(),"11 question contains no items")
	s=fixture()
	s.position=Vector2(3,2)
	s.interact()
	s.distance=10
	var copy=fixture()
	expect(copy.restore(s.snapshot()) and copy.stars.size()==1 and copy.distance==10,"12 save restores progress")
	var old=s.snapshot()
	old.version="old"
	expect(not fixture().restore(old),"13 another map version rejected")
	s=fixture({"doors":[{"id":"1","key":"1","rect":[4,0,1,5]}]})
	s.map.graph={"nodes":[[0,2],[3,2],[5,2],[8,2]],"edges":[[0,1,3,[[0,2],[3,2]],[]],[1,2,2,[[3,2],[5,2]],["1"]],[2,3,3,[[5,2],[8,2]],[]]]}
	var nav=NativeNavigation.new(s.map,s)
	expect(nav.path_to(Vector2(8,2)).is_empty(),"14 navigator respects locked doors")
	s.keys["1"]=true
	nav.refresh_access()
	expect(not nav.path_to(Vector2(8,2)).is_empty(),"15 navigator opens matching-key route")
	var small=fixture({"width":8,"height":1,"walls":PackedByteArray([0x85]),"start":{"x":1,"y":0},"goal":{"x":7,"y":0}})
	expect(not small.map.floor_at(Vector2(0,0)) and small.map.floor_at(Vector2(1,0)) and not small.map.floor_at(Vector2(7,0)),"16 little-endian collision bits")
	s=fixture()
	var player=NativePlayer.new()
	root.add_child(player)
	player.configure(s.map,s)
	player.assistance=false
	var straight=player.desired_motion(Vector2.RIGHT,.1).length()
	var diagonal=player.desired_motion(Vector2.ONE,.1).length()
	expect(is_equal_approx(straight,diagonal),"17 diagonal speed normalized")
	player.set_route(PackedVector2Array([Vector2(5,2)]))
	player.desired_motion(Vector2.LEFT,.1)
	expect(player.route.is_empty(),"18 manual input cancels auto-walk")
	player.position=Vector2(0,2)
	s.position=player.position
	var dense_route=PackedVector2Array()
	for i in range(81):
		dense_route.append(Vector2(i*.1,2))
	player.set_route(dense_route)
	player.advance(Vector2.ZERO,.05)
	expect(absf(player.position.x-5.5)<.1,"19 auto-walk speed independent of waypoint density")
	player.paused=true
	var before=player.position
	player.advance(Vector2.RIGHT,1)
	expect(player.position==before,"20 paused movement is ignored")
	player.queue_free()
	await physics_frame
	var walls=PackedByteArray()
	walls.resize(50)
	for y in range(20):
		var index=y*20+10
		walls[index>>3]=int(walls[index>>3])|(1<<(index&7))
	s=fixture({"width":20,"height":20,"walls":walls,"start":{"x":3,"y":3},"goal":{"x":19,"y":19},"stars":[{"id":"s1","x":17,"y":17,"radius":1}]})
	var body=StaticBody2D.new()
	body.position=Vector2(10,10)
	body.collision_layer=1
	var box=CollisionShape2D.new()
	var shape=RectangleShape2D.new()
	shape.size=Vector2(1,20)
	box.shape=shape
	body.add_child(box)
	root.add_child(body)
	player=NativePlayer.new()
	root.add_child(player)
	player.configure(s.map,s)
	player.assistance=false
	await physics_frame
	await process_frame
	player.advance(Vector2.ONE,.12)
	expect(player.position.x<9.4 and player.position.y>5,"21 actual circular body slides along wall")
	player.queue_free()
	body.queue_free()
	await process_frame
	print(JSON.stringify({"suite":"native_rules_and_movement","checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

extends Node2D
var world: NativeWorld
var font: Font=load("res://assets/NotoSansCJKsc-Regular.otf")
var trail=PackedVector2Array()
var pulse=0.0
func _process(delta: float):
	pulse+=delta
	if world.player!=null and (trail.is_empty() or trail[-1].distance_to(world.player.position)>.8):
		trail.append(world.player.position)
		if trail.size()>4000:
			trail.remove_at(0)
	queue_redraw()
func label_at(p: Vector2,text: String,color: Color,zoom: float):
	var size=maxi(5,int(12.0/zoom))
	var text_size=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size)
	draw_string(font,p-Vector2(text_size.x*.5,-text_size.y*.27),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func star(p: Vector2,radius: float,color: Color):
	var points=PackedVector2Array()
	for i in range(10):
		var angle=-PI/2+i*PI/5
		points.append(p+Vector2(cos(angle),sin(angle))*radius*(1.0 if i%2==0 else .42))
	draw_colored_polygon(points,color)
func _draw():
	if world==null or world.player==null:
		return
	var state=world.state
	var zoom=maxf(.1,world.camera.zoom.x)
	if trail.size()>1 and zoom>.7:
		for i in range(1,trail.size()):
			if trail[i-1].distance_to(trail[i])<8:
				draw_line(trail[i-1],trail[i],Color("#c8874750"),1.5/zoom,true)
	if world.player.route_index<world.player.route.size():
		var previous=world.player.position
		for i in range(world.player.route_index,world.player.route.size()):
			var p=world.player.route[i]
			draw_line(previous,p,Color("#d39c5380"),1.5/zoom,true)
			previous=p
	for door in state.level.doors:
		if not state.opened.has(str(door.id)):
			draw_rect(state.rect(door),Color("#b98263b8"))
			draw_rect(state.rect(door),Color("#f9f0d2"),false,.6)
	for item in state.level.stars:
		if not state.stars.has(str(item.id)):
			var p=world.map.point(item)
			draw_circle(p,10/zoom,Color("#fff6dfd9"))
			star(p,7.5/zoom,Color("#bd872c"))
	for item in state.level.keys:
		if not state.keys.has(str(item.id)):
			var p=world.map.point(item)
			draw_circle(p,8/zoom,Color("#e8efdcf0"))
			draw_arc(p,8/zoom,0,TAU,24,Color("#78916b"),1/zoom,true)
			label_at(p,str(item.id),Color("#526e45"),zoom)
	for portal in state.level.portals:
		var p=world.map.point(portal)
		draw_circle(p,9/zoom,Color("#d7e8dbdc"))
		draw_arc(p,8/zoom,pulse,TAU+pulse-.7,24,Color("#557f63"),1/zoom,true)
		label_at(p,str(portal.number),Color("#526e45"),zoom)
	for item in state.level.questions:
		var p=world.map.point(item)
		draw_circle(p,6/zoom,Color("#e4e6dad9"))
		label_at(p,"?",Color("#849278"),zoom)
	var start=world.map.point(state.level.start)
	draw_arc(start,10/zoom,0,TAU,24,Color("#c87d45"),1/zoom,true)
	var goal=world.map.point(state.level.goal)
	draw_circle(goal,11/zoom,Color("#e6eddc"))
	label_at(goal,"终" if state.all_stars() else "锁",Color("#667c55"),zoom)
	var p=world.player.position
	draw_circle(p,(9+sin(pulse*2)*1.0)/zoom,Color("#d58a3524"))
	draw_circle(p,5.8/zoom,Color("#fff9e9"))
	draw_arc(p,5.8/zoom,0,TAU,24,Color("#cc7a42"),1.5/zoom,true)
	draw_circle(p,maxf(.7,2.4/zoom),Color("#cd7a43"))

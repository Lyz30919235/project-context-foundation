class_name NativeNavigation
extends RefCounted
var map: NativeMapData
var state: NativeRules
var astar=AStar2D.new()
var buckets: Dictionary={}
var nodes: Array
var edges: Array
var connections: Dictionary={}
func _init(data: NativeMapData,rules: NativeRules):
	map=data
	state=rules
	nodes=map.graph.get("nodes",[])
	edges=map.graph.get("edges",[])
	for i in range(nodes.size()):
		var p=Vector2(nodes[i][0],nodes[i][1])
		astar.add_point(i,p)
		var bucket=Vector2i(p/64.0)
		if not buckets.has(bucket):
			buckets[bucket]=[]
		buckets[bucket].append(i)
	refresh_access()
func refresh_access():
	for index in range(edges.size()):
		var edge=edges[index]
		var allowed=true
		for id in edge[4]:
			for door in state.level.doors:
				if str(door.id)==str(id) and not state.opened.has(str(id)) and not state.missing_keys(door).is_empty():
					allowed=false
		var a=int(edge[0])
		var b=int(edge[1])
		if allowed and not astar.are_points_connected(a,b):
			astar.connect_points(a,b)
			connections[Vector2i(a,b)]=index
			connections[Vector2i(b,a)]=index
		elif not allowed and astar.are_points_connected(a,b):
			astar.disconnect_points(a,b)
func nearest_node(p: Vector2) -> int:
	var center=map.center_at(p)
	var best=-1
	var best_distance=INF
	for origin in [center,p]:
		var bucket=Vector2i(origin/64.0)
		for dy in range(-1,2):
			for dx in range(-1,2):
				for id in buckets.get(bucket+Vector2i(dx,dy),[]):
					var q=astar.get_point_position(id)
					var distance=p.distance_squared_to(q)
					if distance<best_distance and map.segment_clear(p,q,state):
						best_distance=distance
						best=id
		if best>=0:
			break
	return best
func path_to(target: Vector2,from: Vector2=Vector2.INF) -> PackedVector2Array:
	if from==Vector2.INF:
		from=state.position
	var end=map.nearest_floor(target,12)
	if end==Vector2.INF or not state.traversable(end):
		return PackedVector2Array()
	var start_id=nearest_node(from)
	var end_id=nearest_node(end)
	if start_id<0 or end_id<0:
		return PackedVector2Array()
	var ids=astar.get_id_path(start_id,end_id)
	if ids.is_empty():
		return PackedVector2Array()
	var path=PackedVector2Array([from,astar.get_point_position(start_id)])
	for i in range(1,ids.size()):
		var a=int(ids[i-1])
		var b=int(ids[i])
		var index=int(connections.get(Vector2i(a,b),-1))
		if index<0:
			return PackedVector2Array()
		var edge=edges[index]
		var points=edge[3].duplicate()
		if int(edge[0])!=a:
			points.reverse()
		for p in points:
			var q=Vector2(p[0],p[1])
			if path.is_empty() or path[-1].distance_to(q)>.01:
				path.append(q)
	if map.segment_clear(path[-1],end,state):
		path.append(end)
	return path

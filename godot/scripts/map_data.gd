class_name NativeMapData
extends RefCounted
var level: Dictionary
var width: int
var height: int
var walls: PackedByteArray
var centers: PackedByteArray
var junctions: PackedByteArray
var clearance: PackedByteArray
var collisions: Dictionary
var graph: Dictionary
func _init(custom: Dictionary = {}):
	if not custom.is_empty():
		level=custom
		width=int(level.width)
		height=int(level.height)
		walls=level.get("walls",PackedByteArray())
		return
	level=JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/level.json"))
	width=int(level.width)
	height=int(level.height)
	walls=FileAccess.get_file_as_bytes("res://assets/map/walls.bits")
	junctions=FileAccess.get_file_as_bytes("res://assets/map/junctions.bits")
	centers=FileAccess.get_file_as_bytes("res://assets/map/centers.gz").decompress(width*height*4,FileAccess.COMPRESSION_GZIP)
	clearance=FileAccess.get_file_as_bytes("res://assets/map/clearance.gz").decompress(width*height,FileAccess.COMPRESSION_GZIP)
	collisions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/collision.json"))
	graph=JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/graph.json"))
func point(item: Dictionary) -> Vector2:
	return Vector2(float(item.x),float(item.y))
func floor_at(p: Vector2) -> bool:
	var x=int(round(p.x))
	var y=int(round(p.y))
	if x<0 or y<0 or x>=width or y>=height:
		return false
	var id=y*width+x
	return walls.size()>(id>>3) and (int(walls[id>>3])&(1<<(id&7)))==0
func center_at(p: Vector2) -> Vector2:
	if centers.is_empty():
		return p
	var x=clampi(int(round(p.x)),0,width-1)
	var y=clampi(int(round(p.y)),0,height-1)
	var id=(y*width+x)*4
	return Vector2(centers.decode_u16(id),centers.decode_u16(id+2))
func near_junction(p: Vector2) -> bool:
	if junctions.is_empty():
		return false
	var x=clampi(int(round(p.x)),0,width-1)
	var y=clampi(int(round(p.y)),0,height-1)
	var id=y*width+x
	return (int(junctions[id>>3])&(1<<(id&7)))!=0
func segment_clear(a: Vector2,b: Vector2,state = null) -> bool:
	var count=maxi(1,int(ceil(a.distance_to(b)*2.0)))
	for i in range(count+1):
		var p=a.lerp(b,float(i)/count)
		if not floor_at(p):
			return false
		if state!=null and not state.traversable(p):
			return false
	return true
func nearest_floor(p: Vector2,max_radius: int=30) -> Vector2:
	var rounded=p.round()
	for radius in range(max_radius+1):
		var best=Vector2.INF
		var dist=INF
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				if radius>0 and absi(x)!=radius and absi(y)!=radius:
					continue
				var q=rounded+Vector2(x,y)
				if floor_at(q) and q.distance_squared_to(p)<dist:
					dist=q.distance_squared_to(p)
					best=q
		if best!=Vector2.INF:
			return best
	return Vector2.INF

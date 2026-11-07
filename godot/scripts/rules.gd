class_name NativeRules
extends RefCounted
var map: NativeMapData
var level: Dictionary
var position: Vector2
var stars: Dictionary={}
var keys: Dictionary={}
var opened: Dictionary={}
var questions: Dictionary={}
var suppressed=""
var distance=0.0
var won=false
func _init(data: NativeMapData):
	map=data
	level=map.level
	position=map.point(level.start)
func all_stars() -> bool:
	return stars.size()==level.stars.size()
func required(door: Dictionary) -> Array:
	return door.get("requiredKeys",[door.get("key","")])
func rect(door: Dictionary) -> Rect2:
	var r=door.rect
	return Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3]))
func near(p: Vector2,item: Dictionary,extra: float=0.0) -> bool:
	return p.distance_squared_to(map.point(item))<=pow(float(item.get("radius",2))+extra,2)
func missing_keys(door: Dictionary) -> Array:
	var missing=[]
	for key in required(door):
		if not keys.has(str(key)):
			missing.append(str(key))
	return missing
func traversable(p: Vector2) -> bool:
	if not map.floor_at(p):
		return false
	for door in level.get("doors",[]):
		if rect(door).has_point(p) and not opened.has(str(door.id)) and not missing_keys(door).is_empty():
			return false
	return all_stars() or not near(p,level.goal)
func open_near(p: Vector2,distance_to_door: float=3.0) -> Array:
	var events=[]
	for door in level.get("doors",[]):
		var id=str(door.id)
		if not opened.has(id) and rect(door).grow(distance_to_door).has_point(p) and missing_keys(door).is_empty():
			opened[id]=true
			events.append({"type":"door","id":id,"keys":required(door)})
	return events
func move_to(p: Vector2) -> Array:
	if won:
		return []
	if not map.floor_at(p):
		return [{"type":"wall"}]
	var events=[]
	for door in level.get("doors",[]):
		if not rect(door).has_point(p) or opened.has(str(door.id)):
			continue
		var missing=missing_keys(door)
		if not missing.is_empty():
			return [{"type":"locked","id":str(door.id),"keys":missing}]
		opened[str(door.id)]=true
		events.append({"type":"door","id":str(door.id),"keys":required(door)})
	if not all_stars() and near(p,level.goal):
		return [{"type":"goalLocked","remaining":level.stars.size()-stars.size()}]
	distance+=position.distance_to(p)
	position=p
	events.append_array(interact())
	return events
func interact() -> Array:
	var events=[]
	for item in level.stars:
		var id=str(item.id)
		if not stars.has(id) and near(position,item):
			stars[id]=true
			events.append({"type":"star","id":id})
	for item in level.get("keys",[]):
		var id=str(item.id)
		if not keys.has(id) and near(position,item):
			keys[id]=true
			events.append({"type":"key","id":id})
	for item in level.get("questions",[]):
		var id=str(item.id)
		if not questions.has(id) and near(position,item):
			questions[id]=true
			events.append({"type":"question","id":id})
	if suppressed!="":
		for portal in level.get("portals",[]):
			if str(portal.id)==suppressed and not near(position,portal,1.0):
				suppressed=""
				break
	for portal in level.get("portals",[]):
		if str(portal.id)==suppressed or not near(position,portal):
			continue
		var target={}
		for next in level.portals:
			if int(next.number)==int(portal.number)+1:
				target=next
		if target.is_empty() and level.get("portalLoop",false):
			target=level.portals[0]
		if not target.is_empty():
			position=map.point(target)
			suppressed=str(target.id)
			events.append({"type":"portal","from":int(portal.number),"to":int(target.number)})
			break
	if all_stars() and near(position,level.goal):
		won=true
		events.append({"type":"win"})
	return events
func snapshot() -> Dictionary:
	return {"version":level.version,"position":{"x":position.x,"y":position.y},"stars":stars.keys(),"keys":keys.keys(),"opened":opened.keys(),"questions":questions.keys(),"distance":distance,"won":won,"suppressed":suppressed}
func restore(save: Dictionary) -> bool:
	if save.get("version","")!=level.version or not save.has("position"):
		return false
	var p=map.point(save.position)
	if not map.floor_at(p):
		return false
	stars.clear()
	keys.clear()
	opened.clear()
	questions.clear()
	for item in level.stars:
		if str(item.id) in save.get("stars",[]):
			stars[str(item.id)]=true
	for item in level.get("keys",[]):
		if str(item.id) in save.get("keys",[]):
			keys[str(item.id)]=true
	for item in level.get("doors",[]):
		if str(item.id) in save.get("opened",[]):
			opened[str(item.id)]=true
	for item in level.get("questions",[]):
		if str(item.id) in save.get("questions",[]):
			questions[str(item.id)]=true
	position=p if traversable(p) else map.point(level.start)
	distance=maxf(0,float(save.get("distance",0)))
	suppressed=str(save.get("suppressed",""))
	won=bool(save.get("won",false)) and all_stars() and near(position,level.goal)
	return true

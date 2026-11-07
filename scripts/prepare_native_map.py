"""Build native-only map assets. Original reference and web assets are never rewritten."""
from pathlib import Path
import sys,json,base64,gzip,math,hashlib
ROOT=Path(__file__).resolve().parents[1]
for location in [ROOT/"work/pydeps"]:
 if location.exists():sys.path.insert(0,str(location))
import cv2,numpy as np
from scipy import ndimage
from skimage.morphology import skeletonize
A=json.loads((ROOT/"src/map.annotations.json").read_text(encoding="utf-8"))
OUT=ROOT/"godot/assets/map";OUT.mkdir(parents=True,exist_ok=True)
WORK=ROOT/"work/native";WORK.mkdir(parents=True,exist_ok=True)
w,h=A["width"],A["height"]
source=cv2.imread(str(ROOT/"reference/hand-drawn-map.png"))
M=cv2.getPerspectiveTransform(np.float32(A["sourceQuad"]),np.float32([[0,0],[w-1,0],[w-1,h-1],[0,h-1]]))
paper=cv2.warpPerspective(source,M,(w,h),borderValue=(230,240,246))
b,g,r=[c.astype(np.float32) for c in cv2.split(paper)]
gray=cv2.cvtColor(paper,cv2.COLOR_BGR2GRAY).astype(np.float32)
bg=cv2.GaussianBlur(gray,(0,0),13);ratio=gray/np.maximum(bg,1)
old_green=(g-r>6)&(g-b>2)
raw=((ratio<.72)&(gray<155)).astype(np.uint8)*255
ink=(raw*((~old_green).astype(np.uint8))).astype(np.uint8)
ink=cv2.morphologyEx(ink,cv2.MORPH_CLOSE,np.ones((2,2),np.uint8))
baseline=ink.copy()
seeds=((g-r>3)&(g-b>1)&(gray>35)&(gray<230)).astype(np.uint8)*255
lines=cv2.HoughLinesP(seeds,1,np.pi/1800,threshold=70,minLineLength=220,maxLineGap=85)
candidates=[]
if lines is not None:
 for x1,y1,x2,y2 in lines.reshape(-1,4):
  if x2==x1:continue
  slope=(y2-y1)/(x2-x1)
  if abs(slope)<.08:candidates.append((float(y1+slope*(w/2-x1)),float(slope),float(abs(x2-x1))))
groups=[]
for item in sorted(candidates):
 if groups and abs(item[0]-np.average([p[0] for p in groups[-1]],weights=[p[2] for p in groups[-1]]))<14:groups[-1].append(item)
 else:groups.append([item])
yy,xx=np.indices((h,w));bands=np.zeros((h,w),bool);curves=[]
for group in groups:
 length=sum(p[2] for p in group)
 if length<450:continue
 middle=np.average([p[0] for p in group],weights=[p[2] for p in group]);slope=np.average([p[1] for p in group],weights=[p[2] for p in group])
 initial=middle+slope*(np.arange(w)-w/2)
 ys,xs=np.nonzero((seeds>0)&(np.abs(yy-initial[None,:])<9))
 if len(xs)<350 or np.ptp(xs)<w*.28:continue
 coeff=np.polyfit(xs,ys,2)
 for _ in range(4):
  residual=np.abs(np.polyval(coeff,xs)-ys);valid=residual<3.0
  if valid.sum()<200:break
  coeff=np.polyfit(xs[valid],ys[valid],2)
 center=np.polyval(coeff,np.arange(w))
 if center.min()<8 or center.max()>h-8:continue
 band=np.abs(yy-center[None,:])<=2.5
 bands|=band;curves.append([float(v) for v in coeff])
# Keep true dark or thick ink, and strokes crossing the paper ruling.
thick=ndimage.distance_transform_edt(raw>0)>=1.8
thick=cv2.dilate(thick.astype(np.uint8),np.ones((3,3),np.uint8))>0
cross=np.zeros((h,w),np.uint8)
for dx in [-3,-2,-1,0,1,2,3]:
 kernel=np.zeros((9,9),np.uint8);cv2.line(kernel,(4-dx,0),(4+dx,8),1,1)
 cross|=cv2.morphologyEx(raw,cv2.MORPH_OPEN,kernel)
protect=(ratio<.39)|thick|(cross>0)
remove=bands&(~protect)
ink[remove]=0
# Remove isolated ruling remnants only where they retain green chroma.
soft=bands&(g-r>-1)&(g-b>-1)&(ratio>.43)&(~thick)&(cross==0)
ink[soft]=0
# Dark printed green ruling also survives in shadow. Color evidence lets us
# remove it without erasing achromatic pen walls running along the same row.
shadow_green=bands&(g-r>.5)&(g-b>.5)&(cross==0)
ink[shadow_green]=0
cleaned_count=int(np.count_nonzero((baseline>0)&(ink==0)))
outside_ruling_unchanged=bool(np.array_equal(baseline[~bands],ink[~bands]))
if not outside_ruling_unchanged:raise RuntimeError("Unexpected wall edits outside detected ruling bands")
def project(point):
 p=cv2.perspectiveTransform(np.float32([[point]]),M)[0,0]
 return {"x":int(round(p[0])),"y":int(round(p[1]))}
def clear_rect(rect):
 x,y,rw,rh=rect
 points=cv2.perspectiveTransform(np.float32([[[x,y],[x+rw,y],[x+rw,y+rh],[x,y+rh]]]),M)[0]
 cv2.fillConvexPoly(ink,points.astype(np.int32),0)
for category in ["stars","keys","portals","questions"]:
 for item in A[category]:
  p=project(item["source"]);cv2.circle(ink,(p["x"],p["y"]),9 if category=="stars" else 8,0,-1)
for door in A["doors"]:
 if "eraseSourceRect" in door:clear_rect(door["eraseSourceRect"])
 p,q=[project(v) for v in door["sourceLine"]]
 cv2.line(ink,(p["x"],p["y"]),(q["x"],q["y"]),0,7)
margin=np.zeros((h,w),np.uint8)
cv2.fillPoly(margin,[np.array([[0,0],[400,65],[700,72],[1100,45],[1400,10],[1600,0]],np.int32)],255)
ink[margin>0]=255
ink[:4]=255;ink[-4:]=255;ink[:,:4]=255;ink[:,-4:]=255
retained=[];retired=[]
for index,patch in enumerate(A["repairs"]):
 labels,_=ndimage.label(ink==0)
 x,y=patch["from"];qx,qy=patch["to"]
 if labels[y,x] and labels[qy,qx] and labels[y,x]!=labels[qy,qx]:
  cv2.line(ink,(x,y),(qx,qy),0,patch.get("width",3));retained.append(index)
 else:retired.append(index)
floor=ink==0;labels,n=ndimage.label(floor)
clearance=ndimage.distance_transform_edt(floor).astype(np.float32)
def snap(source_point):
 p=project(source_point)
 for radius in range(20):
  options=[]
  for y in range(max(4,p["y"]-radius),min(h-4,p["y"]+radius+1)):
   for x in range(max(4,p["x"]-radius),min(w-4,p["x"]+radius+1)):
    if floor[y,x]:options.append(((x-p["x"])**2+(y-p["y"])**2,x,y))
  if options:
   _,x,y=min(options);return {"x":x,"y":y}
 raise RuntimeError("No floor near "+str(source_point))
level={"version":"map-native-0.2.0-"+hashlib.sha256(ink.tobytes()).hexdigest()[:8],"width":w,"height":h,"start":snap(A["start"]["source"]),"goal":{**snap(A["goal"]["source"]),"radius":4},"portalLoop":A["portalLoop"]}
for category in ["stars","keys","portals","questions"]:
 level[category]=[{**{k:v for k,v in item.items() if k in ["id","number"]},**snap(item["source"]),"radius":4} for item in A[category]]
level["doors"]=[]
for door in A["doors"]:
 p,q=[project(v) for v in door["sourceLine"]]
 level["doors"].append({"id":door["id"],"requiredKeys":door["requiredKeys"],"rect":[min(p["x"],q["x"])-1,min(p["y"],q["y"])-1,max(3,abs(p["x"]-q["x"])+3),max(3,abs(p["y"]-q["y"])+3)]})
critical=[level["start"],level["goal"]]+[p for cat in ["stars","keys","portals","questions"] for p in level[cat]]
components={int(labels[p["y"],p["x"]]) for p in critical}
if len(components)!=1:raise RuntimeError("Critical map components disconnected: "+str(components))
(OUT/"walls.bits").write_bytes(np.packbits((~floor).flat,bitorder="little").tobytes())
(OUT/"clearance.gz").write_bytes(gzip.compress(np.minimum(clearance*4,255).astype(np.uint8).tobytes(),mtime=0))
# A compressed centerline graph replaces millions of grid nodes at runtime.
skel=skeletonize(floor);sy,sx=np.nonzero(skel);skel_ids=set((sy*w+sx).tolist())
def neighbors(pid):
 x,y=pid%w,pid//w;result=[]
 for dx,dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,-1),(-1,1),(1,1)]:
  q=(y+dy)*w+x+dx
  if 0<=x+dx<w and 0<=y+dy<h and q in skel_ids:
   if dx and dy and not(floor[y,x+dx] or floor[y+dy,x]):continue
   result.append(q)
 return result
degree=ndimage.convolve(skel.astype(np.uint8),np.ones((3,3),np.uint8))-skel
_,nearest=ndimage.distance_transform_edt(~skel,return_indices=True)
centers=np.stack([nearest[1],nearest[0]],axis=-1).astype("<u2")
(OUT/"centers.gz").write_bytes(gzip.compress(centers.tobytes(),mtime=0))
junction=(degree>=3)&skel
junction=ndimage.binary_dilation(junction,iterations=6)
(OUT/"junctions.bits").write_bytes(np.packbits(junction.flat,bitorder="little").tobytes())
forced=set()
for p in critical:
 forced.add(int(nearest[0,p["y"],p["x"]])*w+int(nearest[1,p["y"],p["x"]]))
node_pixels={pid for pid in skel_ids if len(neighbors(pid))!=2}|forced
nodes=[];node_map={};queue=[]
def ensure_node(pid):
 if pid not in node_map:node_map[pid]=len(nodes);nodes.append([pid%w,pid//w]);queue.append(pid)
 return node_map[pid]
for pid in sorted(node_pixels):ensure_node(pid)
visited=set();edges=[];qi=0
while qi<len(queue):
 start=queue[qi];qi+=1
 for neighbor in neighbors(start):
  pair=(min(start,neighbor),max(start,neighbor))
  if pair in visited:continue
  visited.add(pair);chain=[start,neighbor];previous=start;current=neighbor
  while current not in node_map and len(chain)<9:
   nexts=[p for p in neighbors(current) if p!=previous]
   if len(nexts)!=1:break
   nxt=nexts[0];pair=(min(current,nxt),max(current,nxt))
   if pair in visited:break
   visited.add(pair);chain.append(nxt);previous,current=current,nxt
  a=ensure_node(start);b=ensure_node(current)
  if a==b:continue
  points=[[p%w,p//w] for p in chain]
  distance=sum(math.dist(p,q) for p,q in zip(points,points[1:]))
  door_ids=[]
  for door in level["doors"]:
   x,y,rw,rh=door["rect"]
   if any(x-1<=p[0]<=x+rw+1 and y-1<=p[1]<=y+rh+1 for p in points):door_ids.append(door["id"])
  edges.append([a,b,round(distance,3),points,door_ids])
graph={"nodes":nodes,"edges":edges}
(OUT/"graph.json").write_text(json.dumps(graph,separators=(",",":")),encoding="utf-8",newline="\n")
# Static boundary segments keep wall holes and curves; split broadphase by 256px.
contours,_=cv2.findContours(ink,cv2.RETR_LIST,cv2.CHAIN_APPROX_SIMPLE)
chunks={};seen=set()
for contour in contours:
 points=cv2.approxPolyDP(contour,.35,True)[:,0,:]
 if len(points)<2:continue
 for p,q in zip(points,np.roll(points,-1,axis=0)):
  if np.array_equal(p,q):continue
  segment=tuple(int(v) for v in np.concatenate([p,q]));reverse=segment[2:]+segment[:2]
  key=min(segment,reverse)
  if key in seen:continue
  seen.add(key);cx=int((p[0]+q[0])/2)//256;cy=int((p[1]+q[1])/2)//256
  chunks.setdefault(f"{cx},{cy}",[]).extend(segment)
(OUT/"collision.json").write_text(json.dumps(chunks,separators=(",",":")),encoding="utf-8",newline="\n")
rng=np.random.default_rng(42);texture=rng.integers(-2,3,(h,w,1),dtype=np.int16)
art=np.clip(np.full(paper.shape,[223,235,245],np.int16)+texture,0,255).astype(np.uint8)
alpha=ink.astype(np.float32)/255
art=(art*(1-alpha[:,:,None])+np.array([61,75,68])[None,None,:]*alpha[:,:,None]).astype(np.uint8)
art[margin>0]=[223,235,245]
cv2.imwrite(str(OUT/"paper.webp"),art,[cv2.IMWRITE_WEBP_QUALITY,92])
(OUT/"level.json").write_text(json.dumps(level,ensure_ascii=False,separators=(",",":")),encoding="utf-8",newline="\n")
overlay=paper.copy();overlay[remove|soft]=(100,100,240)
cv2.imwrite(str(WORK/"ruling-detection.jpg"),overlay)
cv2.imwrite(str(WORK/"clean-map.png"),art)
# Preserve exact evidence and audit which legacy connections remain necessary.
report={"source_sha256":hashlib.sha256((ROOT/"reference/hand-drawn-map.png").read_bytes()).hexdigest(),"ruling_curves":curves,"removed_ink_pixels":cleaned_count,"retained_repairs":retained,"retired_repairs":retired,"critical_components":len(components),"graph_nodes":len(nodes),"graph_edges":len(edges),"collision_chunks":len(chunks),"collision_segments":len(seen),"old_wall_preserved_outside_ruling":outside_ruling_unchanged}
(ROOT/"godot/assets/map/processing-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8",newline="\n")
print(json.dumps({k:v for k,v in report.items() if k not in ["ruling_curves","source_sha256"]}|{"ruling_count":len(curves)}))

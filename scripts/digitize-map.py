"""Digitize only the supplied map; annotations are in original photo coordinates."""
from pathlib import Path
import sys,json,base64
ROOT=Path(__file__).resolve().parents[1]
LOCAL=ROOT/"work/pydeps"
if LOCAL.exists(): sys.path.insert(0,str(LOCAL))
import cv2,numpy as np
from scipy import ndimage

annotations=json.loads((ROOT/"src/map.annotations.json").read_text(encoding="utf-8"))
w,h=annotations["width"],annotations["height"]
source=cv2.imread(str(ROOT/"reference/hand-drawn-map.png"))
if source is None: raise SystemExit("Reference photo is missing")
matrix=cv2.getPerspectiveTransform(np.float32(annotations["sourceQuad"]),np.float32([[0,0],[w-1,0],[w-1,h-1],[0,h-1]]))
paper=cv2.warpPerspective(source,matrix,(w,h),borderValue=(230,240,246))
b,g,r=cv2.split(paper)
gray=cv2.cvtColor(paper,cv2.COLOR_BGR2GRAY).astype(np.float32)
background=cv2.GaussianBlur(gray,(0,0),13)
green=(g.astype(int)-r.astype(int)>6)&(g.astype(int)-b.astype(int)>2)
ink=((gray/np.maximum(background,1)<.72)&(gray<155)&(~green)).astype(np.uint8)*255
ink=cv2.morphologyEx(ink,cv2.MORPH_CLOSE,np.ones((2,2),np.uint8))
def project(point):
    p=cv2.perspectiveTransform(np.float32([[point]]),matrix)[0,0]
    return {"x":int(round(p[0])),"y":int(round(p[1]))}
def clear_rect(source_rect):
    x,y,rw,rh=source_rect
    points=cv2.perspectiveTransform(np.float32([[[x,y],[x+rw,y],[x+rw,y+rh],[x,y+rh]]]),matrix)[0]
    cv2.fillConvexPoly(ink,points.astype(np.int32),0)

# Text/glyphs that represent an item are not physical walls.
for name in ["stars","keys","portals","questions"]:
    for item in annotations[name]:
        p=project(item["source"]);cv2.circle(ink,(p["x"],p["y"]),9 if name=="stars" else 8,0,-1)
for door in annotations["doors"]:
    if "eraseSourceRect" in door: clear_rect(door["eraseSourceRect"])
    p1,p2=[project(p) for p in door["sourceLine"]]
    cv2.line(ink,(p1["x"],p1["y"]),(p2["x"],p2["y"]),0,7)
for patch in annotations["repairs"]:
    cv2.line(ink,tuple(patch["from"]),tuple(patch["to"]),0,patch.get("width",3))

# Block photographic margins and the edge of the sheet.
marginMask=np.zeros(ink.shape,dtype=np.uint8)
cv2.fillPoly(marginMask,[np.array([[0,0],[400,65],[700,72],[1100,45],[1400,10],[1600,0]],np.int32)],255)
ink[marginMask>0]=255
ink[:4,:]=255;ink[-4:,:]=255;ink[:,:4]=255;ink[:,-4:]=255
wall=(cv2.resize(ink,(w,h),interpolation=cv2.INTER_AREA)>110).astype(np.uint8)
labels,n=ndimage.label(1-wall)
def snap(point):
    p=project(point);best=None
    for radius in range(0,18):
        for yy in range(max(2,p["y"]-radius),min(h-2,p["y"]+radius+1)):
            for xx in range(max(2,p["x"]-radius),min(w-2,p["x"]+radius+1)):
                if wall[yy,xx]:continue
                d=(xx-p["x"])**2+(yy-p["y"])**2
                # Prefer road clearance, and stay near the drawn marker.
                score=d
                if best is None or score<best[0]:best=(score,xx,yy)
        if best:break
    if best is None: raise RuntimeError("No floor near marker "+str(point))
    return {"x":best[1],"y":best[2]}
level={"version":annotations["version"],"width":w,"height":h,"start":snap(annotations["start"]["source"]),"goal":{**snap(annotations["goal"]["source"]),"radius":4},"portalLoop":annotations["portalLoop"]}
for name in ["stars","keys","portals","questions"]:
    level[name]=[{**{k:v for k,v in item.items() if k in ["id","number"]},**snap(item["source"]),"radius":4} for item in annotations[name]]
level["doors"]=[]
for item in annotations["doors"]:
    p1,p2=[project(p) for p in item["sourceLine"]]
    x,y=min(p1["x"],p2["x"])-1,min(p1["y"],p2["y"])-1
    rw,rh=max(3,abs(p1["x"]-p2["x"])+3),max(3,abs(p1["y"]-p2["y"])+3)
    level["doors"].append({"id":item["id"],"requiredKeys":item["requiredKeys"],"rect":[x,y,rw,rh]})
level["wallsB64"]=base64.b64encode(np.packbits(wall.flatten(),bitorder="little").tobytes()).decode()
# Clear, quiet ink rendering; every navigable repair is visible in this view.
rng=np.random.default_rng(42)
texture=rng.integers(-2,3,(h,w,1),dtype=np.int16)
art=np.clip(np.full(paper.shape,[223,235,245],dtype=np.int16)+texture,0,255).astype(np.uint8)
alpha=ink.astype(np.float32)/255
art=(art.astype(float)*(1-alpha[:,:,None])+np.array([61,75,68])[None,None,:]*alpha[:,:,None]).astype(np.uint8)
# Do not make the blocked photo margin look like a giant ink blob.
art[marginMask>0]=np.array([223,235,245])
def data_image(image,quality=86):
    okay,buf=cv2.imencode(".webp",image,[cv2.IMWRITE_WEBP_QUALITY,quality])
    if not okay:raise RuntimeError("Could not encode map")
    return "data:image/webp;base64,"+base64.b64encode(buf).decode()
level["art"]=data_image(art)
level["originalArt"]=data_image(paper,83)
(ROOT/"src/level.generated.json").write_text(json.dumps(level,separators=(",",":")),encoding="utf-8")
preview=art.copy()
report={}
for name in ["stars","keys","portals","questions"]:
    for item in level[name]:
        report[name+":"+item["id"]]={"x":item["x"],"y":item["y"],"component":int(labels[item["y"],item["x"]])}
        p=(item["x"]*2,item["y"]*2);cv2.circle(preview,p,14,(80,150,220),2);cv2.putText(preview,name[0]+item["id"],(p[0]+9,p[1]-5),cv2.FONT_HERSHEY_SIMPLEX,.5,(20,50,200),1)
for name in ["start","goal"]:
    p=level[name];report[name]={**p,"component":int(labels[p["y"],p["x"]])};cv2.circle(preview,(p["x"],p["y"]),16,(30,70,220),3)
(ROOT/"work").mkdir(exist_ok=True)
cv2.imwrite(str(ROOT/"work/calibrated-map.png"),preview)
np.savez_compressed(ROOT/"work/level-analysis.npz",wall=wall,labels=labels)
(ROOT/"work/marker-components.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print(json.dumps({"map":[w,h],"components":int(n),"markers":report,"generated_bytes":(ROOT/"src/level.generated.json").stat().st_size}))

"""Fetch pinned official Godot editor/template into ignored project-local tools."""
from pathlib import Path
import io,zipfile,urllib.request,hashlib,json
ROOT=Path(__file__).resolve().parents[1]
BASE="https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/"
EDITOR_ZIP_SHA="731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953"
TEMPLATE_SHA="d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562"
def sha(path):
 h=hashlib.sha256()
 with path.open("rb") as f:
  for chunk in iter(lambda:f.read(1024*1024),b""):h.update(chunk)
 return h.hexdigest()
tools=ROOT/"work/tools";tools.mkdir(parents=True,exist_ok=True)
editor=tools/"godot";editor.mkdir(exist_ok=True)
if not (editor/"Godot_v4.7.2-stable_win64_console.exe").exists():
 archive=tools/"godot.zip"
 if not archive.exists() or sha(archive)!=EDITOR_ZIP_SHA:
  urllib.request.urlretrieve(BASE+"Godot_v4.7.2-stable_win64.exe.zip",archive)
 if sha(archive)!=EDITOR_ZIP_SHA:raise RuntimeError("Godot editor archive hash mismatch")
 with zipfile.ZipFile(archive) as z:
  for name in ["Godot_v4.7.2-stable_win64.exe","Godot_v4.7.2-stable_win64_console.exe"]:
   (editor/name).write_bytes(z.read(name))
class RemoteFile(io.RawIOBase):
 def __init__(self,url):
  self.url=url;self.pos=0
  with urllib.request.urlopen(urllib.request.Request(url,method="HEAD"),timeout=60) as r:self.size=int(r.headers["Content-Length"])
 def seekable(self):return True
 def seek(self,offset,whence=0):
  self.pos=offset if whence==0 else (self.pos+offset if whence==1 else self.size+offset);return self.pos
 def tell(self):return self.pos
 def read(self,n=-1):
  if n<0:n=self.size-self.pos
  if not n:return b""
  start=self.pos;end=min(self.size-1,start+n-1)
  with urllib.request.urlopen(urllib.request.Request(self.url,headers={"Range":f"bytes={start}-{end}"}),timeout=180) as r:
   if r.status!=206 or not r.headers.get("Content-Range","").startswith(f"bytes {start}-"):raise RuntimeError("Template host did not honor byte range")
   data=r.read()
  self.pos+=len(data);return data
target=tools/"templates";target.mkdir(exist_ok=True)
output=target/"windows_release_x86_64.exe"
if not output.exists() or sha(output)!=TEMPLATE_SHA:
 with zipfile.ZipFile(RemoteFile(BASE+"Godot_v4.7.2-stable_export_templates.tpz")) as z:
  names=[i for i in z.infolist() if i.filename.endswith("/windows_release_x86_64.exe")]
  if len(names)!=1:raise RuntimeError("Unexpected template archive")
  with z.open(names[0]) as source,output.open("wb") as destination:
   for chunk in iter(lambda:source.read(1024*1024),b""):destination.write(chunk)
 if sha(output)!=TEMPLATE_SHA:raise RuntimeError("Windows template hash mismatch")
assets=ROOT/"godot/assets";assets.mkdir(parents=True,exist_ok=True)
for link,path in [
 ("https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf",assets/"NotoSansCJKsc-Regular.otf"),
 ("https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/LICENSE",assets/"OFL.txt")]:
 if not path.exists():urllib.request.urlretrieve(link,path)
print(json.dumps({"godot":"4.7.2.stable","editor_ready":True,"windows_template_sha256":sha(output),"font_ready":True}))

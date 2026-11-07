"""Reproducible Windows export, native checks, packaged smoke test, and ZIP."""
from pathlib import Path
import argparse,subprocess,sys,os,json,hashlib,zipfile,shutil
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/"work/native";WORK.mkdir(parents=True,exist_ok=True)
ENGINE=ROOT/"work/tools/godot/Godot_v4.7.2-stable_win64_console.exe"
BUNDLE=ROOT/"outputs/map-windows-x64"
VERSION="0.2.0"
def run(args,log,env=None):
 result=subprocess.run([str(x) for x in args],cwd=ROOT,env=env,capture_output=True,text=True,encoding="utf-8",errors="replace",timeout=240)
 text=result.stdout+"\n"+result.stderr
 (WORK/log).write_text(text,encoding="utf-8",newline="\n")
 if result.returncode or "SCRIPT ERROR:" in text or "\nERROR:" in text:
  raise RuntimeError(log+": "+text[-4500:])
 return text
def sha(path):
 h=hashlib.sha256()
 with path.open("rb") as f:
  for chunk in iter(lambda:f.read(1024*1024),b""):h.update(chunk)
 return h.hexdigest()
parser=argparse.ArgumentParser()
parser.add_argument("--skip-tests",action="store_true")
parser.add_argument("--regenerate-map",action="store_true")
args=parser.parse_args()
if not ENGINE.exists():
 run([sys.executable,"scripts/prepare_native_tools.py"],"tools-prepare.log")
version=run([ENGINE,"--version"],"engine-version.log").strip()
if not version.startswith("4.7.2.stable"):raise RuntimeError("Unexpected Godot version: "+version)
if args.regenerate_map:
 env=dict(os.environ);env["PYTHONPATH"]=str(ROOT/"work/pydeps")+os.pathsep+env.get("PYTHONPATH","")
 run([sys.executable,"-X","utf8","scripts/prepare_native_map.py"],"processing.log",env)
run([ENGINE,"--headless","--path","godot","--editor","--import","--quit"],"import-final.log")
if not args.skip_tests:
 for name in ["test_rules","test_integration","test_full_map"]:
  run([ENGINE,"--headless","--path","godot","--script","res://tests/"+name+".gd"],name+"-final.log")
BUNDLE.mkdir(parents=True,exist_ok=True)
run([ENGINE,"--headless","--path","godot","--export-release","Windows","../outputs/map-windows-x64/map.exe"],"export-final.log")
report_path=WORK/"packaged-runtime-report.json"
if report_path.exists():report_path.unlink()
env=dict(os.environ);env["MAP_VERIFY_REPORT"]=str(report_path)
run([BUNDLE/"map.exe","--headless","--log-file",WORK/"release-engine.log","--","--verify-package"],"release-launch.log",env)
if not report_path.exists():raise RuntimeError("Exported executable did not complete runtime verification")
runtime=json.loads(report_path.read_text(encoding="utf-8"))
if not runtime.get("ok"):raise RuntimeError("Exported runtime verification failed")
licenses=BUNDLE/"LICENSES";licenses.mkdir(exist_ok=True)
(licenses/"Godot-MIT.txt").write_text(runtime.pop("license_text"),encoding="utf-8",newline="\n")
shutil.copyfile(ROOT/"godot/assets/OFL.txt",licenses/"NotoSansCJK-OFL.txt")
(licenses/"来源.txt").write_text("Godot Engine 4.7.2 — https://godotengine.org/\nNoto Sans CJK SC Regular — https://github.com/notofonts/noto-cjk\n游戏地图为用户提供的手绘图，识别与校准范围见项目文档。\n",encoding="utf-8",newline="\n")
instructions="""map · 纸上迷宫 — Windows 64 位免安装版 0.2.0

1. 完整解压此压缩包。
2. 双击 map.exe。map.pck 必须与 map.exe 放在同一文件夹。
3. 无需安装 Godot、Python 或 Node.js。

操作
WASD / 方向键：平滑移动，键盘输入立即接管自动行走。
鼠标左键：点击道路寻路；鼠标右键或中键：拖动地图。
滚轮：缩放；F：全图；C：定位自己。
空格 / Esc：暂停或继续；F11：切换全屏。
步速滑块：调整移动速度。
失去窗口焦点时自动暂停。进度自动保存在本机用户数据目录，独立于旧网页版。

规则
全部星星集齐后才能进入终点；钥匙打开对应编号的门且可重复使用。
传1→传2→传3→传4→传5，传5为最终落点；落地后先离开再进入才会继续触发。
问号没有物品。
原图模糊的门编号、钥匙2和右下终点仍沿用暂定设定。

验证
已执行原生规则与移动、窗口/存档集成测试，以及真实圆形碰撞控制器的全图通关模拟。
已检查 Windows 窗口启动和中文显示；真实键鼠手感与人工完整通关由用户后续试玩验收。
"""
(BUNDLE/"使用说明.txt").write_text(instructions,encoding="utf-8-sig",newline="\r\n")
commit=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip()
dirty=bool(subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).strip())
manifest={"version":VERSION,"godot":version,"source_commit":commit,"working_tree_dirty":dirty,"runtime_verification":runtime,"files":{name:sha(BUNDLE/name) for name in ["map.exe","map.pck"]}}
(BUNDLE/"release-info.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
(BUNDLE/"SHA256SUMS.txt").write_text("\n".join(value+"  "+name for name,value in manifest["files"].items())+"\n",encoding="ascii")
archive=ROOT/("outputs/map-windows-x64-v"+VERSION+".zip")
with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for path in sorted(BUNDLE.rglob("*")):
  if path.is_file():z.write(path,path.relative_to(BUNDLE).as_posix())
with zipfile.ZipFile(archive) as z:
 bad=z.testzip()
 if bad:raise RuntimeError("ZIP integrity error: "+bad)
 for name,expected in manifest["files"].items():
  h=hashlib.sha256()
  with z.open(name) as f:
   for chunk in iter(lambda:f.read(1024*1024),b""):h.update(chunk)
  if h.hexdigest()!=expected:raise RuntimeError("ZIP hash mismatch: "+name)
summary={"archive":archive.name,"bytes":archive.stat().st_size,"sha256":sha(archive),"source_commit":commit,"working_tree_dirty":dirty,"runtime":runtime}
(WORK/"release-report.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding="utf-8",newline="\n")
print(json.dumps(summary,ensure_ascii=False))

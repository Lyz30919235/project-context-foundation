import {MazeGame} from './engine.mjs';
const $=id=>document.getElementById(id);
const canvas=$('board'),ctx=canvas.getContext('2d'),mini=$('minimap'),mctx=mini.getContext('2d');
const storageKey='map-paper-maze-v1';
let saved=null;try{saved=JSON.parse(localStorage.getItem(storageKey));}catch{}
let game=new MazeGame(LEVEL,saved?.game),elapsed=Math.max(0,saved?.elapsed||0),started=Boolean(saved?.started),paused=false;
let W=800,H=700,dpr=1,zoom=1,offsetX=0,offsetY=0,following=false,showOriginal=false,route=[],routeIndex=0,routeVisible=false;
let lastFrame=performance.now(),moveDebt=0,saveDebt=0,toastTimeout,down=null,dragged=false,wasPinching=false;
const held=new Set(),pointers=new Map(),trail=(saved?.trail||[]).slice(-6000),directions={ArrowUp:[0,-1],w:[0,-1],W:[0,-1],ArrowDown:[0,1],s:[0,1],S:[0,1],ArrowLeft:[-1,0],a:[-1,0],A:[-1,0],ArrowRight:[1,0],d:[1,0],D:[1,0]};
const paper=new Image(),original=new Image();paper.src=LEVEL.art;original.src=LEVEL.originalArt||LEVEL.art;
let artReady=false;paper.onload=()=>{artReady=true;draw();};paper.onerror=()=>toast('地图图像加载失败，请重新打开游戏。');
function toast(text,ms=2700){$('toast').textContent=text;$('toast').hidden=false;clearTimeout(toastTimeout);toastTimeout=setTimeout(()=>$('toast').hidden=true,ms);}
function save(){try{localStorage.setItem(storageKey,JSON.stringify({game:game.snapshot(),elapsed,started,trail:trail.slice(-6000)}));$('saveStatus').textContent='探索进度已自动保存';}catch{$('saveStatus').textContent='当前浏览器无法保存，仍可继续探索';}}
function setStarted(){if(started)return;started=true;$('introCard').hidden=true;following=true;locate(3.2);toast('从左下角入口出发。方向键 / WASD，或点击道路前往。',3800);save();}
function fit(){zoom=Math.min((W-70)/LEVEL.width,(H-65)/LEVEL.height);offsetX=(W-LEVEL.width*zoom)/2;offsetY=(H-LEVEL.height*zoom)/2;following=false;clampView();updateZoom();}
function clampView(){if(LEVEL.width*zoom>W-32)offsetX=Math.min(16,Math.max(W-LEVEL.width*zoom-16,offsetX));else offsetX=(W-LEVEL.width*zoom)/2;if(LEVEL.height*zoom>H-32)offsetY=Math.min(16,Math.max(H-LEVEL.height*zoom-16,offsetY));else offsetY=(H-LEVEL.height*zoom)/2;}
function locate(value=null){if(value)zoom=Math.min(8,Math.max(.2,value));offsetX=W/2-game.position.x*zoom;offsetY=H/2-game.position.y*zoom;following=true;clampView();updateZoom();}
function updateZoom(){$('zoomLabel').textContent=zoom<1?'全图':Math.round(zoom*50)+'%';}
function resize(){const box=$('viewport').getBoundingClientRect(),oldW=W,oldH=H;W=box.width;H=box.height;dpr=Math.min(devicePixelRatio||1,2);canvas.width=Math.round(W*dpr);canvas.height=Math.round(H*dpr);ctx.setTransform(dpr,0,0,dpr,0,0);if(!started)fit();else{offsetX+=(W-oldW)/2;offsetY+=(H-oldH)/2;if(following)locate();}drawMini();}
function zoomAt(factor,sx=W/2,sy=H/2){const wx=(sx-offsetX)/zoom,wy=(sy-offsetY)/zoom;zoom=Math.min(10,Math.max(Math.min((W-30)/LEVEL.width,(H-30)/LEVEL.height)*.8,zoom*factor));offsetX=sx-wx*zoom;offsetY=sy-wy*zoom;following=false;clampView();updateZoom();}
function point(e){const r=canvas.getBoundingClientRect();return{x:e.clientX-r.left,y:e.clientY-r.top};}
function world(p){return{x:(p.x-offsetX)/zoom,y:(p.y-offsetY)/zoom};}
function handleEvents(events){
 for(const e of events){
  if(e.type==='star')toast(e.total===e.required?'所有星星都找到了！终点已经开启。':'拾到一颗星星 · '+e.total+' / '+e.required);
  if(e.type==='key')toast('找到钥匙 '+e.id+'，现在可以打开对应的门。');
  if(e.type==='door')toast('门已打开 · 钥匙 '+e.keys.join('、')+' 保留在背包里');
  if(e.type==='locked')notifyBlocked('这扇门需要钥匙 '+e.key+'。');
  if(e.type==='question')toast('问号是空的，这里没有任何物品。');
  if(e.type==='goalLocked')notifyBlocked('终点尚未开启，还差 '+e.remaining+' 颗星星。');
  if(e.type==='portal'){route=[];routeIndex=0;routeVisible=false;toast('传'+e.from+' → 传'+e.to+' · 已到达新的位置');locate();}
  if(e.type==='win'){route=[];paused=true;held.clear();save();$('winSummary').textContent='收集了 '+LEVEL.stars.length+' 颗星星，走过 '+game.steps+' 步，用时 '+formatTime(elapsed)+'。';$('winDialog').showModal();}
 }
 if(events.some(e=>['star','key','door','win'].includes(e.type)))updateStats();
}
let lastBlocked='',lastBlockedTime=0;
function notifyBlocked(text){if(text!==lastBlocked||performance.now()-lastBlockedTime>1600){lastBlocked=text;lastBlockedTime=performance.now();toast(text);}}
function step(dx,dy){const old={...game.position},events=game.step(dx,dy);handleEvents(events);if(game.position.x!==old.x||game.position.y!==old.y){trail.push(game.index(game.position.x,game.position.y));if(trail.length>6000)trail.shift();if(following){const px=offsetX+game.position.x*zoom,py=offsetY+game.position.y*zoom;if(px<W*.2||px>W*.8||py<H*.2||py>H*.8)locate();}return true;}return false;}
function updateStats(){
 $('starCount').textContent=game.stars.size;$('starTotal').textContent=' / '+LEVEL.stars.length;$('progress').style.width=(game.stars.size/LEVEL.stars.length*100)+'%';
 $('starSlots').innerHTML=LEVEL.stars.map(s=>'<span class="star-slot '+(game.stars.has(s.id)?'filled':'')+'" aria-label="'+(game.stars.has(s.id)?'已收集':'未收集')+'星星">✦</span>').join('');
 $('keyCount').textContent=game.keys.size+' / '+LEVEL.keys.length;
 $('keySlots').innerHTML=LEVEL.keys.map(k=>'<span class="key-slot '+(game.keys.has(k.id)?'owned':'')+'" aria-label="钥匙'+k.id+(game.keys.has(k.id)?'已取得':'未取得')+'">⚿<small>'+k.id+'</small></span>').join('');
 $('collectHint').textContent=game.allStars?'星光齐了，去右下角的终点吧。':'集齐所有星星，终点才会开启。';
 $('steps').textContent=String(game.steps).padStart(4,'0');$('zoneLabel').textContent=game.allStars?'所有星光已经集齐，终点等着你。':started?'不着急，每条弯路都值得探索。':'从左下角入口出发。';
}
function formatTime(seconds){seconds=Math.floor(seconds);return String(Math.floor(seconds/60)).padStart(2,'0')+':'+String(seconds%60).padStart(2,'0');}
function circle(x,y,r,fill,stroke=null,line=1){ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fillStyle=fill;ctx.fill();if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=line;ctx.stroke();}}
function drawMarker(item,type){
 const x=offsetX+item.x*zoom,y=offsetY+item.y*zoom;if(x< -40||y< -40||x>W+40||y>H+40)return;
 const r=Math.min(12,Math.max(type==='player'?5:4,zoom*2.1));
 if(type==='star'){if(game.stars.has(item.id))return;circle(x,y,r+3,'#fcf6e4e6');ctx.fillStyle='#bd8a2d';ctx.font=(r*2.15)+'px Georgia';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText('✦',x,y+.5);}
 if(type==='key'){if(game.keys.has(item.id))return;circle(x,y,r+2,'#eaf0dfe6','#84936e',1);ctx.fillStyle='#5f7550';ctx.font='bold '+Math.max(8,r)+'px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(item.id,x,y);}
 if(type==='portal'){circle(x,y,r+1,'#e0ece6eb','#648877',1);ctx.fillStyle='#547760';ctx.font=Math.max(8,r)+'px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(item.number,x,y);}
 if(type==='question'){circle(x,y,Math.max(3,r*.7),'#e9e9e0dd');ctx.fillStyle='#8d9582';ctx.font=Math.max(7,r*.9)+'px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText('?',x,y);}
 if(type==='start'||type==='goal'){circle(x,y,r+3,type==='goal'&&game.allStars?'#dce8d5ed':'#fcf9eef0',type==='start'?'#d78751':'#8c9d78',1);ctx.fillStyle=type==='start'?'#b86b3d':'#71815e';ctx.font='bold '+Math.max(7,r*.9)+'px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(type==='start'?'入':game.allStars?'终':'锁',x,y);}
}
function draw(){
 ctx.clearRect(0,0,W,H);ctx.save();ctx.translate(offsetX,offsetY);ctx.scale(zoom,zoom);ctx.shadowColor='#3c473a1b';ctx.shadowBlur=18/zoom;ctx.shadowOffsetY=5/zoom;ctx.fillStyle='#faf5e7';ctx.fillRect(0,0,LEVEL.width,LEVEL.height);ctx.shadowBlur=0;ctx.shadowOffsetY=0;
 if(artReady)ctx.drawImage(showOriginal&&original.complete?original:paper,0,0,LEVEL.width,LEVEL.height);ctx.strokeStyle='#fffdf4';ctx.lineWidth=2/zoom;ctx.strokeRect(0,0,LEVEL.width,LEVEL.height);
 if(trail.length>1&&zoom>1){ctx.beginPath();let previous=null;for(const id of trail){const p={x:id%LEVEL.width,y:(id/LEVEL.width)|0};if(!previous||Math.abs(p.x-previous.x)+Math.abs(p.y-previous.y)>3)ctx.moveTo(p.x,p.y);else ctx.lineTo(p.x,p.y);previous=p;}ctx.strokeStyle='#bc7e4948';ctx.lineWidth=1.4/zoom;ctx.stroke();}
 if(routeVisible&&route.length>1){ctx.beginPath();for(let i=routeIndex;i<route.length;i++){const id=route[i],x=id%LEVEL.width,y=(id/LEVEL.width)|0;if(i===routeIndex)ctx.moveTo(x,y);else ctx.lineTo(x,y);}ctx.strokeStyle='#be884992';ctx.lineWidth=Math.max(.8,1.5/zoom);ctx.setLineDash([3/zoom,3/zoom]);ctx.stroke();ctx.setLineDash([]);}
 for(const door of LEVEL.doors){const [x,y,w,h]=door.rect;if(game.openedDoors.has(door.id))continue;const can=game.requiredKeys(door).every(k=>game.keys.has(k));ctx.fillStyle=can?'#9ba88399':'#b87b5bc9';ctx.fillRect(x,y,w,h);ctx.strokeStyle='#faf2d4';ctx.lineWidth=.6;ctx.strokeRect(x+.2,y+.2,Math.max(.4,w-.4),Math.max(.4,h-.4));}
 ctx.restore();for(const s of LEVEL.stars)drawMarker(s,'star');for(const k of LEVEL.keys)drawMarker(k,'key');for(const p of LEVEL.portals)drawMarker(p,'portal');for(const q of LEVEL.questions)drawMarker(q,'question');drawMarker(LEVEL.start,'start');drawMarker(LEVEL.goal,'goal');
 const px=offsetX+game.position.x*zoom,py=offsetY+game.position.y*zoom;circle(px,py,11,'#d87e3c20');circle(px,py,6.3,'#fff9eb','#cd7540',1.7);circle(px,py,3,'#cf7b44');drawMini();
}
function drawMini(){
 const r=mini.getBoundingClientRect();if(!r.width||!r.height)return;if(mini.width!==Math.round(r.width*1.5)||mini.height!==Math.round(r.height*1.5)){mini.width=Math.round(r.width*1.5);mini.height=Math.round(r.height*1.5);}
 const w=mini.width,h=mini.height,z=Math.min((w-14)/LEVEL.width,(h-10)/LEVEL.height),ox=(w-LEVEL.width*z)/2,oy=(h-LEVEL.height*z)/2;
 mctx.clearRect(0,0,w,h);mctx.fillStyle='#f8f5e7';mctx.fillRect(ox,oy,LEVEL.width*z,LEVEL.height*z);if(artReady){mctx.globalAlpha=.65;mctx.drawImage(paper,ox,oy,LEVEL.width*z,LEVEL.height*z);mctx.globalAlpha=1;}
 mctx.strokeStyle='#9da78c';mctx.lineWidth=.8;mctx.strokeRect(ox-offsetX/zoom*z,oy-offsetY/zoom*z,W/zoom*z,H/zoom*z);mctx.beginPath();mctx.arc(ox+game.position.x*z,oy+game.position.y*z,3,0,Math.PI*2);mctx.fillStyle='#c67a44';mctx.fill();
}
function setPause(value){if(!started||game.won)return;paused=value;held.clear();route=[];$('pausedOverlay').hidden=!value;$('pause').textContent=value?'▷':'Ⅱ';$('pause').setAttribute('aria-label',value?'继续':'暂停');save();}
function reset(){game=new MazeGame(LEVEL);elapsed=0;started=false;paused=false;route=[];routeIndex=0;trail.length=0;held.clear();$('pausedOverlay').hidden=true;$('introCard').hidden=false;$('pause').textContent='Ⅱ';for(const d of document.querySelectorAll('dialog[open]'))d.close();fit();updateStats();save();toast('新的探索，从左下角入口开始。');}
async function goTo(target,hint=false){
 if(paused||game.won)return;if(!started)setStarted();$('hint').disabled=true;await new Promise(r=>setTimeout(r,20));const p=game.findPath(target);$('hint').disabled=false;
 if(!p){toast('目前还走不到这里。试试其他道路，或先找钥匙和传送点。',3400);return false;}
 route=p;routeIndex=1;routeVisible=true;following=true;if(hint){route=p.slice(0,Math.min(p.length,110));routeIndex=1;toast('先沿着这一小段星光走，看看前方有什么。');}return true;
}
async function hint(){
 if(!started)setStarted();if(paused||game.won)return;$('hint').disabled=true;await new Promise(r=>setTimeout(r,20));
 const targets=[...LEVEL.keys.filter(k=>!game.keys.has(k.id)),...LEVEL.stars.filter(s=>!game.stars.has(s.id)),...(game.allStars?[LEVEL.goal]:[]),...LEVEL.portals.filter(p=>p.number<LEVEL.portals.length)];
 targets.sort((a,b)=>Math.abs(a.x-game.position.x)+Math.abs(a.y-game.position.y)-Math.abs(b.x-game.position.x)-Math.abs(b.y-game.position.y));
 let best=null;for(const target of targets){const p=game.findPath(target);if(p&&p.length>5&&(!best||p.length<best.length))best=p;if(best&&best.length<600)break;}
 $('hint').disabled=false;if(!best){toast('暂时没有新的可达目标，试试传送点附近或其他岔路。');return;}route=best.slice(0,Math.min(best.length,110));routeIndex=1;routeVisible=true;following=true;toast('提示照亮前方一小段，剩下的路由你发现。');
}
$('start').onclick=()=>{setStarted();canvas.focus();};$('locate').onclick=()=>{if(!started)setStarted();locate(3.2);};$('overview').onclick=fit;$('miniOverview').onclick=fit;$('zoomIn').onclick=()=>zoomAt(1.3);$('zoomOut').onclick=()=>zoomAt(1/1.3);$('hint').onclick=hint;
$('paperMode').onclick=()=>{showOriginal=!showOriginal;$('paperMode').textContent=showOriginal?'切换清晰图':'查看原图';};$('pause').onclick=()=>setPause(!paused);$('resume').onclick=()=>setPause(false);
$('help').onclick=()=>{held.clear();$('helpDialog').showModal();};$('restart').onclick=()=>{held.clear();$('restartDialog').showModal();};$('confirmRestart').onclick=reset;$('playAgain').onclick=reset;
document.querySelectorAll('[data-close]').forEach(button=>button.onclick=()=>{$(button.dataset.close).close();if(button.dataset.close==='winDialog')paused=false;});
for(const dialog of document.querySelectorAll('dialog'))dialog.addEventListener('close',()=>{held.clear();if(dialog.id==='winDialog')paused=false;});
canvas.addEventListener('wheel',e=>{e.preventDefault();const p=point(e);zoomAt(Math.exp(-e.deltaY*.0012),p.x,p.y);},{passive:false});
canvas.addEventListener('pointerdown',e=>{if(e.button!==0&&e.button!==1&&e.button!==2)return;canvas.setPointerCapture(e.pointerId);const p=point(e);pointers.set(e.pointerId,p);down={x:p.x,y:p.y,ox:offsetX,oy:offsetY,button:e.button};dragged=false;});
canvas.addEventListener('pointermove',e=>{if(!pointers.has(e.pointerId))return;const p=point(e),old=pointers.get(e.pointerId);if(pointers.size===2){const other=[...pointers].find(([id])=>id!==e.pointerId)?.[1];if(other){const before=Math.hypot(old.x-other.x,old.y-other.y),after=Math.hypot(p.x-other.x,p.y-other.y);if(before>2)zoomAt(after/before,(p.x+other.x)/2,(p.y+other.y)/2);}wasPinching=true;dragged=true;}else if(down){const dx=p.x-down.x,dy=p.y-down.y;if(Math.hypot(dx,dy)>4)dragged=true;if(dragged){offsetX=down.ox+dx;offsetY=down.oy+dy;following=false;clampView();}}pointers.set(e.pointerId,p);});
canvas.addEventListener('pointerup',e=>{const p=point(e);pointers.delete(e.pointerId);if(!dragged&&!wasPinching&&down?.button===0)goTo(world(p));if(!pointers.size){down=null;wasPinching=false;}});
canvas.addEventListener('pointercancel',e=>{pointers.delete(e.pointerId);down=null;});canvas.addEventListener('contextmenu',e=>e.preventDefault());canvas.addEventListener('dblclick',e=>{const p=point(e);zoomAt(1.8,p.x,p.y);});
mini.onclick=e=>{const r=mini.getBoundingClientRect(),z=Math.min((r.width-9)/LEVEL.width,(r.height-7)/LEVEL.height),ox=(r.width-LEVEL.width*z)/2,oy=(r.height-LEVEL.height*z)/2;const wx=(e.clientX-r.left-ox)/z,wy=(e.clientY-r.top-oy)/z;if(zoom<1)zoom=3;offsetX=W/2-wx*zoom;offsetY=H/2-wy*zoom;following=false;clampView();updateZoom();};
window.addEventListener('keydown',e=>{if(document.querySelector('dialog[open]'))return;if(directions[e.key]){e.preventDefault();if(!started)setStarted();if(paused||game.won)return;held.add(e.key);route=[];routeVisible=false;following=true;}if(e.code==='Space'){e.preventDefault();setPause(!paused);}if(e.key==='f'||e.key==='F')fit();if(e.key==='c'||e.key==='C')locate(3.2);});
window.addEventListener('keyup',e=>held.delete(e.key));window.addEventListener('blur',()=>{held.clear();save();});window.addEventListener('pagehide',save);document.addEventListener('visibilitychange',()=>{if(document.hidden&&started&&!game.won)setPause(true);});
const padKeys={up:'ArrowUp',down:'ArrowDown',left:'ArrowLeft',right:'ArrowRight'};
document.querySelectorAll('[data-dir]').forEach(button=>{button.addEventListener('pointerdown',e=>{e.preventDefault();button.setPointerCapture(e.pointerId);if(!started)setStarted();route=[];routeVisible=false;held.add(padKeys[button.dataset.dir]);following=true;});for(const name of ['pointerup','pointercancel','lostpointercapture'])button.addEventListener(name,()=>held.delete(padKeys[button.dataset.dir]));});
if(LEVEL.portalLoop){$('portalRule').textContent='传1 → 传2 → 传3 → 传4 → 传5 → 传1';$('helpPortal').textContent='传 n 到达传 n+1，传5回到传1。';}
$('introCard').hidden=started;updateStats();new ResizeObserver(resize).observe($('viewport'));resize();if(started)locate(3.2);
function frame(now){const delta=Math.min((now-lastFrame)/1000,.08);lastFrame=now;const active=started&&!paused&&!game.won&&!document.hidden&&!document.querySelector('dialog[open]');if(active){elapsed+=delta;moveDebt=held.size||routeIndex<route.length?moveDebt+delta:0;saveDebt+=delta;let count=0;while(moveDebt>=1/65&&count++<7){moveDebt-=1/65;let moved=false;const key=[...held].at(-1);if(key){const d=directions[key];moved=step(d[0],d[1]);}else if(routeIndex<route.length){const id=route[routeIndex],x=id%LEVEL.width,y=(id/LEVEL.width)|0,dx=x-game.position.x,dy=y-game.position.y;if(Math.abs(dx)+Math.abs(dy)===0){routeIndex++;continue;}if(Math.abs(dx)+Math.abs(dy)!==1){route=[];break;}moved=step(dx,dy);if(moved)routeIndex++;else route=[];}if(!moved&&!key)break;}if(saveDebt>3){saveDebt=0;save();}}else moveDebt=0;$('timer').textContent=formatTime(elapsed);$('steps').textContent=String(game.steps).padStart(4,'0');draw();requestAnimationFrame(frame);}
requestAnimationFrame(frame);
globalThis.mapGame={get state(){return game.snapshot();},get level(){return LEVEL;},get engine(){return game;},get view(){return{zoom,offsetX,offsetY,W,H};},goTo,fit,locate,start:setStarted,reset};

export function unpackWalls(base64, size) {
  const bytes = typeof atob === 'function'
    ? Uint8Array.from(atob(base64), c => c.charCodeAt(0))
    : new Uint8Array(Buffer.from(base64, 'base64'));
  const walls = new Uint8Array(size);
  for (let i = 0; i < size; i++) walls[i] = (bytes[i >> 3] >> (i & 7)) & 1;
  return walls;
}

class MinHeap {
  constructor() { this.items = []; }
  push(id, score) {
    const item = {id, score}; let i = this.items.length; this.items.push(item);
    while (i > 0) { const parent = (i - 1) >> 1; if (this.items[parent].score <= score) break; this.items[i] = this.items[parent]; i = parent; }
    this.items[i] = item;
  }
  pop() {
    const first = this.items[0], last = this.items.pop();
    if (this.items.length) {
      let i = 0;
      while (true) { let child = i * 2 + 1; if (child >= this.items.length) break;
        if (child + 1 < this.items.length && this.items[child + 1].score < this.items[child].score) child++;
        if (this.items[child].score >= last.score) break;
        this.items[i] = this.items[child]; i = child;
      }
      this.items[i] = last;
    }
    return first;
  }
  get length() { return this.items.length; }
}

export class MazeGame {
  constructor(level, saved = null) {
    this.level = level; this.width = level.width; this.height = level.height;
    this.walls = level.walls instanceof Uint8Array ? level.walls : unpackWalls(level.wallsB64, this.width * this.height);
    this.position = {...level.start}; this.stars = new Set(); this.keys = new Set();
    this.openedDoors = new Set(); this.seenQuestions = new Set(); this.suppressedPortal = null;
    this.steps = 0; this.won = false;
    this.doorAt = new Int16Array(this.walls.length); this.doorAt.fill(-1);
    for (let d = 0; d < (level.doors || []).length; d++) {
      const door = level.doors[d], [x,y,w,h] = door.rect;
      for(let yy = Math.max(0,y); yy < Math.min(this.height,y+h); yy++)
        for(let xx = Math.max(0,x); xx < Math.min(this.width,x+w); xx++) this.doorAt[yy*this.width+xx] = d;
    }
    if (saved) this.restore(saved);
  }
  get allStars() { return this.stars.size === this.level.stars.length; }
  requiredKeys(door) { return door.requiredKeys || [door.key]; }
  index(x,y) { return y*this.width+x; }
  floor(x,y) {
    return Number.isInteger(x) && Number.isInteger(y) && x >= 0 && y >= 0 && x < this.width && y < this.height && !this.walls[this.index(x,y)];
  }
  door(x,y) {
    if (!this.floor(x,y)) return null;
    const id = this.doorAt[this.index(x,y)];
    return id < 0 ? null : this.level.doors[id];
  }
  near(a,b,r=2) { return (a.x-b.x)**2+(a.y-b.y)**2 <= r*r; }
  traversable(x,y) {
    if (!this.floor(x,y)) return false;
    const door = this.door(x,y);
    if (door && !this.openedDoors.has(door.id) && !this.requiredKeys(door).every(key=>this.keys.has(key))) return false;
    if (!this.allStars && this.near({x,y}, this.level.goal, this.level.goal.radius || 2)) return false;
    return true;
  }
  step(dx,dy) {
    if (this.won || Math.abs(dx)+Math.abs(dy) !== 1) return [];
    const x=this.position.x+dx, y=this.position.y+dy;
    if (!this.floor(x,y)) return [{type:'wall'}];
    const door=this.door(x,y), events=[];
    if (door && !this.openedDoors.has(door.id)) {
      const missing=this.requiredKeys(door).filter(key=>!this.keys.has(key));
      if (missing.length) return [{type:'locked', id:door.id, key:missing.join('、'), keys:missing}];
      this.openedDoors.add(door.id); events.push({type:'door',id:door.id,keys:this.requiredKeys(door)});
    }
    if (!this.allStars && this.near({x,y},this.level.goal,this.level.goal.radius || 2))
      return [{type:'goalLocked',remaining:this.level.stars.length-this.stars.size}];
    this.position={x,y}; this.steps++;
    events.push(...this.interact());
    return events;
  }
  interact() {
    const events=[];
    for (const item of this.level.stars) if (!this.stars.has(item.id) && this.near(this.position,item,item.radius || 2)) {
      this.stars.add(item.id); events.push({type:'star',id:item.id,total:this.stars.size,required:this.level.stars.length});
    }
    for (const item of this.level.keys || []) if (!this.keys.has(item.id) && this.near(this.position,item,item.radius || 2)) {
      this.keys.add(item.id); events.push({type:'key',id:item.id});
    }
    for (const item of this.level.questions || []) if (!this.seenQuestions.has(item.id) && this.near(this.position,item,item.radius || 2)) {
      this.seenQuestions.add(item.id); events.push({type:'question',id:item.id});
    }
    if (this.suppressedPortal) {
      const landing=this.level.portals.find(p=>p.id===this.suppressedPortal);
      if (!landing || !this.near(this.position,landing,(landing.radius || 2)+1)) this.suppressedPortal=null;
    }
    for (const portal of this.level.portals || []) {
      if (portal.id===this.suppressedPortal || !this.near(this.position,portal,portal.radius || 2)) continue;
      const number=portal.number+1;
      let target=this.level.portals.find(p=>p.number===number);
      if (!target && this.level.portalLoop) target=this.level.portals.find(p=>p.number===1);
      if (target) {
        this.position={x:target.x,y:target.y}; this.suppressedPortal=target.id;
        events.push({type:'portal',from:portal.number,to:target.number}); break;
      }
    }
    if (this.allStars && this.near(this.position,this.level.goal,this.level.goal.radius || 2)) {
      this.won=true; events.push({type:'win'});
    }
    return events;
  }
  nearestFloor(x,y,maxRadius=16,walkable=true) {
    x=Math.round(x);y=Math.round(y);
    const okay=(xx,yy)=>walkable?this.traversable(xx,yy):this.floor(xx,yy);
    for (let r=0;r<=maxRadius;r++) {
      let best=null,bestDist=Infinity;
      for(let yy=y-r;yy<=y+r;yy++) for(let xx=x-r;xx<=x+r;xx++) {
        if(r && Math.abs(xx-x)!==r && Math.abs(yy-y)!==r) continue;
        if(!okay(xx,yy)) continue;
        const dist=(xx-x)**2+(yy-y)**2;
        if(dist<bestDist){best={x:xx,y:yy};bestDist=dist;}
      }
      if(best) return best;
    }
    return null;
  }
  findPath(target, maxVisited=this.width*this.height) {
    const goal=this.nearestFloor(target.x,target.y,8,true); if(!goal) return null;
    const start=this.index(this.position.x,this.position.y), end=this.index(goal.x,goal.y);
    if(start===end) return [start];
    const size=this.walls.length, came=new Int32Array(size); came.fill(-1);
    const cost=new Float32Array(size);cost.fill(Infinity);
    const closed=new Uint8Array(size), heap=new MinHeap();
    cost[start]=0;heap.push(start,0);let visited=0;
    while(heap.length && visited<maxVisited){
      const {id}=heap.pop();if(closed[id]) continue;closed[id]=1;visited++;
      if(id===end){
        const path=[];let cursor=end;
        while(cursor!==-1){path.push(cursor);if(cursor===start)break;cursor=came[cursor];}
        return path.reverse();
      }
      const x=id%this.width,y=(id/this.width)|0;
      for(const [nx,ny] of [[x+1,y],[x-1,y],[x,y+1],[x,y-1]]){
        if(!this.traversable(nx,ny))continue;
        const next=this.index(nx,ny);if(closed[next])continue;
        const score=cost[id]+1;if(score>=cost[next])continue;
        cost[next]=score;came[next]=id;heap.push(next,score+Math.abs(nx-goal.x)+Math.abs(ny-goal.y));
      }
    }
    return null;
  }
  snapshot() {
    return {version:this.level.version,position:{...this.position},stars:[...this.stars],keys:[...this.keys],openedDoors:[...this.openedDoors],seenQuestions:[...this.seenQuestions],steps:this.steps,won:this.won,suppressedPortal:this.suppressedPortal};
  }
  restore(saved) {
    if(saved.version!==this.level.version || !saved.position || !this.floor(saved.position.x,saved.position.y))return;
    const valid=(values,items)=>new Set((Array.isArray(values)?values:[]).filter(id=>items.some(item=>item.id===id)));
    this.stars=valid(saved.stars,this.level.stars);this.keys=valid(saved.keys,this.level.keys||[]);
    this.openedDoors=valid(saved.openedDoors,this.level.doors||[]);
    this.seenQuestions=valid(saved.seenQuestions,this.level.questions||[]);
    this.position={...saved.position};this.steps=Math.max(0,Number(saved.steps)||0);
    this.won=Boolean(saved.won&&this.allStars&&this.near(this.position,this.level.goal,this.level.goal.radius||2));
    this.suppressedPortal=(this.level.portals||[]).some(p=>p.id===saved.suppressedPortal)?saved.suppressedPortal:null;
  }
}

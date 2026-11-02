import {readFile,writeFile} from 'node:fs/promises';
import {MazeGame} from '../src/engine.mjs';
const level=JSON.parse(await readFile(new URL('../src/level.generated.json',import.meta.url),'utf8'));
const game=new MazeGame(level);
const report={moves:0,events:[],stages:[],won:false};
const targets=[...level.keys,...level.stars];
for(let phase=0;phase<80&&!game.won;phase++){
 let candidates=targets.filter(t=>t.id.startsWith('s')?!game.stars.has(t.id):!game.keys.has(t.id));
 if(game.allStars)candidates.push({...level.goal,id:'goal'});
 candidates.sort((a,b)=>Math.abs(a.x-game.position.x)+Math.abs(a.y-game.position.y)-Math.abs(b.x-game.position.x)-Math.abs(b.y-game.position.y));
 let madeProgress=false;
 for(const target of candidates){
  const signature=game.keys.size+game.stars.size+game.openedDoors.size;
  const path=game.findPath(target);
  if(!path)continue;
  let teleported=false,walked=0;
  for(let i=1;i<path.length;i++){
   const id=path[i],x=id%level.width,y=(id/level.width)|0,dx=x-game.position.x,dy=y-game.position.y;
   if(Math.abs(dx)+Math.abs(dy)!==1)break;
   const events=game.step(dx,dy);walked++;report.moves++;
   for(const event of events)if(event.type!=='wall')report.events.push(event);
   if(events.some(e=>e.type==='portal')){teleported=true;break;}
   if(game.won)break;
  }
  const progress=game.keys.size+game.stars.size+game.openedDoors.size>signature||game.won;
  report.stages.push({target:target.id,walked,teleported,progress,position:{...game.position}});
  if(progress||teleported){madeProgress=true;break;}
 }
 if(!madeProgress)break;
}
report.won=game.won;report.stars=[...game.stars];report.keys=[...game.keys];report.doors=[...game.openedDoors];
await writeFile(new URL('../work/solve-report.json',import.meta.url),JSON.stringify(report,null,2));
console.log(JSON.stringify({won:report.won,moves:report.moves,stars:report.stars,keys:report.keys,doors:report.doors,stages:report.stages.length,lastStages:report.stages.slice(-6)}));
if(!report.won)process.exitCode=1;

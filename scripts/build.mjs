import {readFile,writeFile,mkdir} from 'node:fs/promises';
const root=new URL('../',import.meta.url);
const read=path=>readFile(new URL(path,root),'utf8');
const [template,css,engine,game,level]=await Promise.all(['src/index.html','src/style.css','src/engine.mjs','src/game.mjs','src/level.generated.json'].map(read));
const script=engine.replace(/\bexport /g,'')+'\n'+game.replace(/^import .+?;\s*$/gm,'');
const built=template.replace('/*__STYLE__*/',css).replace('/*__LEVEL__*/','const LEVEL = '+level+';').replace('/*__SCRIPT__*/',script);
await mkdir(new URL('dist/',root),{recursive:true});
await Promise.all(['dist/index.html','dist/map.html'].map(path=>writeFile(new URL(path,root),built)));
console.log(JSON.stringify({built:['dist/index.html','dist/map.html'],bytes:Buffer.byteLength(built),offline:true}));

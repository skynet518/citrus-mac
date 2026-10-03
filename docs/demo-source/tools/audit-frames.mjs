import {mkdir,writeFile} from 'node:fs/promises';
import {basename,resolve,join} from 'node:path';
import {createFileServer,createCaptureSession,initializeSession,closeCaptureSession} from '@hyperframes/producer';

const dir=resolve(process.argv[2]||'.');
const width=Number(process.argv[3]||1080), height=Number(process.argv[4]||1920);
const out=resolve(process.argv[5]||'.hyperframes/privacy');
await mkdir(out,{recursive:true});
const server=await createFileServer({projectDir:dir,port:0});
const session=await createCaptureSession(server.url,out,{width,height,fps:30,format:'png'},null);
try {
  await initializeSession(session);
  const report=await session.page.evaluate(()=>{
    const allowedAssets=new Set(['02-format-wheel.png','04-tools-wheel.png','05-crop-before.png',
      '07-crop-final.png','08-background-before.png','09-background-final.png','source.jpg','final.jpg']);
    const allowedFilenames=new Set(['Citrus Demo.pdf','Citrus Demo.jpg']);
    const root=document.querySelector('[data-composition-id]');
    const fps=30, duration=Number(root.dataset.duration), count=Math.round(duration*fps);
    const timelines=Object.values(window.__timelines);
    const textValues=[];
    const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);
    while(walker.nextNode()) {
      const value=walker.currentNode.nodeValue.trim();
      if(value) textValues.push(value);
    }
    const expectedText=JSON.stringify(textValues);
    const frames=[];
    const failures=[];
    const assetsSeen=new Set();
    function visible(el) {
      let opacity=1;
      for(let p=el;p&&p!==document.body;p=p.parentElement){const s=getComputedStyle(p);if(s.display==='none'||s.visibility==='hidden')return false;opacity*=Number(s.opacity);}
      return opacity>.01;
    }
    for(let frame=0;frame<count;frame++){
      const t=frame/fps;
      for(const timeline of timelines) timeline.seek(t);
      const active=[];
      for(const img of root.querySelectorAll('img')){
        const source=img.getAttribute('src');
        const name=source.split('/').pop();
        if(!source.startsWith('assets/')||!allowedAssets.has(name)) failures.push({frame,type:'unapproved-image'});
        if(visible(img)){active.push(name);assetsSeen.add(name);}
      }
      for(const name of root.querySelectorAll('.file-name')) if(!allowedFilenames.has(name.textContent.trim())) failures.push({frame,type:'unapproved-filename'});
      const current=[];const scan=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);
      while(scan.nextNode()){const text=scan.currentNode.nodeValue.trim();if(text)current.push(text);}
      if(JSON.stringify(current)!==expectedText)failures.push({frame,type:'unexpected-text-change'});
      if(current.some(t=>/\/(Users|home|Volumes)\//.test(t)))failures.push({frame,type:'absolute-user-path'});
      frames.push({frame,time:Number(t.toFixed(5)),activeAssets:[...new Set(active)].sort()});
    }
    return {audit:'Every rendered frame timestamp: media and text provenance',fps,duration,framesChecked:count,
      approvedFilenames:[...allowedFilenames],assetsSeen:[...assetsSeen].sort(),failureCount:failures.length,failures,frames};
  });
  report.composition=basename(dir);
  await writeFile(join(out,'frame-provenance.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({composition:report.composition,framesChecked:report.framesChecked,failureCount:report.failureCount,assets:report.assetsSeen.length}));
  if(report.failureCount)process.exitCode=1;
}finally{await closeCaptureSession(session).catch(()=>{});server.close();}

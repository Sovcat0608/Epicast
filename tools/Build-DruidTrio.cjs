// Package conversion only: exact approved pixels, alpha-aware separation, then
// the existing premultiplied Lanczos2 + maximum CAS recipe. No new painting.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {buildSize}=require('./artwork/Build-SkycutterSizes.cjs');
const {sharpen}=require('./artwork/Build-SkycutterCAS.cjs');
const root=path.resolve(__dirname,'..'),out=path.join(root,'artifacts/druid-trio-v8');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const sourcePNG=fs.readFileSync(path.join(root,'concepts/druid-specialization-trio/Druid-specializations-review-v8.png'));
if(hash(sourcePNG)!=='4d592a779782dd20fa9b0bcbd38ce7b018613397ea53a53e0abc77e4c76cbfc8')throw Error('Approved source changed');
const source=fs.readFileSync(path.join(out,'approved.bgra')),sw=1882,sh=836,w=660,h=880;
if(source.length!==sw*sh*4)throw Error('Wrong decoded source dimensions');
const seen=new Uint8Array(sw*sh),components=[];
const neighbors=n=>{const x=n%sw,y=Math.floor(n/sw);return [x? n-1:-1,x<sw-1?n+1:-1,y?n-sw:-1,y<sh-1?n+sw:-1].filter(v=>v>=0);};
for(let p=0;p<seen.length;p++){
 if(seen[p]||source[p*4+3]<8)continue;
 const pixels=[p];seen[p]=1;let bounds=[sw,sh,0,0];
 for(let i=0;i<pixels.length;i++){
  const n=pixels[i],x=n%sw,y=Math.floor(n/sw);
  bounds=[Math.min(bounds[0],x),Math.min(bounds[1],y),Math.max(bounds[2],x+1),Math.max(bounds[3],y+1)];
  for(const q of neighbors(n))if(!seen[q]&&source[q*4+3]>=8){seen[q]=1;pixels.push(q);}
 }
 if(pixels.length>10000)components.push({pixels,bounds});
}
components.sort((a,b)=>a.bounds[0]-b.bounds[0]);
if(components.length!==3)throw Error('Expected three disconnected crest silhouettes');
// The leaves overlap column boundaries but do not touch. Nearest-component
// assignment preserves antialiasing and tiny detached details without slicing tips.
const owner=new Uint8Array(sw*sh),queue=new Int32Array(sw*sh);let tail=0;
components.forEach((part,i)=>part.pixels.forEach(p=>{owner[p]=i+1;queue[tail++]=p;}));
for(let i=0;i<tail;i++){const p=queue[i];for(const q of neighbors(p))if(!owner[q]){owner[q]=owner[p];queue[tail++]=q;}}
const manifestPath=path.join(__dirname,'media-manifest.json'),manifest=JSON.parse(fs.readFileSync(manifestPath));
const report={sourceSHA256:hash(sourcePNG),sourceSize:[sw,sh],canvasSize:[w,h],method:'nearest disconnected alpha silhouette, unchanged source pixels; Lanczos2 + CAS 1.0 / 0.65',artworks:{}};
for(const [i,name]of ['DruidRestoration','DruidBalance','DruidFeral'].entries()){
 const bounds=components[i].bounds,x0=Math.round((bounds[0]+bounds[2]-w)/2),y0=-22;
 const pixels=Buffer.alloc(w*h*4);let droppedVisible=0;
 for(let p=0;p<owner.length;p++)if(owner[p]===i+1&&source[p*4+3]){
  const x=p%sw-x0,y=Math.floor(p/sw)-y0;
  if(x<0||x>=w||y<0||y>=h){if(source[p*4+3]>=8)droppedVisible++;continue;}
  source.copy(pixels,(y*w+x)*4,p*4,p*4+4);
 }
 if(droppedVisible)throw Error('Clipped visible artwork: '+name);
 fs.writeFileSync(path.join(out,name+'.bgra'),pixels);
 const entry=report.artworks[name]={sourceOrigin:[x0,y0],visibleBounds:[bounds[0]-x0,bounds[1]-y0,bounds[2]-x0,bounds[3]-y0],droppedVisible,sizes:[]};
 for(const width of [192,288,384,480,576,660]){
  const height=width*4/3,base=buildSize(pixels,w,h,width,height),tga=sharpen(base,width,height);
  for(let p=21;p<tga.length;p+=4)if(tga[p]!==base[p])throw Error('CAS changed alpha');
  const file=`Media/${name}CASSize${width}.tga`;fs.writeFileSync(path.join(root,file),tga);
  manifest[file]={bytes:tga.length,sha256:hash(tga)};entry.sizes.push({width,height,...manifest[file]});
 }
 console.log(name+': '+entry.visibleBounds.join(', ')+'; six prepared sizes, no clipped visible pixels');
}
fs.writeFileSync(manifestPath,JSON.stringify(manifest,null,2)+'\n');
fs.writeFileSync(path.join(out,'bake-verification.json'),JSON.stringify(report,null,2)+'\n');

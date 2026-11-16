// Deterministic package conversion of the user's uncorrected option 1 only.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {buildSize}=require('./artwork/Build-SkycutterSizes.cjs');
const {sharpen}=require('./artwork/Build-SkycutterCAS.cjs');
const root=path.resolve(__dirname,'..'),out=path.join(root,'artifacts/mage-reboot-option1');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const png=fs.readFileSync(path.join(root,'concepts/mage-reboot/Mage-reboot-trio-v3-initial.png'));
if(hash(png)!=='5dd9d15c1d72c67efb83dfa664e235e450b36c8b8c1c3bbc7cc017b2a2d3f5ac')throw Error('Wrong approved Mage source');
const source=fs.readFileSync(path.join(out,'approved.bgra')),sw=2172,sh=724,tile=724,pad=22,canvas=768;
if(source.length!==sw*sh*4)throw Error('Wrong decoded source dimensions');
const sizes=[192,288,384,480,576,768],manifestPath=path.join(__dirname,'media-manifest.json');
const manifest=JSON.parse(fs.readFileSync(manifestPath)),definitions=[];
const report={source:'concepts/mage-reboot/Mage-reboot-trio-v3-initial.png',sourceSHA256:hash(png),sourceSize:[sw,sh],canvasSize:[canvas,canvas],padding:pad,
 method:'Three 724-square source columns, all source pixels retained once, 22px transparent padding; premultiplied Lanczos2 then CAS sharpness 1.0/blend 0.65',artworks:{}};
for(const [i,spec]of ['Frost','Fire','Arcane'].entries()){
 const name='MageReboot'+spec,pixels=Buffer.alloc(canvas*canvas*4),bounds=[canvas,canvas,0,0];
 let visible=0,sourceEdge=0,internalSeam=0;
 for(let y=0;y<sh;y++)for(let x=0;x<tile;x++){
  const sx=i*tile+x,p=(y*sw+sx)*4,q=((y+pad)*canvas+x+pad)*4;
  source.copy(pixels,q,p,p+4);
  if(source[p+3]>=8){
   visible++;bounds[0]=Math.min(bounds[0],x+pad);bounds[1]=Math.min(bounds[1],y+pad);
   bounds[2]=Math.max(bounds[2],x+pad+1);bounds[3]=Math.max(bounds[3],y+pad+1);
   if(sx===0||sx===sw-1||y===0||y===sh-1)sourceEdge++;
   if((x===0&&i>0)||(x===tile-1&&i<2))internalSeam++;
  }
 }
 if(internalSeam)throw Error('Column separation intersects visible artwork: '+spec);
 fs.writeFileSync(path.join(out,name+'.bgra'),pixels);
 const item=report.artworks[spec]={name,sourceOrigin:[i*tile,0],visibleBounds:bounds,sourceVisiblePixels:visible,sourceVisibleEdgePixels:sourceEdge,internalSeamPixels:internalSeam,droppedSourcePixels:0,canvasSHA256:hash(pixels),sizes:[]};
 for(const width of sizes){
  const base=buildSize(pixels,canvas,canvas,width,width),tga=sharpen(base,width,width);
  for(let p=21;p<tga.length;p+=4)if(tga[p]!==base[p])throw Error('CAS changed alpha');
  const file=`Media/${name}CASSize${width}.tga`;fs.writeFileSync(path.join(root,file),tga);
  manifest[file]={bytes:tga.length,sha256:hash(tga)};item.sizes.push({width,height:width,...manifest[file]});
 }
 definitions.push(` mage${spec}={name="${name}",bounds={${bounds.join(',')}},sourceWidth=768,sourceHeight=768,width=216,height=216,sizes={${sizes.join(',')}}}`);
 console.log(spec+': source column '+i+', bounds '+bounds.join(',')+', six textures; all source pixels preserved');
}
fs.writeFileSync(path.join(root,'MageRebootData.lua'),'local _,E=...\n-- Generated from the exact approved uncorrected option 1. Do not substitute later edits.\nE.MageRebootArtworks={\n'+definitions.join(',\n')+'\n}\n');
fs.writeFileSync(manifestPath,JSON.stringify(manifest,null,2)+'\n');
fs.writeFileSync(path.join(out,'bake-verification.json'),JSON.stringify(report,null,2)+'\n');

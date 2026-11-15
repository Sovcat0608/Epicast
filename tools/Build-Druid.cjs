// Exact approved sheet split into equal 768x1024 canvases. No repainting,
// rescaling relative to the sister, new emissions, or invented effects.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {buildSize}=require('./artwork/Build-SkycutterSizes.cjs');
const {sharpen}=require('./artwork/Build-SkycutterCAS.cjs');
const root=path.join(__dirname,'..');
const source=fs.readFileSync(path.join(root,'artifacts/druid/approved.bgra'));
if(source.length!==1536*1024*4)throw Error('Expected approved 1536x1024 BGRA');
const manifestPath=path.join(__dirname,'media-manifest.json');
const manifest=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
const report={sourceSHA256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,'concepts/druid-sisters/Moonwarden-Groveheart-review.png'))).digest('hex'),artworks:{}};
if(report.sourceSHA256!=='926c6cc974fcd6015a1ae576e52123c7c4f2a157decadd3f0cb5f92dca157034')throw Error('Approved source changed');
for(const [side,name]of ['Moonwarden','Groveheart'].entries()){
 const pixels=Buffer.alloc(768*1024*4),bounds=[768,1024,0,0];
 for(let y=0;y<1024;y++){
  source.copy(pixels,y*768*4,(y*1536+side*768)*4,(y*1536+(side+1)*768)*4);
  for(let x=0;x<768;x++)if(pixels[(y*768+x)*4+3]>=8){bounds[0]=Math.min(bounds[0],x);bounds[1]=Math.min(bounds[1],y);bounds[2]=Math.max(bounds[2],x+1);bounds[3]=Math.max(bounds[3],y+1);}
 }
 report.artworks[name]={sourceRectangle:[side*768,0,768,1024],visibleBounds:bounds,sizes:[]};
 for(const w of [192,288,384,480,576,768]){
  const h=w*4/3,base=buildSize(pixels,768,1024,w,h),tga=sharpen(base,w,h);
  for(let p=21;p<tga.length;p+=4)if(tga[p]!==base[p])throw Error('CAS changed alpha');
  const file=`Media/${name}CASSize${w}.tga`;
  fs.writeFileSync(path.join(root,file),tga);
  manifest[file]={bytes:tga.length,sha256:crypto.createHash('sha256').update(tga).digest('hex')};
  report.artworks[name].sizes.push({width:w,height:h,backingWidth:tga.readUInt16LE(12),backingHeight:tga.readUInt16LE(14),...manifest[file]});
 }
 console.log(`${name}: exact half-sheet, visible bounds ${bounds.join(', ')}, six CAS sizes`);
}
fs.writeFileSync(manifestPath,JSON.stringify(manifest,null,2)+'\n');
fs.writeFileSync(path.join(root,'artifacts/druid/bake-verification.json'),JSON.stringify(report,null,2)+'\n');

const canvas=document.querySelector('canvas'),getContext=canvas.getContext.bind(canvas);
window.diagnostics={errors:[],frames:0,creates:0};
canvas.getContext=(type,options)=>getContext(type,type.startsWith('webgl')?{...options,alpha:true,premultipliedAlpha:true,preserveDrawingBuffer:true}:options);
var Module={canvas,locateFile:p=>'/vendor/'+p,print:()=>{},printErr:s=>diagnostics.errors.push(String(s)),hammerJsAssignControl:()=>{},animationArrayCallback:()=>{},meshIdArrayCallback:()=>{},onRuntimeInitialized(){
 Module.hammerJsAssignControl=()=>{};function str(s){const b=new TextEncoder().encode(s+'\0'),p=Module._malloc(b.length);Module.HEAPU8.set(b,p);return p;}
 const a=str('/missing-name?name='),b=str('/asset?id=');Module._createWebJsScene(640,360,a,b);Module._free(a);Module._free(b);Module._setFarPlane(20000);Module._setFarPlaneForCulling(20000);
 window.engineReady=true;
}};
let pointer=0;function studioPointer(){if(!pointer)pointer=Module._malloc(38*4);return pointer;}
window.create=id=>{diagnostics.creates++;return Module._studioCreate(id);};
window.remove=id=>Module._studioRemove(id);
window.configure=(id,c,opacity,desat)=>{new Float32Array(Module.HEAPU8.buffer,studioPointer(),38).set(c.values);Module._studioConfigure(id,pointer,opacity,desat||0);};
window.animation=(id,seq)=>Module._studioAnimation(id,seq);
window.debug=id=>{Module._studioDebug(id,studioPointer());return [...new Float32Array(Module.HEAPU8.buffer,pointer,8)];};
window.order=ids=>{new Int32Array(Module.HEAPU8.buffer,studioPointer(),ids.length).set(ids);Module._studioSetOrder(pointer,ids.length);};
window.artwork=(pixels,w,h,desaturation=0,flip=false)=>{
 const rgba=new Uint8Array(pixels);
 for(let i=0;i<rgba.length;i+=4){
  if(flip){
   const x=(i/4)%w;
   const source=i+(w-1-2*x)*4;
   rgba.set(pixels.subarray(source,source+4),i);
  }
  const alpha=rgba[i+3]/255;
  const gray=.299*rgba[i]+.587*rgba[i+1]+.114*rgba[i+2];
  for(let channel=0;channel<3;channel++){
   const original=rgba[i+channel];
   rgba[i+channel]=(original+(gray-original)*desaturation)*alpha;
  }
 }
 const pointer=Module._malloc(rgba.length);
 Module.HEAPU8.set(rgba,pointer);
 Module._studioArtwork(w,h,pointer);
 Module._free(pointer);
};
window.artRect=(...args)=>Module._studioArtworkRect(...args);
window.frame=(dt,w,h)=>{const density=Math.min(devicePixelRatio,1.5),width=Math.round(w*density),height=Math.round(h*density);if(canvas.width!==width||canvas.height!==height){canvas.width=width;canvas.height=height;Module._setSceneSize(width,height);}Module._studioFrame(dt,width,height);diagnostics.frames++;};
window.inspect=()=>{const gl=Module.ctx||getContext('webgl2'),pixels=new Uint8Array(canvas.width*canvas.height*4);gl.readPixels(0,0,canvas.width,canvas.height,gl.RGBA,gl.UNSIGNED_BYTE,pixels);let rgb=0,sum=0;for(let i=0;i<pixels.length;i+=4){const v=pixels[i]+pixels[i+1]+pixels[i+2];sum+=v;if(v>6)rgb++;}return{rgb,sum,error:gl.getError(),width:canvas.width,height:canvas.height};};

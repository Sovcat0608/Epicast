// One renderer per iframe: the upstream WASM exposes a single scene singleton.
// Keep real WoW materials/particles; do not substitute procedural effects.
const params=new URLSearchParams(location.search),id=Number(params.get('id'));
const canvas=document.querySelector('canvas');
window.diagnostics={id,ready:false,animations:[],errors:[],frames:0,replays:0,sceneLoads:0};
window.addEventListener('error',e=>diagnostics.errors.push(e.message));
// Upstream creates an opaque canvas by default. Only change its presentation
// attributes; all native material/shader blending is left intact.
const getContext=canvas.getContext.bind(canvas);
canvas.getContext=function(type,options){const gl=getContext(type,type.startsWith('webgl')?{...options,alpha:true,premultipliedAlpha:true,preserveDrawingBuffer:true}:options);if(gl&&type.startsWith('webgl')&&!gl.epicastTransparent){const clear=gl.clearColor.bind(gl);gl.clearColor=(r,g,b,a)=>clear(r,g,b,0);gl.epicastTransparent=true;}return gl;};
var Module={canvas,locateFile:p=>'/vendor/'+(params.has('upstream')?'upstream/':'')+p,print:()=>{},printErr:s=>diagnostics.errors.push(String(s)),hammerJsAssignControl:()=>{},
 animationArrayCallback:a=>{diagnostics.animations=[...a];diagnostics.ready=true;},meshIdArrayCallback:()=>{},
 onRuntimeInitialized(){
  // The bundled pre-js installs Hammer controls. This embedded viewport has no
  // independent pointer navigation; the parent owns its placement and camera.
  Module.hammerJsAssignControl=()=>{};
  const utf8=s=>{const bytes=new TextEncoder().encode(s+'\0'),p=Module._malloc(bytes.length);Module.HEAPU8.set(bytes,p);return p;};
  const a=utf8('/missing-name?name='),b=utf8('/asset?id=');
  Module._createWebJsScene(384,384,a,b);Module._free(a);Module._free(b);
  canvas.width=384;canvas.height=384;
  Module._setSceneSize(384,384);Module._setClearColor(0,0,0);Module._setFarPlane(20000);Module._setFarPlaneForCulling(20000);
  Module._setSceneFileDataId(0,id,-1);diagnostics.sceneLoads++;
  window.engineReady=true;
 }
};
window.tick=dt=>{if(!window.engineReady)return;Module._gameloop(dt);diagnostics.frames++;};
let cameraPointer=0,debugPointer=0,lastCamera='';
window.configure=(c,width,height)=>{
 if(!window.engineReady||params.has('autofit')||params.has('upstream'))return;
 const density=Math.min(devicePixelRatio,2),w=Math.round(width*density),h=Math.round(height*density);
 const key=JSON.stringify([w,h,c.values]);if(key===lastCamera)return false;lastCamera=key;
 if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;Module._setSceneSize(w,h);}
 if(!cameraPointer)cameraPointer=Module._malloc(38*4);
 new Float32Array(Module.HEAPU8.buffer,cameraPointer,38).set(c.values);
 Module._setEpicastCamera(cameraPointer);
 diagnostics.viewport={width:w,height:h,cssWidth:width,cssHeight:height};
 return true;
};
window.replay=animation=>{if(!window.engineReady)return;Module._setAnimationId(animation);diagnostics.replays++;diagnostics.lastSequence=animation;};
window.coldReload=()=>{Module._setSceneFileDataId(0,id,-1);lastCamera='';diagnostics.sceneLoads++;diagnostics.ready=false;};
window.inspectPixels=()=>{
 const gl=Module.ctx||getContext('webgl2')||getContext('webgl'),pixels=new Uint8Array(canvas.width*canvas.height*4);gl.readPixels(0,0,canvas.width,canvas.height,gl.RGBA,gl.UNSIGNED_BYTE,pixels);
 let rgb=0,alpha=0,zeroAlphaRGB=0,sum=0,signature=2166136261;for(let i=0;i<pixels.length;i+=4){const v=pixels[i]+pixels[i+1]+pixels[i+2];if(v>6)rgb++;if(pixels[i+3])alpha++;if(v>6&&!pixels[i+3])zeroAlphaRGB++;sum+=v;signature=Math.imul(signature^v,16777619)>>>0;}
 const ext=gl.getExtension('WEBGL_debug_renderer_info');
 let debug=null;
 if(Module._getEpicastDebug){if(!debugPointer)debugPointer=Module._malloc(8*4);Module._getEpicastDebug(debugPointer);debug=[...new Float32Array(Module.HEAPU8.buffer,debugPointer,8)];}
 return {rgb,alpha,zeroAlphaRGB,sum,signature,debug,corner:[...pixels.slice(0,4)],context:gl.getContextAttributes(),renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),error:gl.getError()};
};

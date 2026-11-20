// Equivalent of NativeEffects.lua + Effects.lua's doubled ModelScene viewport.
// Values are model units and CSS pixels, independent of framebuffer density.
(function(root){
 const dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0);
 function camera(row,{width,height,artWidth,kind,zoom=1,hover=0,follow=true,flip=false,frameScale,center}){
  const d=flip?-1:1,rad=Math.PI/180;
  const az=(row.azimuth||0)*rad,el=(row.elevation||0)*rad,a=(row.trailAngle??90)*rad;
  const sa=Math.sin(az),ca=Math.cos(az),se=Math.sin(el),ce=Math.cos(el),sn=Math.sin(a),cs=Math.cos(a);
  const forward=[d*sa*ce,d*ca*ce,-se],base=[d*ca,-d*sa,0],vertical=[d*sa*se,d*ca*se,ce];
  const right=base.map((v,i)=>v*sn+vertical[i]*d*cs),up=base.map((v,i)=>-v*d*cs+vertical[i]*sn);
  const scale=row.scale,origin=[row.originX,row.originY,row.originZ];
  if(!(scale>0)||!origin.every(Number.isFinite))throw Error('Invalid model calibration');
  const eye=origin.map((v,i)=>v-forward[i]*8/scale);
  const factor=frameScale??artWidth/(kind==='restoration'?162:216)*zoom;
  const viewport=864*factor*row.trailSize/100;
  const [cx,cy]=center??[width/2,height/2+30*factor];
  const anchor=[cx+1.5*row.trailX*factor*d,cy-1.5*row.trailY*factor-(follow?hover*zoom:0)];
  const near=.01/scale,far=100/scale;
  const view=[right[0],up[0],-forward[0],0,right[1],up[1],-forward[1],0,right[2],up[2],-forward[2],0,-dot(right,eye),-dot(up,eye),dot(forward,eye),1];
  const projection=[viewport/width/.375,0,0,0,0,viewport/height/.375,0,0,1-2*anchor[0]/width,2*anchor[1]/height-1,-(far+near)/(far-near),-1,0,0,-2*far*near/(far-near),0];
  return {values:[...view,...projection,...eye,...up],view,projection,eye,right,up,forward,anchor,viewport,near,far,factor};
 }
 function project(point,c,width,height){
  const mul=(m,v)=>[0,1,2,3].map(r=>v.reduce((s,x,k)=>s+m[k*4+r]*x,0));
  const p=mul(c.projection,mul(c.view,[...point,1]));return [(p[0]/p[3]+1)*width/2,(1-p[1]/p[3])*height/2,p[2]/p[3]];
 }
 const api={camera,project};if(typeof module!=='undefined')module.exports=api;else root.EpicastProjection=api;
})(globalThis);

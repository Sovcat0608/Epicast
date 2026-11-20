// Assemble the six independent, registered bitmap tracks behind the carved boughs.
function loadCrown(spec) {
  const get = name => loadImage("crown/" + name + ".webp");
  const trial = name => loadImage("crown-ludo/" + name + ".webp");
  const useLudo = new URLSearchParams(location.search).get("crown") !== "krita";
  const back = get("back"), front = get("front"), nibs = get("nibs");
  const region = useLudo ? trial("all-region") : get("region");
  const tracks = spec.tracks.map(t => {
    if (!useLudo) return {...t, paint:get(t.prefix), contact:get(t.prefix+"-contact")};
    const prefix = t.prefix === "leaf-8" ? "" : t.prefix + "-";
    return {...t, columns:4, frames:spec.tracks[0].frames,
      paint:trial(prefix+"paint"), contact:trial(prefix+"contact")};
  });
  const images = [back,front,nibs,region,...tracks.flatMap(t=>[t.paint,t.contact])];
  const [width,height] = spec.size;
  function surface(w = width,h = height) {
    const el = document.createElement("canvas");
    el.width = w;
    el.height = h;
    return el.getContext("2d");
  }
  const patch = surface();
  const poses = [];
  function frameAt(ms) {
    return Math.floor((ms % spec.period)/spec.frameMs);
  }
  function drawCrown(frame) {
    if (poses[frame]) return poses[frame];
    const scene = surface();
    const cels = tracks.map(t => t.frames[(frame-t.delay+t.frames.length)%t.frames.length]);
    function drawTile(target, index, key, ox, oy) {
      const t = tracks[index], [x,y,w,h] = t.slot, cel = cels[index];
      target.drawImage(animationImage(t[key]),(cel%t.columns)*w,Math.floor(cel/t.columns)*h,w,h,x-ox,y-oy,w,h);
    }
    scene.drawImage(back,0,0);
    scene.globalCompositeOperation = "source-atop";
    tracks.forEach((_,i)=>drawTile(scene,i,"contact",0,0));
    scene.globalCompositeOperation = "source-over";
    tracks.forEach((t,i)=>{
      const [x,y,w,h] = t.slot;
      const receiver = surface(w,h);
      drawTile(receiver,i,"paint",x,y);
      receiver.globalCompositeOperation = "source-atop";
      t.casters.forEach(j=>drawTile(receiver,j,"contact",x,y));
      scene.drawImage(receiver.canvas,x,y);
    });
    scene.drawImage(front,0,0);
    poses[frame] = scene.canvas;
    return scene.canvas;
  }
  function draw(target,frame,drawFeathers) {
    patch.clearRect(0,0,width,height);
    drawFeathers(patch);
    patch.drawImage(nibs,0,0);
    patch.drawImage(drawCrown(frame),0,0);
    patch.globalCompositeOperation = "destination-in";
    patch.drawImage(region,0,0);
    patch.globalCompositeOperation = "source-over";
    target.save();
    target.globalCompositeOperation = "destination-out";
    target.drawImage(region,0,0);
    target.globalCompositeOperation = "source-over";
    target.drawImage(patch.canvas,0,0);
    target.restore();
  }
  return {images,frameAt,draw};
}

const byId = id => document.getElementById(id);
const crest = byId("crest"), detail = byId("detail");
const ctx = crest.getContext("2d"), zoom = detail.getContext("2d");
const channelAtlases = new Map();
function animationImage(image) {
  return channelAtlases.get(image.src) || image;
}
function loadImage(src) {
  const image = new Image();
  image.src = src;
  return image;
}
const previewURL = new URL(location.href);
const cheeksVisible = previewURL.searchParams.get("cheeks") === "show";
const hiddenCheekAssets = "cheek-layout/hidden/";
const master = loadImage(cheeksVisible ? "cheek-layout/crest.webp" : hiddenCheekAssets + "crest.webp");
const cheekButton = byId("show-cheeks");
cheekButton.textContent = cheeksVisible ? "Hide cheek leaves" : "Show cheek leaves";
cheekButton.onclick = () => {
  if (cheeksVisible) previewURL.searchParams.delete("cheeks");
  else previewURL.searchParams.set("cheeks", "show");
  location.href = previewURL.href;
};
function loadClip(data) {
  const clusters = data.clusters.map(cluster => ({
  slot: cluster.slot,
  cover: loadImage(cluster.cover),
  tracks: cluster.tracks.map(track => ({
    ...track, art: loadImage(track.sheet), period: track.frames.reduce((sum, f) => sum + f.ms, 0)
  }))
  }));
  return {clusters, tracks: clusters.flatMap(c => c.tracks), columns: data.columns, fps: data.fps,
          nextState: data.nextState};
}
const states = {Idle: loadClip(animation), Channel: loadClip(channel), Impact: loadClip(impact)};
const legacyCrown = new URLSearchParams(location.search).has("crown");
const crown = legacyCrown ? loadCrown(crownIdle) : loadShoulderStudy();
const showRightCrown = !legacyCrown && !previewURL.searchParams.has("solo");
const modernMotion = showRightCrown && previewURL.searchParams.get("motion") !== "base" &&
  typeof restorationMotion !== "undefined";
const treantMotion = modernMotion ? loadTreantRest(treantRestCycle,cheeksVisible) : null;
const treantTrack = treantMotion || treantIdle;
const treant = treantMotion ? null :
  loadImage(cheeksVisible ? treantIdle.sheet : hiddenCheekAssets + "treant-idle.webp");
const rejuvenation = modernMotion ? loadRejuvenationMotion(restorationMotion.rejuvenation) : null;
const crownSymbol = modernMotion ? loadCrownSymbol(restorationCrownSymbol) : null;
function loadOverlay(track) {
  const image = loadImage(track.sheet), mask = loadImage(track.coverage);
  const buffer = track.redrawFeathers ? document.createElement("canvas") : null;
  if (buffer) [buffer.width,buffer.height] = track.slot.slice(2);
  return {...track,image,mask,buffer};
}
function cheekOverlay(track, name) {
  if (cheeksVisible) return loadOverlay(track);
  const file = hiddenCheekAssets + name;
  return loadOverlay({...track,sheet:file+"-scene.webp",coverage:file+"-coverage.webp"});
}
const channelTreant = treantMotion ? null : cheekOverlay(crestMotionBatch.treant,"treant-channel");
const impactTreant = treantMotion ? null : cheekOverlay(treantImpact,"treant-impact");
const ambient = [cheekOverlay(crestMotionBatch.vines,"vines-idle"),...fabricFlagIdle.map(loadOverlay)];
const channelFabric = fabricFlagChannel.map(loadOverlay);
const impactFabric = fabricFlagImpact.tracks.map(loadOverlay);
const woodShards = loadWoodChannel(cheeksVisible,treantMotion);
function overlayCel(track, time) {
  if (track.durations) {
    let position = time % track.period;
    for (let i = 0; i < track.durations.length; i++) {
      if (position < track.durations[i]) return i;
      position -= track.durations[i];
    }
  }
  return Math.floor((time + .0001) / track.frameMs) % track.frames;
}
function drawOverlay(target, track, cel, drawBehind, amount = 1) {
  const [x,y,w,h] = track.slot;
  const sx = cel%track.columns*w, sy = Math.floor(cel/track.columns)*h;
  target.save();
  target.globalCompositeOperation = "destination-out";
  target.globalAlpha = amount;
  target.drawImage(animationImage(track.mask),x,y);
  target.restore();
  if (!drawBehind) {
    target.save();
    if (amount < 1) target.globalCompositeOperation = "lighter";
    target.globalAlpha = amount;
    target.drawImage(animationImage(track.image),sx,sy,w,h,x,y,w,h);
    target.restore();
    return;
  }
  // Restore the currently moving quills under this foreground patch.
  const patch = track.buffer.getContext("2d");
  patch.clearRect(0,0,w,h);
  patch.save();
  patch.translate(-x,-y);
  drawBehind(patch);
  patch.restore();
  patch.drawImage(animationImage(track.image),sx,sy,w,h,0,0,w,h);
  patch.save();
  patch.globalCompositeOperation = "destination-in";
  patch.drawImage(animationImage(track.mask),0,0);
  patch.restore();
  target.save();
  if (amount < 1) target.globalCompositeOperation = "lighter";
  target.globalAlpha = amount;
  target.drawImage(track.buffer,x,y);
  target.restore();
}
const rightCrown = showRightCrown ? loadImage(rightCrownIdle.sheet) : null;
const rightCrownCoverage = showRightCrown ? loadImage(rightCrownIdle.coverage) : null;
const innerFans = showRightCrown ? innerLeafIdle.map(loadOverlay) : [];
const leafSheets = modernMotion ? wanLeafUncovered : wanLeafPreview;
const leafTracks = showRightCrown ? {
  Channel: loadOverlay(leafSheets.channel),
  Impact: loadOverlay(leafSheets.impact)
} : {};
const detailViews = {crown: [0, 0, ...crownIdle.size], treant: treantTrack.slot, wood: [72,760,980,208]};
byId("focus").add(new Option("Carved wood shards","wood"));
byId("focus").prepend(new Option("Treant", "treant"));
if (rejuvenation) {
  detailViews.rejuvenation = rejuvenation.slot;
  byId("focus").add(new Option("Rejuvenation leaf","rejuvenation"));
}
if (crownSymbol) {
  detailViews["crown-symbol"] = crownSymbol.slot;
  byId("focus").add(new Option("Crown symbol","crown-symbol"));
}
for (const [index, name] of ["Hanging vines", "Left fabric banner", "Right fabric banner"].entries()) {
  const id = "ambient-" + index;
  detailViews[id] = ambient[index].slot;
  byId("focus").add(new Option(name,id));
}
if (showRightCrown) {
  const comparison = document.querySelector("figcaption a");
  comparison.href = "../../artifacts/restoration-leaf-wan-refinement/index.html";
  comparison.textContent = "Compare leaf animations";
  detailViews["right-crown"] = rightCrownIdle.slot;
  byId("focus").prepend(new Option("Upper-right green leaves", "right-crown"));
  detailViews["inner-fans"] = [247,229,642,276];
  byId("focus").prepend(new Option("Both inner leaf fans","inner-fans"));
  for (const [i,side] of ["Left","Right"].entries()) {
    const id="inner-fan-"+i;
    detailViews[id]=innerFans[i].slot;
    byId("focus").add(new Option(side+" inner leaf fan",id));
  }
  detailViews["cheeks"] = [310,805,535,398];
  byId("focus").prepend(new Option("Treant and charms","cheeks"));
  byId("focus").value = "crown";
}
if (crown.segment) detailViews.segment = crown.segment;
if (crown.rightSegment) detailViews["right-shoulder"] = crown.rightSegment;
byId("focus").add(new Option("Left feathers", "left-feathers"));
detailViews["left-feathers"] = [-120, 408, 426, 417];
for (const track of legacyCrown ? crownIdle.tracks : []) {
  const [x, y, w, h] = track.slot;
  const top = Math.max(0, y);
  detailViews[track.prefix] = [x, top, w, h + y - top];
  byId("focus").add(new Option(track.name, track.prefix));
}
const sideMargin = 160;
const playback = new ChannelPlayback(showRightCrown ? 1 : crownIdle.period / leafChannel[0].period);
const durationInput = byId("channel-duration");
const transitionSurfaces = [document.createElement("canvas"),document.createElement("canvas")];
let state = "Idle";
let crownTime = 0, treantTime = 0, ambientTime = 0, idleTime = 0, impactTime = 0;
let impactSymbolStart, treantReleaseFrom;
let leafIdleStart = 0, bannerIdleStart;
let playing = true, reference = false, lastTime, lastPose, lastScene, request;
let channelReady = false;

function celAt(track, time) {
  let t = ((time - track.delay) % track.period + track.period) % track.period;
  for (const frame of track.frames) {
    if (t < frame.ms) return frame.cel;
    t -= frame.ms;
  }
}

function framePose(mode,time,crownFrame,glow) {
  const clip = states[mode];
  const isChannel = mode === "Channel";
  const treantCel = treantMotion?.sample(mode,time,treantTime,playback,treantReleaseFrom);
  const treantFrame = treantCel ? treantCel.key :
    isChannel ? overlayCel(channelTreant,time) : overlayCel(treantTrack,treantTime);
  const overlays = isChannel ? [ambient[0],...channelFabric] : ambient;
  const overlayFrames = overlays.map((track,index)=>{
    if (index===0) return overlayCel(track,ambientTime);
    if (isChannel) return overlayCel(track,time);
    if (bannerIdleStart===undefined) return overlayCel(track,ambientTime);
    return overlayCel(track,idleTime-bannerIdleStart+fabricFlagImpact.idleReturn[index-1]*track.frameMs);
  });
  const featherFrames = clip.tracks.map(track=>celAt(track,time));
  const isImpact = mode === "Impact";
  const treantImpactCel = isImpact && impactTreant ? overlayCel(impactTreant,time) : null;
  const bannerImpactCel = isImpact ? overlayCel(impactFabric[0],time) : null;
  const leafTrack = leafTracks[mode];
  const leafCel = leafTrack ? overlayCel(leafTrack,time) : null;
  const leafMix = isImpact && leafTrack ? leafImpact.mix[leafCel] : 1;
  // Both compositing passes use the same leaf and shadow during Channel ramps.
  const rejuvenationPose = rejuvenation && rejuvenation.sample(state==="Channel" ? state : mode,
    time,idleTime-leafIdleStart,idleTime,playback);
  const symbolPose = crownSymbol && crownSymbol.sample(mode,time,idleTime,glow,impactSymbolStart);
  const woodHoldAge = playback.phase === "Hold" ? playback.age : playback.phase === "End" ? playback.holdAgeAtEnd : 0;
  const woodPulse = Math.round(woodShards.sampleHold(woodHoldAge)*10000)/10000;
  const key = mode + " " + featherFrames.join(",") + "/" + crownFrame + "/" + treantFrame + "/" +
    overlayFrames.join(",") + "/" + glow + "/" + leafCel + "/" + (rejuvenationPose?.key || "") +
    "/" + bannerImpactCel + "/" + treantImpactCel + "/" + woodPulse;
  return {clip,time,crownFrame,glow,isChannel,treantFrame,treantCel,overlays,overlayFrames,
          leafTrack,leafCel,leafMix,rejuvenationPose,bannerImpactCel,treantImpactCel,woodPulse,symbolPose,key};
}

function drawScene(target,pose,drawSymbol = true,treantCel = pose.treantCel) {
  const {clip:{clusters,columns},time,crownFrame,isChannel,treantFrame,overlays,overlayFrames,
         leafTrack,leafCel,leafMix,rejuvenationPose,bannerImpactCel,treantImpactCel} = pose;
  target.clearRect(-sideMargin,0,crest.width,crest.height);
  target.drawImage(animationImage(master),0,0);

  function blades(canvas,cluster) {
    const [x,y,w,h] = cluster.slot;
    for (const track of cluster.tracks) {
      const cel = celAt(track,time);
      canvas.drawImage(animationImage(track.art),cel%columns*w,Math.floor(cel/columns)*h,w,h,x,y,w,h);
    }
  }
  for (const cluster of clusters) {
    const [x,y,w,h] = cluster.slot;
    target.clearRect(x,y,w,h);
    blades(target,cluster);
    target.drawImage(animationImage(cluster.cover),x,y);
  }

  const drawFeathers = canvas=>clusters.forEach(cluster=>blades(canvas,cluster));
  crown.draw(target,crownFrame,drawFeathers);
  if (rightCrown) {
    const [x,y,w,h] = rightCrownIdle.slot;
    const cel = (crownFrame+6)%rightCrownIdle.frames;
    target.save();
    target.globalCompositeOperation = "destination-out";
    target.drawImage(animationImage(rightCrownCoverage),x,y);
    target.restore();
    target.drawImage(animationImage(rightCrown),cel%rightCrownIdle.columns*w,
      Math.floor(cel/rightCrownIdle.columns)*h,w,h,x,y,w,h);
  }
  innerFans.forEach(track=>drawOverlay(target,track,crownFrame));
  if (rejuvenationPose) rejuvenation.removeFixed(target);
  if (leafTrack && leafMix > 0) {
    drawOverlay(target,leafTrack,leafCel,drawFeathers,leafMix);
  }
  if (rejuvenationPose) rejuvenation.draw(target,rejuvenationPose);
  if (treantCel) {
    treantMotion.draw(target,treantCel);
  } else if (isChannel) {
    drawOverlay(target,channelTreant,treantFrame);
  } else {
    const [x,y,w,h] = treantTrack.slot;
    target.clearRect(x,y,w,h);
    target.drawImage(animationImage(treant),treantFrame%treantTrack.columns*w,Math.floor(treantFrame/treantTrack.columns)*h,
      w,h,x,y,w,h);
    if (treantImpactCel !== null && impactTreant.mix[treantImpactCel] > 0) {
      drawOverlay(target,impactTreant,treantImpactCel,undefined,impactTreant.mix[treantImpactCel]);
    }
  }
  overlays.forEach((track,index)=>{
    const behind = track.redrawFeathers ? canvas=>blades(canvas,clusters[index-1]) : undefined;
    if (index>0 && bannerImpactCel!==null) {
      if (bannerImpactCel===impactFabric[index-1].frames-1) {
        drawOverlay(target,track,fabricFlagImpact.idleReturn[index-1],behind);
      } else {
        drawOverlay(target,impactFabric[index-1],bannerImpactCel,behind);
      }
    } else drawOverlay(target,track,overlayFrames[index],behind);
  });
  woodShards.draw(target,pose,drawFeathers,treantCel);
  if (drawSymbol && pose.symbolPose) crownSymbol.draw(target,pose.symbolPose);
}

function blendScenes(idle,channelPose,amount,drawSymbol = true) {
  [idle,channelPose].forEach((pose,index)=>{
    const surface = transitionSurfaces[index];
    const buffer = surface.getContext("2d");
    buffer.setTransform(1,0,0,1,sideMargin,0);
    // Use one facial pose through the surrounding crest's Channel blend.
    drawScene(buffer,pose,false,channelPose.treantCel);
  });
  ctx.clearRect(-sideMargin,0,crest.width,crest.height);
  ctx.save();
  ctx.globalAlpha = 1-amount;
  ctx.drawImage(transitionSurfaces[0],-sideMargin,0);
  // Adding premultiplied canvases gives a linear alpha-preserving blend.
  ctx.globalCompositeOperation = "lighter";
  ctx.globalAlpha = amount;
  ctx.drawImage(transitionSurfaces[1],-sideMargin,0);
  ctx.restore();
  // Cast ramps interpolate the glyph's positions directly, so the separated
  // ball and crescent show one continuous movement through the transition.
  if (drawSymbol && channelPose.symbolPose) crownSymbol.draw(ctx,channelPose.symbolPose);
}

function paint() {
  if (modernMotion) {
    // Preview the existing six-second crest hover and the separate leaf phase.
    const bob = reference ? 0 : -1.2*(1-Math.cos(2*Math.PI*(idleTime%6000)/6000));
    crest.style.transform = `translateY(${bob.toFixed(3)}%)`;
  }
  const amount = Math.round(playback.amount*1000)/1000;
  const crownFrame = crown.frameAt(crownTime);
  const idle = framePose(state === "Impact" ? "Impact" : "Idle",state === "Impact" ? impactTime : idleTime,crownFrame,amount);
  const cast = amount>0 ? framePose("Channel",playback.time,crownFrame,amount) : null;
  const motionKey = amount === 1 ? cast.key : cast ? idle.key + "|" + cast.key : idle.key;
  const sceneKey = reference ? "reference" : playback.phase + "/" + motionKey;
  const symbolPose = !reference && (cast || idle).symbolPose;
  const key = sceneKey + "|" + (symbolPose?.key || "");
  if (key === lastPose) return;
  lastPose = key;
  crest.dataset.pose = reference ? sceneKey : (cast || idle).key;
  crest.dataset.channelPhase = playback.phase;
  crest.dataset.channelAmount = amount;
  crest.dataset.crownFrame = crownFrame;

  const reuseUnderlay = lastScene === sceneKey;
  if (!reuseUnderlay) {
    if (reference) {
      ctx.clearRect(-sideMargin,0,crest.width,crest.height);
      ctx.drawImage(master,0,0);
    } else if (!cast || amount === 1) {
      drawScene(ctx,cast || idle,false);
    } else {
      blendScenes(idle,cast,amount,false);
    }
  }
  if (symbolPose) crownSymbol.draw(ctx,symbolPose,reuseUnderlay);
  lastScene = sceneKey;

  zoom.clearRect(0,0,detail.width,detail.height);
  const focus = byId("focus").value;
  const bannerIndex = ["ambient-1","ambient-2"].indexOf(focus);
  const bannerTracks = state === "Channel" ? channelFabric : state === "Impact" ? impactFabric : null;
  const crop = bannerTracks && bannerIndex>=0 ? bannerTracks[bannerIndex].slot :
    detailViews[focus] || [master.width-295,408,426,417];
  if (detail.width !== crop[2] || detail.height !== crop[3]) {
    detail.width = crop[2];
    detail.height = crop[3];
  }
  zoom.drawImage(crest,sideMargin+crop[0],crop[1],crop[2],crop[3],0,0,detail.width,detail.height);
}

function advancePreview(delta) {
  if (!(delta>0)) return;
  idleTime += delta;
  ambientTime = (ambientTime+delta)%12000;
  if (!treantMotion || state==="Idle") {
    treantTime = (treantTime+delta)%(treantMotion?.idleMs || treantTrack.frames*treantTrack.frameMs);
  }
  const before = playback.phase, previousState = state;
  crownTime = (crownTime+playback.advance(delta))%crownIdle.period;
  if (state === "Channel" && playback.phase === "Idle") {
    state = "Idle";
  } else if (state === "Impact") {
    impactTime += delta;
  }
  if (state === "Impact" && impactTime >= states.Impact.tracks[0].period) {
    state = states.Impact.nextState || "Idle";
  }
  if (previousState!=="Idle" && state==="Idle") {
    if (treantMotion) treantTime = 0;
    leafIdleStart = idleTime;
    if (previousState==="Impact") bannerIdleStart = idleTime;
  }
  if (before !== playback.phase || previousState !== state) syncControls();
}

function tick(now) {
  if (lastTime !== undefined) advancePreview(now-lastTime);
  lastTime = now;
  paint();
  request = requestAnimationFrame(tick);
}

function syncControls() {
  const cast = state === "Channel";
  byId("toggle").disabled = reference;
  byId("toggle").textContent = playing ? "Pause" : "Play";
  byId("rest").setAttribute("aria-pressed",reference);
  byId("idle").setAttribute("aria-pressed",state === "Idle");
  byId("channel").setAttribute("aria-pressed",cast);
  byId("channel").disabled = !channelReady || playback.phase === "End";
  durationInput.disabled = cast;
  byId("channel").textContent = !channelReady ? "Preparing Channel…" :
    cast ? (playback.phase === "End" ? "Ending channel…" : "End channel") : "Channel";
  const stage = cast ? "Channel " + playback.phase.toLowerCase() : state;
  let status = reference ? "Static reference" : stage + (playing ? "" : " paused");
  if (!reference && cast) status += " · total " + (playback.durationMs/1000) + " s";
  if (!reference && !cast) {
    const clip = states[state];
    status += " · " + clip.fps + " fps · " + clip.tracks[0].period/1000 + " s";
  }
  if (byId("status").textContent !== status) byId("status").textContent = status;
  document.title = "Epicast · Restoration · " + stage;
}

function refresh() {
  cancelAnimationFrame(request);
  lastTime = undefined;
  lastPose = undefined;
  lastScene = undefined;
  paint();
  if (playing && !reference && !document.hidden) request = requestAnimationFrame(tick);
  syncControls();
}

function commitDuration() {
  const seconds = durationInput.valueAsNumber;
  if (!Number.isFinite(seconds) || seconds < .1 || !Number.isFinite(seconds*1000)) {
    durationInput.value = playback.durationMs/1000;
    return;
  }
  playback.durationMs = seconds*1000;
  syncControls();
}

function endChannel() {
  treantReleaseFrom = treantMotion?.sample("Channel",playback.time,treantTime,playback);
  playback.end();
  playing = true;
  reference = false;
  refresh();
}


const overlayImages = [channelTreant,impactTreant,...ambient,...channelFabric,...impactFabric,...innerFans,
  ...Object.values(leafTracks)].filter(Boolean).flatMap(track=>[track.image,track.mask]);
const images = Object.values(states).flatMap(s => [
  ...s.clusters.map(c=>c.cover), ...s.tracks.map(t=>t.art)
]);
const previewImages = [master,treant,rightCrown,rightCrownCoverage,...overlayImages,...images,
  ...crown.images,...woodShards.images,...(rejuvenation?.images || []),...(crownSymbol?.images || []),
  ...(treantMotion?.images || [])].filter(Boolean);

function preloadTurn() {
  return new Promise(resolve=>{
    if (window.requestIdleCallback) requestIdleCallback(resolve,{timeout:100});
    else window.setTimeout(resolve,0);
  });
}

async function preloadChannel() {
  // The Channel ramps blend with Idle, so the large atlases from both sides
  // of the transition need to stay decoded. Small masks and Impact can load normally.
  const channelImages = [master,treant,rightCrown,...crown.images,
    ...[states.Idle,states.Channel].flatMap(clip=>[
      ...clip.clusters.map(cluster=>cluster.cover),...clip.tracks.map(track=>track.art)
    ]),
    ...[channelTreant,...ambient,...channelFabric,...innerFans,leafTracks.Channel].filter(Boolean)
      .flatMap(track=>[track.image,track.mask]),
    ...woodShards.channelImages,...(rejuvenation?.channelImages || []),...(treantMotion?.channelImages || [])
  ].filter(image=>image && image.naturalWidth*image.naturalHeight>=512*512);
  const unique = new Map(channelImages.map(image=>[image.src,image]));
  // Retain the decoded Channel sources. A successful img.decode() alone
  // does not keep Chromium from decoding the same compressed atlas again.
  for (const image of unique.values()) {
    await preloadTurn();
    try {
      if (window.createImageBitmap) {
        channelAtlases.set(image.src,await createImageBitmap(image));
      } else {
        await image.decode?.();
      }
    } catch (error) {
      // These images already passed the load check. The warm draw can still
      // use the browser's ordinary on-demand decoder.
      console.debug("Channel atlas deferred to the canvas",image.src,error);
    }
  }
}

function waitForImage(image) {
  return new Promise((resolve,reject)=>{
    const failed = () => reject(new Error("Could not load " + image.src));
    if (image.complete) {
      if (image.naturalWidth) resolve();
      else failed();
    } else {
      image.addEventListener("load",resolve,{once:true});
      image.addEventListener("error",failed,{once:true});
    }
  });
}
Promise.all(previewImages.map(waitForImage)).then(()=>{
  crest.width = master.naturalWidth + 2*sideMargin;
  crest.height = master.naturalHeight;
  crest.style.setProperty("--ui-width", (162*crest.width/master.naturalWidth)+"px");
  ctx.translate(sideMargin,0);
  ctx.globalCompositeOperation = "source-over";
  ctx.drawImage(master,0,0);
  byId("rest").disabled = false;
  for (const surface of transitionSurfaces) {
    surface.width = crest.width;
    surface.height = crest.height;
  }
  byId("idle").disabled = false;
  byId("impact").disabled = false;
  durationInput.disabled = false;
  durationInput.onchange = commitDuration;
  byId("channel").onclick = () => {
    if (state === "Channel") {
      endChannel();
      return;
    }
    commitDuration();
    treantReleaseFrom = undefined;
    playback.start();
    state = "Channel";
    playing = true;
    reference = false;
    refresh();
  };
  byId("idle").onclick = () => {
    if (state === "Channel") {
      endChannel();
      return;
    }
    if (state!=="Idle") {
      if (treantMotion) treantTime = 0;
      leafIdleStart = idleTime;
      if (state==="Impact") bannerIdleStart = idleTime;
    }
    state = "Idle";
    reference = false;
    refresh();
  };
  byId("impact").onclick = () => {
    if (crownSymbol) {
      const time = state === "Channel" ? playback.time : state === "Impact" ? impactTime : idleTime;
      impactSymbolStart = crownSymbol.sample(state,time,idleTime,playback.amount,impactSymbolStart);
    }
    playback.reset();
    state = "Impact";
    impactTime = 0;
    playing = true;
    reference = false;
    refresh();
  };
  byId("toggle").onclick = () => { playing = !playing; refresh(); };
  byId("rest").onclick = () => { reference = !reference; refresh(); };
  byId("focus").onchange = () => { lastPose = undefined; paint(); };
  byId("scale").onclick = () => byId("scale").setAttribute("aria-pressed",crest.classList.toggle("actual"));
  document.addEventListener("visibilitychange",refresh);
  refresh();
  preloadChannel().catch(error=>console.debug("Channel preload fell back to on-demand rendering",error)).finally(()=>{
    channelReady = true;
    syncControls();
  });
}).catch(error=>{
  console.error(error);
  byId("status").textContent="The crest or its painted cels could not be loaded.";
});

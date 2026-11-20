function loadRejuvenationMotion(spec) {
  const background = loadImage(spec.receiver);
  const coverage = loadImage(spec.coverage);
  const occlusion = loadImage(spec.occlusion);
  const incoming = loadImage(spec.incoming);
  const clips = Object.fromEntries(Object.entries(spec.clips).map(([name, data]) => [
    name, {...data, art: loadImage(data.paint), cast: loadImage(data.shadow)}
  ]));
  const [x,y,w,h] = spec.slot;
  const patch = document.createElement("canvas");
  [patch.width,patch.height] = [w,h];
  const ctx = patch.getContext("2d");

  function channelFrame(playback) {
    const {holdFrames,restRamp,startFrames,period} = clips.channel;
    const end = playback.phase === "End";
    const phase = end ? playback.endFromPhase : playback.phase;
    const age = end ? playback.endFromAge : playback.age;
    const ramp = playback.rampMs;
    const strip = (side,t) => holdFrames+side*restRamp+Math.round(t*(restRamp-1));
    if (phase === "Start") {
      let step = Math.min(startFrames-1,Math.floor(age/ramp*startFrames));
      if (end) step = Math.round(step*(1-Math.min(1,playback.age/ramp)));
      return holdFrames+2*restRamp+step;
    }
    const cel = (startFrames+Math.floor((age%period)/period*holdFrames))%holdFrames;
    if (!end) return cel;
    const half = holdFrames/2, crossing = Math.round(cel/half)*half;
    const travel = Math.min(ramp*.52,Math.abs(crossing-cel)*period/holdFrames);
    if (playback.age<travel) return Math.round(cel+(crossing-cel)*playback.age/travel)%holdFrames;
    return strip(crossing%holdFrames===0 ? 0 : 1, Math.min(1,(playback.age-travel)/(ramp-travel)));
  }

  function sample(mode, time, idleTime, hoverTime=idleTime, playback) {
    const state = mode.toLowerCase();
    const clip = clips[state];
    const elapsed = state === "idle" ? idleTime : time;
    const t = state === "impact" ? Math.min(elapsed,clip.period-0.001) : elapsed%clip.period;
    const frame = state==="channel" && playback && playback.phase!=="Idle"
      ? channelFrame(playback) : Math.min(clip.frames-1, Math.floor(t/clip.frameMs));
    const {amplitude,period,offset} = spec.float;
    // The independent local offset is layered over the crest's native hover.
    const float = Math.round(4 * amplitude * Math.sin(2*Math.PI*((hoverTime+offset)%period)/period))/4;
    return {clip,frame,float,key:state+"/"+frame+"/"+float};
  }

  function drawCel(image, pose) {
    const {frame,clip,float} = pose;
    const sx = (frame%clip.columns)*w, sy = Math.floor(frame/clip.columns)*h;
    ctx.drawImage(animationImage(image),sx,sy,w,h,0,float,w,h);
  }

  function removeFixed(target) {
    target.save();
    target.globalCompositeOperation = "destination-out";
    target.drawImage(coverage,x,y);
    target.globalCompositeOperation = "source-over";
    target.drawImage(background,x,y);
    target.restore();
  }

  function draw(target, pose) {
    target.save();
    // Replace the former fixed shadow and keep the new cast on existing receivers.
    ctx.clearRect(0,0,w,h);
    ctx.globalCompositeOperation = "source-over";
    drawCel(pose.clip.cast,pose);
    ctx.globalCompositeOperation = "destination-out";
    ctx.drawImage(occlusion,0,0);
    target.globalCompositeOperation = "source-atop";
    target.drawImage(patch,x,y);

    ctx.clearRect(0,0,w,h);
    ctx.globalCompositeOperation = "source-over";
    drawCel(pose.clip.art,pose);
    ctx.globalCompositeOperation = "source-atop";
    ctx.drawImage(incoming,0,0);
    ctx.globalCompositeOperation = "destination-out";
    ctx.drawImage(occlusion,0,0);
    target.globalCompositeOperation = "source-over";
    target.drawImage(patch,x,y);
    target.restore();
  }
  return {sample,draw,removeFixed,slot:spec.slot,images:[background,coverage,occlusion,incoming,
    ...Object.values(clips).flatMap(clip=>[clip.art,clip.cast])],
    channelImages:[clips.idle.art,clips.idle.cast,clips.channel.art,clips.channel.cast]};
}

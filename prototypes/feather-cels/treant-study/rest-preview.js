function loadTreantRest(spec, cheeksVisible) {
  const loadBank = files => Object.fromEntries(Object.entries(files).map(([name,url])=>[name,loadImage(url)]));
  const atlases = loadBank(spec.files[cheeksVisible ? "shown" : "hidden"]);
  const overlaps = spec.wood.map(tile=>tile && {...tile,atlases:loadBank(tile.files)});
  const clamp = t => Math.min(1,Math.max(0,t));
  const smooth = t => { const u = clamp(t); return u*u*(3-2*u); };
  const cel = (clip,index) => ({clip,index,key:clip+"/"+index});
  const rest = cel("idle",0);
  const channel = index => cel("channel",index);
  const hold = time => channel(8+Math.floor((time%spec.channelHoldMs)/spec.channelHoldMs*16));

  function sample(mode, time, idleTime, playback, releaseFrom) {
    if (mode==="Impact") {
      const index = Math.floor(time/spec.impactMs*spec.impactFrames);
      return index>=spec.impactFrames-1 ? rest : cel("impact",index);
    }
    if (mode!=="Channel") {
      const index = Math.floor((idleTime%spec.idleMs)/spec.idleMs*spec.idleFrames);
      return cel("idle",index);
    }
    if (playback.phase==="Start") {
      return channel(Math.floor(8*clamp(playback.age/playback.rampMs)));
    }
    if (playback.phase!=="End") return hold(playback.phase==="Hold" ? playback.age : time);

    const progress = clamp(playback.age/playback.rampMs);
    const traveled = 1-(1-progress)*playback.entry;
    const index = 24+Math.round(8*traveled);
    const end = index===32 ? rest : channel(index);
    // At manual stop the pose may be partway through Start or a Hold breath.
    // Carry that exact cel into End, then ease into the authored release.
    const from = releaseFrom || hold(playback.holdAgeAtEnd);
    const weight = Math.round(smooth(progress/.28)*64)/64;
    if (weight===0) return from;
    if (weight===1 || from.key===end.key) return end;
    return {...end,from,weight,key:from.key+">"+end.key+"/"+weight};
  }

  function drawPatch(target,pose,bank,[x,y,w,h],planes,plane) {
    const drawCel = cel => target.drawImage(animationImage(bank[cel.clip]),cel.index%spec.columns*w,
      (Math.floor(cel.index/spec.columns)*planes+plane)*h,w,h,x,y,w,h);
    target.clearRect(x,y,w,h);
    if (!pose.from) {
      drawCel(pose);
      return;
    }
    target.save();
    target.globalAlpha = 1-pose.weight;
    drawCel(pose.from);
    target.globalCompositeOperation = "lighter";
    target.globalAlpha = pose.weight;
    drawCel(pose);
    target.restore();
  }

  function draw(target,pose) {
    drawPatch(target,pose,atlases,spec.slot,1,0);
  }

  function drawOverlap(target,pose,side,shadow) {
    const tile = overlaps[side];
    if (tile) drawPatch(target,pose,tile.atlases,tile.rect,2,shadow ? 1 : 0);
  }

  const banks = [atlases,...overlaps.filter(Boolean).map(tile=>tile.atlases)];
  return {draw,drawOverlap,sample,slot:spec.slot,idleMs:spec.idleMs,
    images:banks.flatMap(bank=>Object.values(bank)),
    channelImages:banks.flatMap(bank=>[bank.idle,bank.channel])};
}

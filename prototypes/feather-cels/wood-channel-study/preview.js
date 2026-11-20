function loadWoodChannel(cheeksVisible, treantMotion) {
  const paths = ["mask","lower","paint","front","shadow","frontCast"];
  const sides = woodChannel.tiles.map(tile => {
    const [, , w, h] = tile.slot;
    const image = Object.fromEntries(paths.map(name => [name,loadImage(tile[name])]));
    image.light = loadImage(tile.paintedGlow);
    image.upper = loadImage(cheeksVisible ? tile.upper : tile.hiddenUpper);
    image.shade = loadImage(cheeksVisible ? tile.shade : tile.hiddenShade);
    const clips = Object.fromEntries(["idle","channel"].map(state => [
      state,tile[state].map((clip,index) => clip && !(treantMotion && index===0) && {
        ...clip,image:loadImage(clip.sheet),cast:clip.cast ? loadImage(clip.cast) : null
      })
    ]));
    const layers = Array.from({length:4},() => {
      const canvas = document.createElement("canvas");
      [canvas.width,canvas.height] = [w,h];
      return canvas.getContext("2d");
    });
    return {tile,image,clips,layers};
  });

  function draw(target, pose, drawFeathers, treantCel) {
    if (pose.glow <= 0) return;
    const extent = pose.glow;
    const blend = Math.min(1,extent*9);
    for (const [side,{tile,image,clips,layers}] of sides.entries()) {
      const [x,y,w,h] = tile.slot;
      const [ox,oy] = tile.paintBox;
      const slide = tile.travel*extent;
      const [scene,wood,front,frontCast] = layers;
      const [face,banner] = clips[pose.isChannel ? "channel" : "idle"];
      const flagCel = pose.overlayFrames[side+1];
      for (const layer of layers) layer.clearRect(0,0,w,h);

      // Keep the moving slats between their lower receivers and the animated foreground.
      scene.save();
      scene.translate(-x,-y);
      drawFeathers(scene);
      scene.restore();
      scene.drawImage(image.lower,0,0);
      scene.globalCompositeOperation = "source-atop";
      scene.drawImage(image.shadow,slide,0);
      scene.globalCompositeOperation = "source-over";

      // Keep the fabric's shadow in crest coordinates so it moves with the fabric
      // while the wooden receiver slides independently beneath it.
      frontCast.drawImage(image.frontCast,0,0);
      if (treantCel) treantMotion.drawOverlap(frontCast,treantCel,side,true);
      if (banner?.cast) {
        frontCast.clearRect(...banner.rect);
        drawCel(frontCast,banner.cast,flagCel,banner.rect);
      }
      wood.drawImage(image.paint,ox+slide,oy);
      wood.save();
      wood.globalCompositeOperation = "source-atop";
      wood.globalAlpha = extent*pose.woodPulse;
      wood.drawImage(image.light,ox+slide,oy);
      wood.globalAlpha = 1;
      wood.drawImage(image.shade,0,0);
      wood.drawImage(frontCast.canvas,0,0);
      wood.restore();
      scene.drawImage(wood.canvas,0,0);
      scene.drawImage(image.upper,0,0);

      front.drawImage(image.front,0,0);
      if (treantCel) {
        treantMotion.drawOverlap(front,treantCel,side,false);
      } else if (face) {
        front.clearRect(...face.rect);
        drawCel(front,face.image,pose.treantFrame,face.rect);
      }
      if (banner) {
        front.clearRect(...banner.rect);
        drawCel(front,banner.image,flagCel,banner.rect);
      }
      scene.drawImage(front.canvas,0,0);
      scene.globalCompositeOperation = "destination-in";
      scene.drawImage(image.mask,0,0);
      scene.globalCompositeOperation = "source-over";

      // Replace in premultiplied space, including silhouette and contact shadow.
      target.save();
      target.globalCompositeOperation = "destination-out";
      target.globalAlpha = blend;
      target.drawImage(image.mask,x,y);
      target.globalCompositeOperation = "lighter";
      target.drawImage(scene.canvas,x,y);
      target.restore();
    }
  }

  function drawCel(target,image,frame,[x,y,w,h]) {
    const sx = frame%woodChannel.columns*w;
    const sy = Math.floor(frame/woodChannel.columns)*h;
    target.drawImage(animationImage(image),sx,sy,w,h,x,y,w,h);
  }

  function sampleHold(ms) {
    const {levels,period} = woodChannel.paintedHold;
    const cursor = (ms%period)/period*(levels.length-1);
    const index = Math.floor(cursor);
    const fraction = cursor-index;
    return levels[index]*(1-fraction) + levels[index+1]*fraction;
  }

  const images = sides.flatMap(({image,clips})=>[
    ...Object.values(image),...Object.values(clips).flat().filter(Boolean).flatMap(track=>[track.image,track.cast].filter(Boolean))
  ]);
  const channelImages = sides.flatMap(({clips})=>Object.values(clips).flat().filter(Boolean)
    .flatMap(track=>[track.image,track.cast].filter(Boolean)));
  return {draw,images,channelImages,sampleHold};
}

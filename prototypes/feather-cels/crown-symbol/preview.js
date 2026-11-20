function loadCrownSymbol(spec) {
  const atlas = loadImage(spec.atlas), receiver = loadImage(spec.receiver);
  const coverage = loadImage(spec.coverage), front = loadImage(spec.front);
  const [x,y,w,h] = spec.slot;
  const [px,py] = spec.pivot;
  const [sx,sy,sw,sh] = spec.sprite;
  const patch = document.createElement("canvas");
  [patch.width,patch.height] = [w,h];
  const buffer = patch.getContext("2d");
  const underlay = document.createElement("canvas");
  const composed = document.createElement("canvas");
  for (const canvas of [underlay,composed]) [canvas.width,canvas.height] = [w,h];
  const saved = underlay.getContext("2d");
  const result = composed.getContext("2d");
  const turn = 2*Math.PI;
  const mix = (a,b,t) => a+(b-a)*t;
  const clamp = t => Math.min(1,Math.max(0,t));
  const ease = t => { const q = clamp(t); return q*q*(3-2*q); };
  const celTime = ms => Math.floor(ms/25)*25;

  function sample(state,time,idleTime,channelAmount,impactStart) {
    const clock = celTime(idleTime);
    const cycle = turn*(clock%3000)/3000;
    const spread = 10.5*Math.sin(cycle);
    const neutral = {ballX:0,ballY:-.68*spread,moonY:.32*spread,scale:1,
      rock:2.8*Math.PI/180*Math.sin(cycle+.55),glow:0,
      hover:3.4*Math.sin(turn*((clock+710)%6920)/6920)};
    const t = celTime(time);
    const key = [state,clock,t,channelAmount].join("/");
    if (state === "Channel") {
      const shake = turn*t/115;
      return {...neutral,key,
        ballX:2.5*channelAmount*Math.sin(shake),
        ballY:mix(neutral.ballY,-20+1.35*Math.sin(1.37*shake),channelAmount),
        moonY:mix(neutral.moonY,9,channelAmount),
        rock:neutral.rock*(1-.6*channelAmount),glow:.76*channelAmount};
    }
    if (state === "Impact" && t<1000) {
      const from = impactStart || neutral;
      const contact = 150;
      const after = Math.max(0,t-contact);
      const travel = clamp(t/contact)**2;
      const settle = ease((after-65)/720);
      const moonY = mix(from.moonY,neutral.moonY,settle)+
        5.5*Math.sin(Math.PI*clamp(after/260));
      const rebound = 7*Math.sin(Math.PI*clamp((after-35)/305));
      return {...neutral,key,moonY,
        ballX:mix(from.ballX,0,travel),
        // At contact both pieces share the same local surface point. The
        // ball then rebounds away from the displaced crescent.
        ballY:t<contact ? mix(from.ballY,moonY+spec.gap,travel) :
          mix(moonY+spec.gap,neutral.ballY,settle)-rebound,
        rock:mix(from.rock,neutral.rock,settle),
        scale:1+.2*(1-ease((t-185)/665)),
        glow:mix(.92,1.34,travel)*(1-ease((t-185)/630))};
    }
    return {...neutral,key};
  }

  function remember(target) {
    const {e,f} = target.getTransform();
    saved.clearRect(0,0,w,h);
    saved.drawImage(target.canvas,x+e,y+f,w,h,0,0,w,h);
    saved.globalCompositeOperation = "destination-out";
    saved.drawImage(animationImage(coverage),0,0);
    saved.globalCompositeOperation = "source-over";
    saved.drawImage(animationImage(receiver),0,0);
  }

  function layer(pose,column,opacity,composite = "source-over") {
    if (opacity<=0) return;
    buffer.save();
    buffer.globalCompositeOperation = composite;
    buffer.globalAlpha = Math.min(1,opacity);
    buffer.translate(px-x,py-y+pose.hover);
    buffer.rotate(pose.rock);
    buffer.scale(pose.scale,pose.scale);
    const pieces = animationImage(atlas);
    buffer.drawImage(pieces,column*sw,sh,sw,sh,sx-px,sy-py+pose.moonY,sw,sh);
    buffer.drawImage(pieces,column*sw,0,sw,sh,sx-px+pose.ballX,sy-py+pose.ballY,sw,sh);
    buffer.restore();
  }

  function clipFront() {
    buffer.save();
    buffer.globalCompositeOperation = "destination-out";
    buffer.drawImage(animationImage(front),0,0);
    buffer.restore();
  }

  function draw(target,pose,reuseUnderlay = false) {
    if (!reuseUnderlay) remember(target);
    result.clearRect(0,0,w,h);
    result.drawImage(underlay,0,0);
    if (pose) {
      buffer.clearRect(0,0,w,h);
      layer(pose,3,.90);
      clipFront();
      layer(pose,2,.74*pose.glow);
      result.globalCompositeOperation = "source-atop";
      result.drawImage(patch,0,0);

      buffer.clearRect(0,0,w,h);
      const lit = Math.min(1,pose.glow);
      layer(pose,0,1-lit);
      layer(pose,1,lit,"lighter");
      clipFront();
      result.globalCompositeOperation = "source-over";
      result.drawImage(patch,0,0);
    }
    target.clearRect(x,y,w,h);
    target.drawImage(composed,x,y);
  }

  return {sample,draw,slot:spec.slot,images:[atlas,receiver,coverage,front]};
}

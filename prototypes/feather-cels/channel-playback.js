// The cast timer governs phase boundaries; channel cels keep their authored cadence.
class ChannelPlayback {
  static transitionMs = 500;

  constructor(leafSpeed) {
    this.leafSpeed = leafSpeed;
    this.durationMs = 3000;
    this.rampMs = ChannelPlayback.transitionMs;
    this.holdMs = 0;
    this.reset();
  }

  reset() {
    this.phase = "Idle";
    this.time = 0;
    this.age = 0;
    this.entry = 0;
  }

  get amount() {
    if (this.phase === "Idle") return 0;
    if (this.phase === "Hold") return 1;
    const t = this.age / this.rampMs;
    const eased = t*t*(3-2*t);
    return this.phase === "Start" ? eased : this.entry*(1-eased);
  }

  start() {
    if (this.phase !== "Idle") return;
    this.rampMs = Math.min(ChannelPlayback.transitionMs,this.durationMs/2);
    this.holdMs = this.durationMs - 2*this.rampMs;
    this.phase = "Start";
    this.age = 0;
    this.time = 0;
  }

  end() {
    if (this.phase !== "Start" && this.phase !== "Hold") return;
    this.endFromPhase = this.phase;
    this.endFromAge = this.age;
    this.holdAgeAtEnd = this.phase === "Hold" ? this.age : 0;
    this.entry = this.amount;
    this.age = 0;
    this.phase = "End";
  }

  advance(delta) {
    let remaining = delta, leafAdvance = delta;
    // Integrate smoothstep over each transition interval so timing is
    // independent of display FPS, even when a frame crosses a phase boundary.
    const integral = t => t*t*t*(1-.5*t);
    while (remaining > 0 && this.phase !== "Idle") {
      if (this.phase === "Hold") {
        const step = Math.min(remaining,this.holdMs-this.age);
        this.age += step;
        remaining -= step;
        this.time += step;
        leafAdvance += step*(this.leafSpeed-1);
        if (this.age >= this.holdMs) this.end();
        continue;
      }
      const start = this.phase === "Start";
      const step = Math.min(remaining,this.rampMs-this.age);
      const area = this.rampMs*(integral((this.age+step)/this.rampMs)-integral(this.age/this.rampMs));
      const moving = start ? area : this.entry*(step-area);
      leafAdvance += moving*(this.leafSpeed-1);
      this.time += .45*step+.55*moving;
      this.age += step;
      remaining -= step;
      if (this.age >= this.rampMs) {
        this.phase = start ? "Hold" : "Idle";
        this.age = 0;
        if (start && this.holdMs === 0) this.end();
      }
    }
    return leafAdvance;
  }
}


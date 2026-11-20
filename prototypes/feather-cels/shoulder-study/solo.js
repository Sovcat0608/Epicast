function loadShoulderStudy() {
  const mode = new URLSearchParams(location.search).get("solo");
  const shoulder = mode !== "autumn";
  const ignis = mode === "ignis" || mode === "ignis-full";
  const trials = {
    autumn: autumnStudy, tango: shoulderStudy, ignis: ignisShoulderStudy, "ignis-full": ignisShoulderStudy,
    "griffin-first": griffinShoulderStudy, "griffin-benchmark": griffinBenchmarkStudy,
    "griffin-broad": griffinBroadStudy, "griffin-delay": griffinDelayStudy, shoulder: griffinQuietStudy
  };
  const track = trials[mode] || griffinQuietStudy;
  const model = ignis ? "Ignis" : shoulder && mode !== "tango" ? "Griffin HD" : "Tango";
  const name = shoulder ? "Left green shoulder" : "Upper-left autumn crown";
  const sheet = loadImage(shoulder ? (mode === "ignis-full" ? track.fullPairedSheet : track.pairedSheet) : track.sheet);
  const autumn = shoulder ? loadImage(autumnStudy.sheet) : sheet;
  const right = shoulder ? loadImage(rightShoulderStudy.pairedSheet) : null;
  document.title = "Epicast · " + name;
  document.querySelector("h1").textContent = "Restoration · " + name;
  const link = document.querySelector("figcaption a");
  link.href = shoulder ? "?solo=autumn" : "?solo=shoulder";
  link.textContent = shoulder ? "Autumn loop" : "Shoulder trial";
  if (shoulder) {
    const variant = document.createElement("select");
    variant.setAttribute("aria-label", "Left shoulder animation");
    variant.add(new Option("Griffin HD · subtle idle", "shoulder"));
    variant.add(new Option("Griffin HD · staggered blades", "griffin-delay"));
    variant.add(new Option("Griffin HD · whole-leaf bend", "griffin-broad"));
    variant.add(new Option("Griffin HD · benchmark retry", "griffin-benchmark"));
    variant.add(new Option("Griffin HD · first trial", "griffin-first"));
    variant.add(new Option("Ignis · gentle idle", "ignis"));
    variant.add(new Option("Ignis · full render", "ignis-full"));
    variant.add(new Option("Tango · previous idle", "tango"));
    variant.value = trials[mode] ? mode : "shoulder";
    variant.onchange = () => { location.search = "?solo=" + variant.value; };
    link.before(variant);
  }
  byId("focus").prepend(new Option(name, "segment"));
  if (right) byId("focus").prepend(new Option("Right autumn shoulder", "right-shoulder"));
  byId("focus").value = right ? "right-shoulder" : "segment";

  function tile(target, image, slot, cel, drawFeathers) {
    const [x,y,w,h] = slot;
    target.save();
    target.beginPath();
    target.rect(x,y,w,h);
    target.clip();
    target.clearRect(x,y,w,h);
    drawFeathers(target);
    target.drawImage(animationImage(image), cel%4*w, Math.floor(cel/4)*h, w,h, x,y,w,h);
    target.restore();
  }

  return {
    images: shoulder ? [sheet, autumn, right] : [sheet],
    segment: track.slot,
    rightSegment: right && rightShoulderStudy.slot,
    label: shoulder ? "Crown and shoulders" : model + " autumn",
    frameAt: ms => Math.floor(ms / track.frameMs) % 16,
    draw(target, beat, drawFeathers) {
      if (shoulder) tile(target, autumn, autumnStudy.slot, (beat+2)%16, drawFeathers);
      tile(target, sheet, track.slot, beat, drawFeathers);
      if (right) tile(target, right, rightShoulderStudy.slot, beat, drawFeathers);
    }
  };
}

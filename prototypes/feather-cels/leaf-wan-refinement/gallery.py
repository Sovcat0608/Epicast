"""Build a portable review page for the Restoration Wan trials."""
import html
import json

from PIL import Image
import numpy as np

from guides import LAYERS, OUTPUT, SIZE, review_source


def write_sheet(path, frames):
    # The gallery deliberately samples the same cels and timing as the game target.
    sheet = Image.new("RGB", (4 * SIZE[0], ((len(frames) + 3) // 4) * SIZE[1]))
    for index, frame in enumerate(frames):
        sheet.paste(Image.fromarray(frame), ((index % 4) * SIZE[0], (index // 4) * SIZE[1]))
    sheet.save(path, lossless=True)


def assemble():
    jobs = json.loads((OUTPUT / "manifest.json").read_text(encoding="utf-8"))
    selection_path = OUTPUT / "review-selection.json"
    selection = json.loads(selection_path.read_text(encoding="utf-8")) if selection_path.exists() else {}
    sections = []
    for job in jobs:
        state = job["state"]
        name = job["name"]
        key = f"{name}/{state}"
        review = selection.get(key, {})
        job,folder = review_source(job,review)
        root = folder.relative_to(OUTPUT).as_posix()
        trial = review.get("trial", 1)
        stem = f"trial-{trial:02}"
        if not (folder / f"{stem}.json").exists():
            continue
        if state == "channel":
            indices = list(range(0, 32, 2))
        else:
            # Contact immediately, peak near the second cel, settle back over 1 s.
            indices = [3, 4, 7, 10, 13, 16, 19, 22, 25, 28, 30, 32]
        with np.load(folder / "guide.npz") as data:
            guide = data["rgb"][indices]
        with np.load(folder / f"{stem}.npz") as data:
            actual = data["rgb"][indices]
        if not (folder / "guide-play.webp").exists():
            write_sheet(folder / "guide-play.webp", guide)
        if not (folder / f"{stem}-play.webp").exists():
            write_sheet(folder / f"{stem}-play.webp", actual)
        supplied = "registered-cels.webp" if (folder / "registered-cels.webp").exists() else f"{stem}-play.webp"
        pixels = job["registered"][2:] if supplied == "registered-cels.webp" else SIZE
        label = "Registered Wan cels" if supplied == "registered-cels.webp" else "Wan render"
        timing = "16 cels · 0.333 s loop" if state == "channel" else "12 cels · 1 s"
        verdict = html.escape(review.get("note", "Wan trial for review"))
        metrics = folder / f"{stem}-metrics.json"
        compare = f'<a href="{root}/{stem}-review.jpg">Frame comparison</a>' if metrics.exists() else ""
        sections.append(f"""
          <article data-state="{state}">
            <h2>{html.escape(LAYERS[job['index']]['name'])} · {state.title()}</h2>
            <p>{timing} · Pass {trial} · {verdict}</p>
            <div class="frames">
              <figure><canvas width="384" height="384" data-source="{root}/guide-play.webp"
                    data-count="{len(indices)}" data-duration="{job['cycle']}"></canvas><figcaption>Fresh reference</figcaption></figure>
              <figure><canvas width="384" height="384" data-source="{root}/{supplied}"
                    data-width="{pixels[0]}" data-height="{pixels[1]}" data-registered="{supplied == 'registered-cels.webp'}"
                    data-count="{len(indices)}" data-duration="{job['cycle']}"></canvas><figcaption>{label}</figcaption></figure>
            </div>
            <footer>{compare}<a href="{root}/{stem}.mp4">Raw Wan render</a></footer>
          </article>""")
    composite = """
      <article class="crest" data-state="both">
        <h2>Original crown motion comparison</h2>
        <p>Each clip compares the original Wan pass at 256 px, with an enlarged view of that result.</p>
        <div class="frames">
          <figure><video controls loop muted playsinline src="crest-channel.mp4"></video><figcaption>Channel</figcaption></figure>
          <figure><video controls loop muted playsinline src="crest-impact.mp4"></video><figcaption>Impact</figcaption></figure>
        </div>
      </article>""" if all((OUTPUT / f"crest-{state}.mp4").exists() for state in ("channel", "impact")) else ""
    page = """<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Restoration leaf animation review</title>
<style>
  :root{color-scheme:dark;--paper:#171a1a;--panel:#242828;--accent:#c6e17d}
  *{box-sizing:border-box}body{margin:0;background:var(--paper);color:#eeefeb;font:15px system-ui,sans-serif}
  main{max-width:1350px;margin:auto;padding:38px clamp(16px,4vw,52px)}
  h1{font-family:Georgia,serif;font-size:clamp(27px,4.5vw,50px);font-weight:500;margin:0 0 12px}
  h2{font-size:17px;margin:0 0 5px;font-weight:600}p,figcaption{color:#c2c9c5;margin:0 0 10px}
  nav{display:flex;flex-wrap:wrap;gap:8px;margin:22px 0}
  button,select{font:inherit;background:#292f2b;color:#f2f4ec;border:1px solid #62725b;border-radius:6px;padding:8px 14px}
  button[aria-pressed=true]{color:#142014;background:var(--accent);border-color:var(--accent)}
  .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,360px),1fr));gap:16px}
  article{background:var(--panel);border:1px solid #39423e;border-radius:10px;padding:15px;min-width:0}
  .frames{display:grid;grid-template-columns:1fr 1fr;gap:8px}
  figure{margin:0;min-width:0}figcaption{padding-top:5px;font-size:13px}
  canvas,video{background:#2e425b;width:100%;height:auto;display:block;border-radius:4px}
  footer{display:flex;flex-wrap:wrap;gap:14px}a{color:var(--accent);text-underline-offset:3px}
  .crest{grid-column:1/-1}.crest video{background:#202523}
</style></head>
<body><main>
<h1>Restoration leaf animation review</h1>
<p>Fresh reference poses and local Wan renders, side by side. Playback defaults to the intended game timing.</p>
<nav aria-label="Review controls">
  <button type="button" data-filter="both" aria-pressed="true">Both states</button>
  <button type="button" data-filter="channel" aria-pressed="false">Channel</button>
  <button type="button" data-filter="impact" aria-pressed="false">Impact</button>
  <button type="button" id="play" aria-pressed="true">Pause</button>
  <button type="button" id="restart">Replay</button>
  <select id="speed" aria-label="Playback speed">
    <option value="1">Game timing</option><option value=".5">Half speed</option><option value=".25">Quarter speed</option>
  </select>
</nav>
<div class="grid">""" + composite + "".join(sections) + """</div></main>
<script>
  const play = document.getElementById("play");
  const speed = document.getElementById("speed");
  const clips = [...document.querySelectorAll("canvas")].map(canvas => {
    const image = new Image();
    image.src = canvas.dataset.source;
    return {canvas, image, context: canvas.getContext("2d"), frame: -1,
            width: Number(canvas.dataset.width ?? 384), height: Number(canvas.dataset.height ?? 384),
            inset: canvas.dataset.registered === "True" ? 16 : 0,
            count: Number(canvas.dataset.count), duration: Number(canvas.dataset.duration)};
  });
  let running = true;
  let elapsed = 0;
  let previous;
  play.onclick = () => {
    running = !running;
    play.textContent = running ? "Pause" : "Play";
    play.setAttribute("aria-pressed", running);
  };
  document.getElementById("restart").onclick = () => {elapsed = 0;};
  const filters = [...document.querySelectorAll("[data-filter]")];
  for (const button of filters) {
    button.onclick = () => {
      const filter = button.dataset.filter;
      for (const item of filters) item.setAttribute("aria-pressed", item === button);
      for (const card of document.querySelectorAll("article")) {
        card.hidden = !["both", filter].includes(card.dataset.state) && filter !== "both";
      }
    };
  }
  function draw(now) {
    if (running && previous !== undefined) elapsed += Math.min(50, now - previous) * Number(speed.value) / 1000;
    previous = now;
    for (const clip of clips) {
      const interval = clip.duration + (clip.duration === 1 ? .55 : 0);
      const cue = elapsed % interval;
      const frame = Math.min(clip.count - 1, Math.floor(cue / clip.duration * clip.count));
      if (clip.frame === frame || !clip.image.complete || !clip.image.naturalWidth) continue;
      clip.frame = frame;
      const size = clip.canvas.width;
      const scale = (size - clip.inset) / Math.max(clip.width, clip.height);
      const drawWidth = clip.width * scale;
      const drawHeight = clip.height * scale;
      clip.context.clearRect(0, 0, size, size);
      clip.context.drawImage(clip.image, (frame % 4) * clip.width, Math.floor(frame / 4) * clip.height,
                             clip.width, clip.height, (size-drawWidth)/2, (size-drawHeight)/2, drawWidth, drawHeight);
    }
    requestAnimationFrame(draw);
  }
  requestAnimationFrame(draw);
</script></body></html>"""
    (OUTPUT / "index.html").write_text(page, encoding="utf-8")


if __name__ == "__main__":
    assemble()

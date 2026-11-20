function buildReview(assets) {
  const width = 660, height = 880;
  function box(parent, name, w, h, x, y) {
    const frame = figma.createFrame();
    parent.appendChild(frame);
    frame.name = name;
    frame.resize(w, h);
    frame.x = x; frame.y = y;
    frame.fills = []; frame.strokes = []; frame.clipsContent = false;
    return frame;
  }
  function picture(parent, name, asset, offsetX, offsetY) {
    const rect = figma.createRectangle();
    parent.appendChild(rect);
    rect.name = name;
    rect.resize(asset.w, asset.h);
    rect.x = asset.x - offsetX; rect.y = asset.y - offsetY;
    rect.fills = [{type: 'IMAGE', scaleMode: 'FILL', imageHash: figma.createImage(figma.base64Decode(asset.png)).hash}];
    return rect;
  }
  function instance(parent, master) {
    const node = master.createInstance();
    parent.appendChild(node);
    node.x = 0; node.y = 0;
    return node;
  }
  function intersects(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
  }

  const root = box(figma.currentPage, 'Restoration · contact shadow study', width, height,
    Math.round(figma.viewport.center.x - width / 2), Math.round(figma.viewport.center.y - height / 2));
  const slots = assets.map(asset => {
    const layer = box(root, asset.name, width, height, 0, 0);
    const source = figma.createComponent();
    layer.appendChild(source);
    source.name = asset.name + ' · source';
    source.resize(width, height); source.x = 0; source.y = 0;
    source.fills = []; source.strokes = []; source.clipsContent = false;
    const p = asset.paint;
    const pose = box(source, 'Pose', p.w, p.h, p.x, p.y);
    picture(pose, 'Paint', p, p.x, p.y);
    if (asset.field) {
      picture(pose, 'Contact field', asset.field, p.x, p.y).visible = false;
    }
    return {layer, source};
  });
  slots.forEach((receiver, i) => {
    const paint = assets[i].paint;
    // Leave room for posing beyond the resting overlap.
    const range = {x: paint.x - 40, y: paint.y - 40, w: paint.w + 80, h: paint.h + 80};
    const casters = assets.map((asset, j) => j > i && asset.field && intersects(range, asset.field) ? j : -1)
      .filter(j => j >= 0);
    if (!casters.length) return;
    const light = box(receiver.layer, 'Contact shadows · linked', width, height, 0, 0);
    const mask = instance(light, receiver.source);
    mask.isMask = true; mask.maskType = 'ALPHA';
    for (const j of casters) {
      const proxy = instance(light, slots[j].source);
      proxy.name = assets[j].name + ' · shade';
      // Indexing children includes the hidden field even when Figma skips invisible instance descendants in searches.
      const parts = proxy.children[0].children;
      parts.find(node => node.name === 'Paint').visible = false;
      parts.find(node => node.name === 'Contact field').visible = true;
    }
    light.locked = true;
  });
  figma.currentPage.selection = [root];
  figma.viewport.scrollAndZoomIntoView([root]);
  return root;
}

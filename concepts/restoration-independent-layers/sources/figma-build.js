// Builds native, self-updating Figma geometry. No polling, network or external image imports.
function buildReview(assets) {
  const W = 660, H = 880;
  function frame(parent, name) {
    const node = figma.createFrame();
    parent.appendChild(node);
    node.name = name;
    node.resize(W, H);
    node.x = 0; node.y = 0;
    node.fills = []; node.strokes = []; node.clipsContent = false;
    return node;
  }
  function rectangle(parent, name, fills) {
    const node = figma.createRectangle();
    parent.appendChild(node); node.name = name;
    node.resize(W, H); node.x = 0; node.y = 0; node.fills = fills; node.strokes = [];
    return node;
  }
  function instance(parent, master) {
    const node = master.createInstance();
    parent.appendChild(node); node.x = 0; node.y = 0;
    return node;
  }
  function asMask(node) {
    node.isMask = true;
    node.maskType = 'ALPHA';
  }

  const root = frame(figma.currentPage, 'Restoration · independent layers');
  const center = figma.viewport.center;
  root.x = Math.round(center.x - W / 2); root.y = Math.round(center.y - H / 2);

  const slots = assets.map(asset => {
    const holder = frame(root, asset.name);
    const master = figma.createComponent();
    holder.appendChild(master);
    master.name = asset.name + ' · source';
    master.resize(W, H); master.x = 0; master.y = 0;
    master.fills = []; master.strokes = []; master.clipsContent = false;
    const hash = figma.createImage(figma.base64Decode(asset.png)).hash;
    const paint = rectangle(master, 'Paint · move, rotate or hide', [{type:'IMAGE', scaleMode:'FILL', imageHash:hash}]);
    paint.resize(asset.width, asset.height);
    paint.x = asset.x; paint.y = asset.y;
    return {holder, master, paint};
  });

  for (let i = 0; i < slots.length - 1; i++) {
    const receiver = slots[i];
    const light = frame(receiver.holder, 'Contact shadows · linked');
    asMask(instance(light, receiver.master));
    for (let j = i + 1; j < slots.length; j++) {
      const caster = slots[j];
      const shadow = frame(light, caster.holder.name + ' · cast');
      asMask(instance(shadow, caster.master));
      const ink = rectangle(shadow, 'Contact shade', [{type:'SOLID', color:{r:0,g:0,b:0}}]);
      ink.resize(W*3,H*3); ink.x=-W; ink.y=-H;
      shadow.opacity = 0.27;
      shadow.effects = [{type:'LAYER_BLUR', radius:2.35, visible:true}];
      shadow.x = 1; shadow.y = 3;
    }
    light.locked = true;
  }
  figma.currentPage.selection = [root];
  figma.viewport.scrollAndZoomIntoView([root]);
  return root;
}


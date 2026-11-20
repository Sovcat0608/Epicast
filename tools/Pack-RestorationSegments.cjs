const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { buildSize } = require('./artwork/Build-SkycutterSizes.cjs');
const { sharpen } = require('./artwork/Build-SkycutterCAS.cjs');

const root = path.join(__dirname, '..');
const output = process.argv[2];
const layers = JSON.parse(fs.readFileSync(path.join(output, 'segments.json'), 'utf8'));
const contacts = JSON.parse(fs.readFileSync(path.join(output, 'shard-contacts.json'), 'utf8'));
const manifestPath = path.join(__dirname, 'media-manifest.json');
const media = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const banks = {};
const contactBanks = {};
const fabricOutputs = new Set();
const atlas = 1024;

function save(family, size, page, pixels) {
    const header = Buffer.alloc(18);
    header[2] = 2;
    header[16] = 32;
    header[17] = 40;
    header.writeUInt16LE(atlas, 12);
    header.writeUInt16LE(atlas, 14);
    const file = `Media/Restoration${family}CASSize${size}Page${page}.tga`;
    const buffer = Buffer.concat([header, pixels]);
    fs.writeFileSync(path.join(root, file), buffer);
    media[file] = { bytes: buffer.length, sha256: crypto.createHash('sha256').update(buffer).digest('hex') };
    if (family === 'FabricContacts') fabricOutputs.add(file);
}

function bake(size) {
    const bank = {};
    const scale = size / 660;
    const cells = [];
    for (const layer of layers) {
        const [x, y, width, height] = layer.rect;
        bank[layer.id] = { rect: [x/660, y/880, width/660, height/880], clips: {} };
        if (layer.hover) bank[layer.id].hover = layer.hover;
        for (const [state, clip] of Object.entries(layer.clips)) {
            const frames = [];
            bank[layer.id].clips[state] = { period: clip.period, frames };
            if (clip.envelope) bank[layer.id].clips[state].envelope = clip.envelope;
            if (clip.stages) bank[layer.id].clips[state].stages = clip.stages;
            if (clip.restRamp) bank[layer.id].clips[state].restRamp = clip.restRamp;
            if (clip.startFrames) bank[layer.id].clips[state].startFrames = clip.startFrames;
            if (clip.restIdleCel) bank[layer.id].clips[state].restIdleCel = clip.restIdleCel;
            for (let index = 0; index < clip.frames; index += 1) {
                cells.push({
                    source: path.join(output, `${layer.id}-${state}-${index}.bgra`),
                    width, height, w: Math.max(1, Math.round(scale*width)), h: Math.max(1, Math.round(scale*height)),
                    frames, index,
                });
            }
        }
    }
    pack('Segments', size, cells);
    return bank;
}

function pack(family, size, cells) {
    cells.sort((a,b) => b.h-a.h || b.w-a.w);
    const dedup = family === 'FabricContacts' ? new Map() : null;
    let x = 0, y = 0, shelf = 0, page = 1, pixels = Buffer.alloc(atlas*atlas*4);
    for (const cell of cells) {
        const { w, h, width, height } = cell;
        const [left, top, fullWidth, fullHeight] = cell.crop || [0, 0, w, h];
        const ref = buildSize(fs.readFileSync(cell.source), width, height, fullWidth, fullHeight);
        const image = sharpen(ref, fullWidth, fullHeight);
        const stride = image.readUInt16LE(12);
        // An interior cut needs the adjacent filtered texels in its gutters.
        const xMin = left > 0 ? -1 : 0;
        const xMax = left+w < fullWidth ? w+1 : w;
        const yMin = top > 0 ? -1 : 0;
        const yMax = top+h < fullHeight ? h+1 : h;
        const rows = [];
        for (let row=yMin; row<yMax; row++) {
            const offset = 18+((top+row)*stride+left+xMin)*4;
            rows.push(image.subarray(offset,offset+(xMax-xMin)*4));
        }
        let digest;
        if (dedup) {
            const hash = crypto.createHash('sha256').update(`${w}/${h}/${xMin}/${yMin}/${xMax}/${yMax}`);
            for (const row of rows) hash.update(row);
            digest = hash.digest('hex');
            const same = dedup.get(digest);
            if (same) { cell.frames[cell.index] = same; continue; }
        }
        if (x+w+2 > atlas) { x=0; y+=shelf; shelf=0; }
        if (y+h+2 > atlas) {
            save(family, size, page++, pixels);
            x=0; y=0; shelf=0; pixels=Buffer.alloc(atlas*atlas*4);
        }
        rows.forEach((row,index)=>row.copy(pixels,((y+yMin+index+1)*atlas+x+1+xMin)*4));
        cell.frames[cell.index] = [page,(x+1)/atlas,(y+1)/atlas,(x+1+w)/atlas,(y+1+h)/atlas];
        if (dedup) dedup.set(digest,cell.frames[cell.index]);
        x+=w+2;
        shelf=Math.max(shelf,h+2);
    }
    save(family,size,page,pixels);
    console.log(`${family} ${size}: ${cells.length} cels on ${page} atlas pages${dedup ? ` (${dedup.size} unique)` : ''}`);
}

function bakeContacts(size) {
    const bank = {};
    const cells = [];
    const scale = size / 660;
    for (const layer of layers) {
        const receiver = contacts.receivers[layer.id];
        const shard = layer.id === 'leftSlats' || layer.id === 'rightSlats';
        if (!receiver && !shard) continue;
        const [, , width, height] = layer.rect;
        const fullWidth = Math.round(scale*width), fullHeight = Math.round(scale*height);
        function add(state, frames, count, x, y, w, h) {
            const crop = [x, y, fullWidth, fullHeight];
            for (let step=1; step<=count; step++) {
                const source = path.join(output, `contact-${layer.id}-${state}-${step}.bgra`);
                cells.push({ source, width, height, w, h, crop, frames, index: step-1 });
            }
        }
        if (shard) {
            const idle = [], channel = [];
            add('idle', idle, contacts.steps, 0, 0, fullWidth, fullHeight);
            add('channel', channel, contacts.steps, 0, 0, fullWidth, fullHeight);
            bank[layer.id] = { idle, channel };
        } else {
            const top = Math.floor(receiver.top*fullHeight/height);
            const bottom = Math.ceil(receiver.bottom*fullHeight/height);
            const split = Math.round(receiver.split*fullWidth/width);
            const left = [], right = [];
            add('leftSlats', left, contacts.steps+1, 0, top, split, bottom-top);
            add('rightSlats', right, contacts.steps+1, split, top, fullWidth-split, bottom-top);
            bank[layer.id] = { left, right, windows: [
                [0, 0, 1, top/fullHeight], [0, bottom/fullHeight, 1, 1],
                [0, top/fullHeight, split/fullWidth, bottom/fullHeight],
                [split/fullWidth, top/fullHeight, 1, bottom/fullHeight],
            ] };
        }
    }
    pack('ShardContacts', size, cells);
    return bank;
}

function bakeFabricContacts(size, bank) {
    const cells = [];
    const scale = size / 660;
    for (const layer of layers) {
        const contact = contacts.fabric[layer.id];
        if (!contact) continue;
        const {left, levels, poseCount, channelFrames, offsets, banner} = contact;
        const [, , width, height] = layer.rect;
        const fullWidth = Math.round(scale*width), fullHeight = Math.round(scale*height);
        const split = Math.round(contact.split*fullWidth/width);
        const edge = split/fullWidth;
        const crop = [left ? 0 : split, 0, fullWidth, fullHeight];
        const w = left ? split : fullWidth-split;
        const idle = [], channel = [];
        for (const [state, variants] of [['idle', idle], ['channel', channel]]) {
            let index = 0;
            for (let step=0; step<=contacts.steps; step++) {
                for (let pose=1; pose<=poseCount; pose++) {
                    const source = path.join(output, `fabric-${layer.id}-${state}-${step}-${pose}.bgra`);
                    const hidden = pose===offsets.hidden;
                    cells.push({ source, width, height, w:hidden?fullWidth:w, h:fullHeight,
                        crop:hidden?undefined:crop, frames:variants, index:index++ });
                }
            }
        }
        bank[layer.id].fabric = {
            banner, levels, poseCount, channelFrames, offsets, idle, channel,
            window: left ? [0,0,edge,1] : [edge,0,1,1],
            remainder: left ? [edge,0,1,1] : [0,0,edge,1],
        };
    }
    pack('FabricContacts', size, cells);
}

function bakeTreantContacts(size, bank) {
    const region = contacts.receivers.roots.treant;
    if (!region) return;
    const rootLayer = layers.find(layer => layer.id === 'roots');
    const face = layers.find(layer => layer.id === 'treant');
    const [, , width, height] = rootLayer.rect;
    const fullWidth = Math.round(size/660*width);
    const fullHeight = Math.round(size/660*height);
    const [left, top, right, bottom] = region.map((coordinate,i) =>
        Math.round(coordinate*(i%2 ? fullHeight/height : fullWidth/width)));
    const lowerBand = bank.roots.windows[1][1];
    const [xl, yt, xr, yb] = [left/fullWidth,Math.max(top/fullHeight,lowerBand),right/fullWidth,bottom/fullHeight];
    const cut = Math.round(yt*fullHeight);
    const cells = [];
    const clips = {};
    for (const [state,clip] of Object.entries(face.clips)) {
        const frames = [];
        clips[state] = frames;
        for (let index=0; index<clip.frames; index++) {
            const source = path.join(output,'treant-contact-'+state+'-'+index+'.bgra');
            cells.push({source,width,height,w:right-left,h:bottom-cut,crop:[left,cut,fullWidth,fullHeight],frames,index});
        }
    }
    pack('TreantContacts',size,cells);
    bank.roots.treant = {clips,window:[xl,yt,xr,yb],remainder:[
        [0,lowerBand,1,yt],[0,yt,xl,yb],[xr,yt,1,yb],[0,yb,1,1]
    ]};
}

function lua(value) {
    if (typeof value==='string') return JSON.stringify(value);
    if (typeof value==='number'||typeof value==='boolean') return String(value);
    if (Array.isArray(value)) return '{'+value.map(lua).join(',')+'}';
    return '{'+Object.entries(value).map(([key,v])=>'['+lua(key)+']='+lua(v)).join(',')+'}';
}

for (const size of [192,288,384,480,576,660]) {
    banks[size]=bake(size);
    contactBanks[size]=bakeContacts(size);
    bakeFabricContacts(size, contactBanks[size]);
    bakeTreantContacts(size, contactBanks[size]);
}
const definitions=layers.map(({id,name,states,enabled})=>enabled===false?{id,name,states,enabled}:{id,name,states});
const files=Object.entries(banks).map(([size,bank])=>`[${size}]=${lua(bank)}`);
const contactFiles=Object.entries(contactBanks).map(([size,bank])=>`[${size}]=${lua(bank)}`);
fs.writeFileSync(path.join(root,'RestorationSegmentsData.lua'),
    `-- Generated by tools/Build-RestorationSegments.py.\nlocal _,E=...\nE.RestorationSegments=${lua(definitions)}\nE.RestorationSegmentBanks={\n${files.join(',\n')}\n}\n`+
    `E.RestorationShardTravel=${contacts.travel}\nE.RestorationShardContactBanks={\n${contactFiles.join(',\n')}\n}\n`);
for (const file of Object.keys(media)) {
    if (/^Media\/RestorationFabricContactsCASSize(?:192|288|384|480|576|660)Page\d+\.tga$/.test(file) && !fabricOutputs.has(file)) {
        fs.unlinkSync(path.join(root,file));
        delete media[file];
    }
}
fs.writeFileSync(manifestPath,JSON.stringify(media,null,2)+'\n');

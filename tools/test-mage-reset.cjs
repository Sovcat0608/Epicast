const fs=require('fs'),assert=require('assert');
const retired=/^(Mage(?:Fire|Frost|Arcane)|Arcane(?:Tome|Scroll|Sigil))/;
assert(!fs.readdirSync('Media').some(name=>retired.test(name)));
const manifest=JSON.parse(fs.readFileSync('tools/media-manifest.json','utf8'));
assert(!Object.keys(manifest).some(name=>retired.test(name.replace('Media/',''))));
assert(!fs.existsSync('concepts/mage-specialization-trio'));
const toc=fs.readFileSync('Epicast.toc','utf8');
for(const file of ['MageBooks.lua','MageCrests.lua','MageCrestData.lua','Seal.lua']){
 assert(!fs.existsSync(file));assert(!toc.includes(file));
}
const originalAssets=Object.keys(manifest).filter(name=>
 !/^Media\/RestorationIdle(?:CASSize(?:192|288|480|576|660)Page)?\d\d\.tga$/.test(name) &&
 !/^Media\/Restoration(?:Segments|ShardContacts|FabricContacts|TreantContacts)CASSize(?:192|288|384|480|576|660)Page\d+\.tga$/.test(name));
assert.equal(originalAssets.length,49,'Thirty static Druid textures, eighteen Mage textures and addon icon remain');
console.log('PASS: retired Mage art absent from source/media/package manifest; Druid and icon payload retained');

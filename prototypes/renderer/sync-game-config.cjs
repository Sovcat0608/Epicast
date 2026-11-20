// Explicit, one-way import of the six saved crest preferences. The save is data.
const fs = require('node:fs');
const path = require('node:path');
const parser = require('luaparse');

const specs = { DRUID: ['balance', 'feral', 'restoration'], MAGE: ['fire', 'frost', 'arcane'] };
const cache = path.join(__dirname, '.cache', 'game-config.json');

function fields(node) {
 if (node?.type !== 'TableConstructorExpression') return {};
 return Object.fromEntries(node.fields.filter(field => field.type === 'TableKeyString' ||
  (field.type === 'TableKey' && field.key.type === 'StringLiteral'))
  .map(field => [field.key.name ?? field.key.value, field.value]));
}

function scalar(node) {
 if (['BooleanLiteral', 'NumericLiteral'].includes(node?.type)) return node.value;
 if (node?.type === 'UnaryExpression' && node.operator === '-' && node.argument.type === 'NumericLiteral') {
  return -node.argument.value;
 }
 return undefined;
}

function extract(source) {
 const {body} = parser.parse(source, {luaVersion: '5.1', encodingMode: 'pseudo-latin1'});
 const declaration = body[0];
 if (body.length !== 1 || declaration?.type !== 'AssignmentStatement' ||
  declaration.variables.length !== 1 || declaration.variables[0].name !== 'EpicastDB') {
  throw Error('Expected one EpicastDB assignment in the saved preferences.');
 }
 const saved = fields(declaration.init[0]);
 if (scalar(saved.version) !== 6) throw Error('Expected Epicast schema 6 preferences.');
 const classes = fields(fields(saved.content).classes);
 const result = {};
 for (const [classID, keys] of Object.entries(specs)) {
  const bank = fields(classes[classID]);
  const slots = fields(bank.slots);
  const active = fields(bank.active);
  for (const key of keys) {
   if (!slots[key]) throw Error('Saved crest is missing: ' + classID + ':' + key);
   const slot = fields(slots[key]);
   const preferences = {};
   for (const field of ['size', 'x', 'y', 'flip', 'effects']) {
    const value = scalar(slot[field]);
    if (typeof value === (['flip','effects'].includes(field) ? 'boolean' : 'number')) preferences[field] = value;
   }
   preferences.shown = scalar(active[key]) === true;
   result[classID + ':' + key] = preferences;
  }
 }
 return result;
}

function sync(geometry = []) {
 const game = process.env.EPICAST_GAME_ROOT || 'D:/World of Warcraft';
 const account = path.join(game, '_forever_', 'WTF', 'Account');
 const sources = fs.readdirSync(account, {withFileTypes: true})
  .filter(entry => entry.isDirectory())
  .map(entry => path.join(account, entry.name, 'SavedVariables', 'Epicast.lua'))
  .filter(file => fs.existsSync(file));
 if (sources.length !== 1) throw Error('Expected exactly one Forever account with Epicast preferences.');
 const [file] = sources;
 const crests = extract(fs.readFileSync(file, 'utf8'));
 const [pixelWidth, pixelHeight, uiWidth, uiHeight] = geometry.map(Number);
 if (geometry.length && (geometry.length !== 4 || ![pixelWidth,pixelHeight,uiWidth,uiHeight].every(n => n > 0 && Number.isFinite(n)))) {
  throw Error('Supply physical width, physical height, UIParent width and UIParent height.');
 }
 const profile = {savedAt: fs.statSync(file).mtime.toISOString(), crests};
 if (geometry.length) profile.pixelsPerUnit = {x: pixelWidth/uiWidth, y: pixelHeight/uiHeight};
 else if (fs.existsSync(cache)) profile.pixelsPerUnit = JSON.parse(fs.readFileSync(cache, 'utf8')).pixelsPerUnit;
 fs.mkdirSync(path.dirname(cache), {recursive: true});
 const temporary = cache + '.tmp';
 fs.writeFileSync(temporary, JSON.stringify(profile, null, 2) + '\n');
 fs.renameSync(temporary, cache);
 return profile;
}

if (require.main === module) {
 try {
  const profile = sync(process.argv.slice(2));
  console.log('Synced six Druid and Mage crests from the last save:', profile.savedAt);
 } catch (error) {
  console.error(error.message);
  process.exitCode = 1;
 }
}
module.exports = {cache, extract};

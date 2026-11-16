const fs=require('fs'),assert=require('assert/strict'),parser=require('luaparse'),crypto=require('crypto');
const bytes=fs.readFileSync('tests/fixtures/arcane-beta13.json');
const approved=JSON.parse(bytes),ast=parser.parse(fs.readFileSync('ArcanePreset.lua','utf8'),{luaVersion:'5.1',encodingMode:'pseudo-latin1'});
function value(n){
 if(['NumericLiteral','StringLiteral','BooleanLiteral'].includes(n.type))return n.value;
 if(n.type==='UnaryExpression'&&n.operator==='-')return-value(n.argument);
 assert.equal(n.type,'TableConstructorExpression');
 const entries=n.fields.map(f=>[value(f.key),value(f.value)]);
 return entries.every(([k])=>typeof k==='number')?entries.sort((a,b)=>a[0]-b[0]).map(e=>e[1]):Object.fromEntries(entries);
}
assert.deepEqual(value(ast.body[1].init[0]),approved,'Baked preset must match every exported setting, binding and layer order');
assert.equal(approved.length,12);assert.equal(approved.filter(r=>r.behavior==='bound').length,6);
assert.deepEqual(approved.filter(r=>r.behavior==='bound').map(r=>r.binding.kind),['cast','buff','success','success','pulse','channel']);
console.log('PASS: all approved Arcane effect and binding values match exact effect-only fixture ('+crypto.createHash('sha256').update(bytes).digest('hex')+')');

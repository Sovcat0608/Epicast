const fs = require("node:fs"), vm = require("node:vm"), path = require("node:path");
const dir = path.join(__dirname,"../prototypes/feather-cels/crown-symbol");
const context = vm.createContext({loadImage:()=>null, document:{createElement:()=>({getContext:()=>null})}});
for (const file of ["track.js","preview.js"]) vm.runInContext(fs.readFileSync(path.join(dir,file),"utf8"),context);
console.log(JSON.stringify(vm.runInContext(`
    const symbol = loadCrownSymbol(restorationCrownSymbol);
    const start = symbol.sample("Channel",0,0,1);
    Object.fromEntries([["idle",72,3000],["channel",37,925],["impact",40,1000]].map(
        ([state,frames,period])=>[state,{period,poses:Array.from({length:frames},(_,i)=>{
            const time = period*i/frames;
            return symbol.sample(state==="idle"?"Idle":state==="channel"?"Channel":"Impact",
                time,state==="idle"?time:0,1,start);
        })}]))
`,context)));

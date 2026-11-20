// Reproducible patch over the pinned, locally cloned WTL renderer source.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'../vendor/source');
const pin='4017528a7edf10a06714643716cf4a5fc56854cf';
// Retain the exact shaders of the pinned upstream binary. Shader reflection
// metadata is already in the source tree; no shader semantics are changed.
const js=fs.readFileSync(path.join(root,'../project.js'),'utf8'),data=fs.readFileSync(path.join(root,'../project.data'));
const files=[...js.matchAll(/\{filename:"([^"]+)",start:(\d+),end:(\d+)\}/g)].map(m=>({filename:m[1],start:+m[2],end:+m[3]}));
if(!files.length)throw Error('Pinned shader package metadata missing');
for(const f of files){
 const name=f.filename.replace(/^\//,'');
 if(!/^glsl\/[a-zA-Z0-9_./-]+$/.test(name)||name.includes('..'))throw Error('Unexpected shader path');
 const target=path.join(root,'../build',name);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,data.subarray(f.start,f.end));
}
if(cp.execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim()!==pin)throw Error('Unexpected renderer source revision');
function write(file,text){if(!fs.existsSync(file)||fs.readFileSync(file,'utf8')!==text)fs.writeFileSync(file,text);}
function patch(file,fn){const original=cp.execFileSync('git',['show','HEAD:'+file],{cwd:root,encoding:'utf8',maxBuffer:8e6});write(path.join(root,file),fn(original));}
function replace(s,a,b){if(!s.includes(a))throw Error('Patch anchor not found: '+a.slice(0,80));return s.replace(a,b);}
write(path.join(root,'emscripten_port/src/EpicastCamera.h'),fs.readFileSync(path.join(__dirname,'EpicastCamera.h'),'utf8'));
write(path.join(root,'emscripten_port/src/EpicastStudio.h'),fs.readFileSync(path.join(__dirname,'EpicastStudio.h'),'utf8'));
patch('wowViewerLib/src/gapi/ogl3.3/textures/GTextureGL33.h',s=>replace(s,'    ~GTextureGL33() override;','    GLuint epicastTextureID() const { return textureIdentifier; }\n    ~GTextureGL33() override;'));
// Upstream's uniform-buffer flush assumes one scene. At a buffer boundary it
// indexes earlier scene arrays with the current scene's index, overrunning them.
// Flush the lexicographic [lastUploadIndx, {k,i}) range across scene arrays.
patch('wowViewerLib/src/gapi/ogl3.3/GDeviceGL33.cpp',s=>{
 s=replace(s,'for (int x = lastUploadIndx[0]; x < bufferChunks.size(); x++) {\n                    const auto &buffersUpl = *bufferChunks[x];\n                    for (int y = lastUploadIndx[1]; (x <= k) && (y < i); y++) {','for (int x = lastUploadIndx[0]; x <= k; x++) {\n                    const auto &buffersUpl = *bufferChunks[x];\n                    const int end = x == k ? i : buffersUpl.size();\n                    for (int y = x == lastUploadIndx[0] ? lastUploadIndx[1] : 0; y < end; y++) {');
 return replace(s,'for (int y = lastUploadIndx[1]; y < buffersUpl.size(); y++) {','for (int y = x == lastUploadIndx[0] ? lastUploadIndx[1] : 0; y < buffersUpl.size(); y++) {');
});
patch('wowViewerLib/CMakeLists.txt',s=>s.replace('if (1)\n    add_subdirectory(shaders)','if (0)\n    add_subdirectory(shaders)'));
patch('emscripten_port/src/main.cpp',s=>replace(s,'extern "C" {',`#include "EpicastCamera.h"
std::shared_ptr<EpicastCamera> epicastCamera = std::make_shared<EpicastCamera>();
#include "EpicastStudio.h"
extern "C" {
    EMSCRIPTEN_KEEPALIVE
    void setEpicastCamera(const float* values) {
        epicastCamera->configure(values);
        apiContainer->camera = epicastCamera;
    }
    EMSCRIPTEN_KEEPALIVE
    void getEpicastDebug(float* values) {
        std::static_pointer_cast<M2Scene>(currentScene)->epicastDebug(values);
    }
`));
patch('wowViewerLib/src/engine/objects/scenes/m2Scene.h',s=>replace(s,'    void setAnimationId(int animationId) override {','    void epicastDebug(float* values) { m_m2Object->epicastDebug(values); }\n    void setAnimationId(int animationId) override {'));
patch('wowViewerLib/src/engine/objects/m2/m2Object.h',s=>replace(s,'    void setAlwaysDraw(bool value) {','    void epicastDebug(float* p);\n    void setAlwaysDraw(bool value) {'));
patch('wowViewerLib/src/engine/objects/m2/m2Object.cpp',s=>s+`\nvoid M2Object::epicastDebug(float* p) {
        for (int i = 0; i < 8; ++i) p[i] = 0;
        if (!m_animationManager) { p[0] = -1; return; }
        m_animationManager->epicastDebug(p);
        for (auto e : particleEmitters) { p[4] += e->isEnabled ? 1 : 0; p[5] += e->epicastCount(); }
    }\n`);
patch('wowViewerLib/src/engine/managers/animationManager.h',s=>replace(s,'    void resetCurrentAnimation();',`    void epicastDebug(float* p) {
        p[0] = animationInfo.currentAnimation.animationIndex;
        p[1] = animationInfo.currentAnimation.animationTime;
        p[2] = animationInfo.currentAnimation.animationRecord->id;
        p[3] = animationInfo.currentAnimation.animationRecord->flags;
    }
    void resetCurrentAnimation();`));
patch('wowViewerLib/src/engine/managers/particles/particleEmitter.h',s=>replace(s,'    int flags = 6;','    int epicastCount() { return particles.size(); }\n    int flags = 6;'));
// Quote paths (the workspace contains spaces); modern Emscripten exports the
// UTF8 helper as a runtime method, not a native function.
patch('emscripten_port/CMakeLists.txt',s=>s.replace('--pre-js ${CMAKE_CURRENT_SOURCE_DIR}/prejs.js --js-library ${CMAKE_CURRENT_SOURCE_DIR}/jsLib.js','--pre-js \'${CMAKE_CURRENT_SOURCE_DIR}/prejs.js\' --js-library \'${CMAKE_CURRENT_SOURCE_DIR}/jsLib.js\'').replace(',\\"UTF8ToString\\"','').replace('\\"FS\\",','\\"UTF8ToString\\",\\"FS\\",').replace('target_link_options(project PUBLIC "SHELL: -pthread=0")',''));
console.log('Applied Epicast camera and diagnostic patch to '+pin);

// Independent native scenes share one GPU context. Keep upstream animation,
// materials, asynchronous loading and the SceneComposer frame pipeline intact.
#include "../../wowViewerLib/src/gapi/ogl3.3/GDeviceGL33.h"
#include <map>
struct StudioLayer {
    std::shared_ptr<M2Scene> scene;
    std::shared_ptr<EpicastCamera> camera = std::make_shared<EpicastCamera>();
    HFrameBuffer target;
    int width = 0, height = 0;
    float opacity = 0, desaturation = 0;
};
std::map<int, StudioLayer> studioLayers;
std::vector<int> studioOrder;
int studioNext = 1;
GLuint studioProgram = 0, studioVao = 0, studioArt = 0;
float studioArtRect[5] = {0,0,0,0,0};
GLuint studioShader(GLenum type, const char* source) {
    GLuint shader = glCreateShader(type); glShaderSource(shader,1,&source,nullptr); glCompileShader(shader);
    return shader;
}
void studioInitComposite() {
    if(studioProgram) return;
    const char* vs = "#version 300 es\nprecision highp float; uniform vec4 rect; out vec2 uv; void main(){ vec2 p=vec2(float(gl_VertexID&1),float(gl_VertexID>>1)); uv=p; gl_Position=vec4(rect.xy+p*rect.zw,0,1);}";
    const char* fs = "#version 300 es\nprecision highp float; uniform sampler2D source; uniform float opacity; uniform float flip; uniform float desaturation; in vec2 uv; out vec4 color; void main(){vec4 c=texture(source,vec2(uv.x,mix(uv.y,1.0-uv.y,flip))); c.rgb=mix(c.rgb,vec3(dot(c.rgb,vec3(.299,.587,.114))),desaturation); color=c*opacity;}";
    GLuint v=studioShader(GL_VERTEX_SHADER,vs),f=studioShader(GL_FRAGMENT_SHADER,fs);
    studioProgram=glCreateProgram(); glAttachShader(studioProgram,v);glAttachShader(studioProgram,f);glLinkProgram(studioProgram);glDeleteShader(v);glDeleteShader(f);glGenVertexArrays(1,&studioVao);
}
void studioQuad(GLuint texture,float x,float y,float width,float height,float opacity,float flip,float desaturation) {
    glBindTexture(GL_TEXTURE_2D,texture);
    glUniform4f(glGetUniformLocation(studioProgram,"rect"),x,y,width,height);
    glUniform1f(glGetUniformLocation(studioProgram,"opacity"),opacity);
    glUniform1f(glGetUniformLocation(studioProgram,"flip"),flip);
    glUniform1f(glGetUniformLocation(studioProgram,"desaturation"),desaturation);
    glDrawArrays(GL_TRIANGLE_STRIP,0,4);
}
extern "C" {
EMSCRIPTEN_KEEPALIVE int studioCreate(int fileID) {
    if(studioLayers.size()>=32)return 0;
    int id=studioNext++; StudioLayer layer;layer.scene=std::make_shared<M2Scene>(apiContainer,fileID,-1);studioLayers.emplace(id,std::move(layer));return id;
}
EMSCRIPTEN_KEEPALIVE void studioRemove(int id) { studioLayers.erase(id); }
EMSCRIPTEN_KEEPALIVE void studioConfigure(int id,const float* values,float opacity,float desaturation) {
    auto it=studioLayers.find(id);if(it==studioLayers.end())return;
    it->second.camera->configure(values);it->second.opacity=opacity;it->second.desaturation=desaturation;
}
EMSCRIPTEN_KEEPALIVE void studioAnimation(int id,int animation) {
    auto it=studioLayers.find(id);if(it!=studioLayers.end())it->second.scene->setAnimationId(animation);
}
EMSCRIPTEN_KEEPALIVE void studioDebug(int id,float* values) {
    for(int i=0;i<8;i++)values[i]=0;values[0]=-1;
    auto it=studioLayers.find(id);if(it!=studioLayers.end())it->second.scene->epicastDebug(values);
}
EMSCRIPTEN_KEEPALIVE void studioSetOrder(const int* ids,int count) { studioOrder.assign(ids,ids+std::min(33,std::max(0,count))); }
EMSCRIPTEN_KEEPALIVE void studioArtwork(int width,int height,const void* pixels) {
    if(!studioArt)glGenTextures(1,&studioArt);glActiveTexture(GL_TEXTURE0);glBindTexture(GL_TEXTURE_2D,studioArt);
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,width,height,0,GL_RGBA,GL_UNSIGNED_BYTE,pixels);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
}
EMSCRIPTEN_KEEPALIVE void studioArtworkRect(float x,float y,float w,float h,float opacity) {
    studioArtRect[0]=x;studioArtRect[1]=y;studioArtRect[2]=w;studioArtRect[3]=h;studioArtRect[4]=opacity;
}
EMSCRIPTEN_KEEPALIVE void studioFrame(double delta,int width,int height) {
    if(!sceneComposer||!apiContainer->hDevice)return;
    apiContainer->camera=epicastCamera;
    glfwPollEvents();processor->processRequests(false);
    HFrameScenario scenario=std::make_shared<FrameScenario>();std::vector<HDrawStage> dependencies;
    for(auto& entry:studioLayers) {
        auto& layer=entry.second;
        if(!layer.target||layer.width!=width||layer.height!=height) {
            layer.width=width;layer.height=height;
            layer.target=apiContainer->hDevice->createFrameBuffer(width,height,{ITextureFormat::itRGBA},ITextureFormat::itDepth32,1,-1);
        }
        auto matrices=layer.camera->getCameraMatrices(1,1,.01,100);
        auto cull=scenario->addCullStage(matrices,layer.scene);
        auto update=scenario->addUpdateStage(cull,delta*1000.0,matrices);
        auto draw=scenario->addDrawStage(update,layer.scene,matrices,dependencies,true,{{0,0},{width,height}},true,false,mathfu::vec4(0,0,0,0),layer.target);
        dependencies={draw};
    }
    if(!studioLayers.empty())sceneComposer->draw(scenario);
    studioInitComposite();
    glBindFramebuffer(GL_FRAMEBUFFER,0);glViewport(0,0,width,height);glDisable(GL_SCISSOR_TEST);glDisable(GL_DEPTH_TEST);glDepthMask(GL_FALSE);glDisable(GL_CULL_FACE);
    glColorMask(GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE);glClearColor(0,0,0,0);glClear(GL_COLOR_BUFFER_BIT);
    glEnable(GL_BLEND);glBlendEquation(GL_FUNC_ADD);glBlendFunc(GL_ONE,GL_ONE_MINUS_SRC_ALPHA);
    glUseProgram(studioProgram);glBindVertexArray(studioVao);glActiveTexture(GL_TEXTURE0);glUniform1i(glGetUniformLocation(studioProgram,"source"),0);
    for(int id:studioOrder) {
        if(id==0) { if(studioArt&&studioArtRect[4]>0)studioQuad(studioArt,studioArtRect[0],studioArtRect[1],studioArtRect[2],studioArtRect[3],studioArtRect[4],1,0);continue; }
        auto it=studioLayers.find(id);if(it==studioLayers.end()||!it->second.target||it->second.opacity<=0)continue;
        auto& layer=it->second;auto tex=std::static_pointer_cast<GTextureGL33>(layer.target->getAttachment(0));
        studioQuad(tex->epicastTextureID(),-1,-1,2,2,layer.opacity,0,layer.desaturation);
    }
    glBindVertexArray(0);glUseProgram(0);glBindTexture(GL_TEXTURE_2D,0);glDepthMask(GL_TRUE);
    apiContainer->hDevice->reset();glfwSwapBuffers(window);
}
}

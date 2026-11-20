// Explicit ModelScene camera for the isolated Epicast preview.
// The client scales/translates the actor. We use its equivalent camera in
// unscaled model coordinates so billboards, sorting and culling agree too.
#pragma once
#include "../../wowViewerLib/src/engine/camera/planarCamera.h"
class EpicastCamera : public PlanarCamera {
    CameraMatrices matrices;
public:
    void configure(const float* p) {
        matrices.lookAtMat = mathfu::mat4(p);
        matrices.perspectiveMat = mathfu::mat4(p + 16);
        matrices.cameraPos = mathfu::vec4(p[32], p[33], p[34], 1);
        // The shaders expect world-up expressed in view coordinates.
        matrices.viewUp = mathfu::vec4(p[8], p[9], p[10], 0);
        matrices.interiorDirectLightDir = mathfu::vec4(0, 0, -1, 0);
    }
    HCameraMatrices getCameraMatrices(float, float, float, float) override {
        return std::make_shared<CameraMatrices>(matrices);
    }
    bool isCompatibleWithInfiniteZ() override { return false; }
    void tick(animTime_t) override {}
    void setCameraPos(float, float, float) override {}
    void setCameraOffset(float, float, float) override {}
    void getCameraPosition(float* p) override {
        for (int i = 0; i < 3; ++i) p[i] = matrices.cameraPos[i];
    }
};

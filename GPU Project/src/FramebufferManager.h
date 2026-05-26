#pragma once

#include <glad/glad.h>

// Manages all FBOs, textures, and RBOs used by the AA pipeline.
// Call init() once after OpenGL context is created.
// Call resize() from framebuffer_size_callback.
class FramebufferManager
{
public:
    // Texture
    GLuint colorTex         = 0;  // Resolved single-sample color
    GLuint multiSamplingTex = 0;  // MSAA color
    GLuint edgeTex          = 0;  // SMAA edge detection result
    GLuint blendTex         = 0;  // SMAA blending weight result
    GLuint imageTex         = 0;  // Static test image
    GLuint detailTex        = 0;  // Magnified detail inset (250x250)
    GLuint areaTex          = 0;  // SMAA area LUT
    GLuint searchTex        = 0;  // SMAA search LUT
    GLuint currentTex       = 0;  // TAA current frame
    GLuint previousTex      = 0;  // TAA previous frame
    GLuint Subsample1       = 0;
    GLuint Subsample2       = 0;

    // FBO
    GLuint colorFBO       = 0;
    GLuint multisampledFBO = 0;
    GLuint edgeFBO        = 0;
    GLuint blendFBO       = 0;
    GLuint detailFBO      = 0;
    GLuint currentFBO     = 0;
    GLuint previousFBO    = 0;

    // RBO
    GLuint colorRBO        = 0;
    GLuint multiSampledRBO = 0;
    GLuint detailRBO       = 0;

    // Initialize all GPU resources.
    // imagePath    : path to the test image loaded into imageTex
    // width/height : initial framebuffer size
    // msaaSamples  : sample count for the multisampled FBO
    // Returns false if any resource creation fails.
    bool init(const char* imagePath, int width, int height, GLuint msaaSamples);

    // Recreate size-dependent textures and RBOs after a window resize.
    // Call this from framebuffer_size_callback.
    void resize(int width, int height, GLuint msaaSamples);

    // Delete all GPU resources (call before glfwTerminate).
    void cleanup();

private:
    void createColorTextures(int width, int height);
    void createMSAATextures(int width, int height, GLuint msaaSamples);
    void createSMAATextures(int width, int height);
    void createTAATextures(int width, int height);
    void createSubsampleTextures(int width, int height);
    void createDetailTexture();
    void createFBOs(GLuint msaaSamples, int width, int height);

    // Helper: create a standard RGBA8 2D texture with linear filtering.
    static GLuint makeLinearTex(int width, int height);
};

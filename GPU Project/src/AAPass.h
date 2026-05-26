#pragma once

#include <glad/glad.h>
#include <glm/glm.hpp>
#include <learnopengl/shader.h>
#include "FramebufferManager.h"

// ---------------------------------------------------------------------------
// SMAA quality preset parameters
// ---------------------------------------------------------------------------
struct SMAAParameters
{
    GLfloat threshold;
    GLfloat depthThreshold;
    GLint   maxSearchSteps;
    GLint   maxSearchStepsDiag;
    GLint   cornerRounding;
};

static const SMAAParameters smaaPresets[4] =
{
    { 0.15f, 0.1f * 0.15f,  4,  0,  0 },  // LOW
    { 0.10f, 0.1f * 0.10f,  8,  0,  0 },  // MEDIUM
    { 0.10f, 0.1f * 0.10f, 16,  8, 25 },  // HIGH
    { 0.05f, 0.1f * 0.05f, 32, 16, 25 },  // ULTRA
};

static const GLuint msaaSamples[5] = { 1, 2, 4, 8, 16 };

// ---------------------------------------------------------------------------
// AAPass
// Owns all AA-related shaders and exposes one render method per technique.
// Call init() once after OpenGL context and FramebufferManager are ready.
// ---------------------------------------------------------------------------
class AAPass
{
public:
    // Initialise all shaders and set static uniforms.
    // scrWidth/scrHeight : initial viewport size (used for screenSize uniform)
    // fb                 : the FramebufferManager whose textures we read/write
    // quadVAO            : fullscreen quad VAO owned by main
    void init(float scrWidth, float scrHeight,
        const FramebufferManager& fb,
        GLuint quadVAO);

    // Call when the window is resized so screenSize uniforms stay correct.
    void onResize(float scrWidth, float scrHeight);

    // --- Per-frame render calls ---
    // Each method assumes the scene has already been rendered into
    // fb.colorFBO (or fb.multisampledFBO for MSAA) before being called.

    // MSAA: blit multisampled -> colorFBO, then draw to screen (or currentFBO if taaOn).
    void renderMSAA(const FramebufferManager& fb, GLuint quadVAO,
        int scrWidth, int scrHeight, bool taaOn);

    // FXAA: draw colorFBO -> screen (or currentFBO if taaOn).
    void renderFXAA(const FramebufferManager& fb, GLuint quadVAO, bool taaOn);

    // SMAA: 3-pass (edge -> blend weight -> neighbor blend).
    // Outputs to screen, or to currentFBO if taaOn.
    void renderSMAA(const FramebufferManager& fb, GLuint quadVAO,
        GLuint presetIndex, bool taaOn);

    // TAA accumulation pass. Call after the base AA pass when taaOn is true.
    void renderTAA(const FramebufferManager& fb, GLuint quadVAO,
        bool firstFrame, int scrWidth, int scrHeight);

    // Update MSAA sample count (call when quality combo changes).
    void updateMSAASamples(const FramebufferManager& fb, GLuint qualityLevel);

private:
    // Shaders
    Shader* screenShader = nullptr;
    Shader* fxaaShader = nullptr;
    Shader* smaaEdgeShader = nullptr;
    Shader* smaaWeightShader = nullptr;
    Shader* smaaBlendShader = nullptr;
    Shader* taaShader = nullptr;

    GLuint m_quadVAO = 0;

    // Internal helpers
    void applySMAAQuality(GLuint presetIndex);
    void drawQuad();
};
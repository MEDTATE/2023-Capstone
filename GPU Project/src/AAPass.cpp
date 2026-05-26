#include "AAPass.h"
#include <glm/gtc/type_ptr.hpp>
#include "FramebufferManager.h"

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

void AAPass::init(float scrWidth, float scrHeight, const FramebufferManager& fb, GLuint quadVAO)
{
    m_quadVAO = quadVAO;

    // Allocate shaders
    screenShader = new Shader("shader/basicScreen.vs", "shader/basicScreen.fs");
    fxaaShader = new Shader("shader/fxaa_demo.vs", "shader/fxaa_demo.fs");
    smaaEdgeShader = new Shader("shader/smaaEdge.vs", "shader/smaaEdge.fs");
    smaaWeightShader = new Shader("shader/smaaBlendWeight.vs", "shader/smaaBlendWeight.fs");
    smaaBlendShader = new Shader("shader/smaaNeighbor.vs", "shader/smaaNeighbor.fs");
    taaShader = new Shader("shader/temporal.vs", "shader/temporal.fs");

    glm::vec4 screenSize(1.0f / scrWidth, 1.0f / scrHeight, scrWidth, scrHeight);

    // Screen shader
    screenShader->use();
    screenShader->setInt("screenTexture", 0);

    // FXAA
    fxaaShader->use();
    fxaaShader->setInt("colorTex", 0);
    fxaaShader->setVec4("screenSize", screenSize);

    // SMAA edge
    smaaEdgeShader->use();
    smaaEdgeShader->setInt("colorTex", 0);
    smaaEdgeShader->setFloat("predicationThreshold", 0.01f);
    smaaEdgeShader->setFloat("predicationScale", 2.0f);
    smaaEdgeShader->setFloat("predicationStrength", 0.4f);
    smaaEdgeShader->setVec4("screenSize", screenSize);

    // SMAA weight
    smaaWeightShader->use();
    smaaWeightShader->setInt("edgesTex", 0);
    smaaWeightShader->setInt("areaTex", 1);
    smaaWeightShader->setInt("searchTex", 2);
    smaaWeightShader->setVec4("subsampleIndices", glm::vec4(1.0f, 1.0f, 1.0f, 0.0f));
    smaaWeightShader->setFloat("predicationThreshold", 0.01f);
    smaaWeightShader->setFloat("predicationScale", 2.0f);
    smaaWeightShader->setFloat("predicationStrength", 0.4f);
    smaaWeightShader->setVec4("screenSize", screenSize);

    // SMAA blend
    smaaBlendShader->use();
    smaaBlendShader->setInt("colorTex", 0);
    smaaBlendShader->setInt("blendTex", 1);
    smaaBlendShader->setFloat("predicationThreshold", 0.01f);
    smaaBlendShader->setFloat("predicationScale", 2.0f);
    smaaBlendShader->setFloat("predicationStrength", 0.4f);
    smaaBlendShader->setVec4("screenSize", screenSize);

    // TAA
    taaShader->use();
    taaShader->setInt("currentTex", 0);
    taaShader->setInt("previousTex", 1);
    taaShader->setVec4("screenSize", screenSize);

    // Apply default SMAA preset (ULTRA)
    applySMAAQuality(3);
}

void AAPass::onResize(float scrWidth, float scrHeight)
{
    glm::vec4 screenSize(1.0f / scrWidth, 1.0f / scrHeight, scrWidth, scrHeight);

    fxaaShader->use();
    fxaaShader->setVec4("screenSize", screenSize);

    smaaEdgeShader->use();
    smaaEdgeShader->setVec4("screenSize", screenSize);

    smaaWeightShader->use();
    smaaWeightShader->setVec4("screenSize", screenSize);

    smaaBlendShader->use();
    smaaBlendShader->setVec4("screenSize", screenSize);

    taaShader->use();
    taaShader->setVec4("screenSize", screenSize);
}

// ---------------------------------------------------------------------------
// MSAA
// ---------------------------------------------------------------------------

void AAPass::renderMSAA(const FramebufferManager& fb, GLuint quadVAO, int scrWidth, int scrHeight, bool taaOn)
{
    // Resolve multisampled -> single-sample color texture
    glBindFramebuffer(GL_READ_FRAMEBUFFER, fb.multisampledFBO);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fb.colorFBO);
    glBlitFramebuffer(0, 0, scrWidth, scrHeight, 0, 0, scrWidth, scrHeight, GL_COLOR_BUFFER_BIT, GL_NEAREST);

    // Draw resolved color to screen (or currentFBO for TAA)
    GLuint targetFBO = taaOn ? fb.currentFBO : 0;
    glBindFramebuffer(GL_FRAMEBUFFER, targetFBO);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glDisable(GL_DEPTH_TEST);

    screenShader->use();
    glBindVertexArray(quadVAO);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, fb.colorTex);
    glDrawArrays(GL_TRIANGLES, 0, 6);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

// ---------------------------------------------------------------------------
// FXAA
// ---------------------------------------------------------------------------

void AAPass::renderFXAA(const FramebufferManager& fb, GLuint quadVAO, bool taaOn)
{
    GLuint targetFBO = taaOn ? fb.currentFBO : 0;
    glBindFramebuffer(GL_FRAMEBUFFER, targetFBO);
    glDisable(GL_DEPTH_TEST);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    fxaaShader->use();
    glBindVertexArray(quadVAO);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, fb.colorTex);
    glDrawArrays(GL_TRIANGLES, 0, 6);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

// ---------------------------------------------------------------------------
// SMAA (3 passes ? called once regardless of TAA state)
// ---------------------------------------------------------------------------

void AAPass::renderSMAA(const FramebufferManager& fb, GLuint quadVAO, GLuint presetIndex, bool taaOn)
{
    applySMAAQuality(presetIndex);

    /* Pass 1: Edge detection ¡æ edgeFBO */
    glBindFramebuffer(GL_FRAMEBUFFER, fb.edgeFBO);
    glDisable(GL_DEPTH_TEST);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    smaaEdgeShader->use();
    glBindVertexArray(quadVAO);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, fb.colorTex);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    /* Pass 2: Blending weight ¡æ blendFBO */
    glBindFramebuffer(GL_FRAMEBUFFER, fb.blendFBO);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    smaaWeightShader->use();
    glBindVertexArray(quadVAO);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, fb.edgeTex);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, fb.areaTex);
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, fb.searchTex);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    /* Pass 3: Neighborhood blending ¡æ screen (or currentFBO for TAA) */
    GLuint targetFBO = taaOn ? fb.currentFBO : 0;
    glBindFramebuffer(GL_FRAMEBUFFER, targetFBO);

    smaaBlendShader->use();
    glBindVertexArray(quadVAO);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, fb.colorTex);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, fb.blendTex);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

// ---------------------------------------------------------------------------
// TAA accumulation (call after base AA pass)
// ---------------------------------------------------------------------------

void AAPass::renderTAA(const FramebufferManager& fb, GLuint quadVAO,
    bool firstFrame, int scrWidth, int scrHeight)
{
    taaShader->use();
    glBindVertexArray(quadVAO);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, fb.currentTex);
    glActiveTexture(GL_TEXTURE1);
    // First frame: no history yet, reuse current as previous
    glBindTexture(GL_TEXTURE_2D, firstFrame ? fb.currentTex : fb.previousTex);

    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    // Copy result into previousFBO for next frame
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fb.previousFBO);
    glBlitFramebuffer(0, 0, scrWidth, scrHeight,
        0, 0, scrWidth, scrHeight,
        GL_COLOR_BUFFER_BIT, GL_NEAREST);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

// ---------------------------------------------------------------------------
// MSAA sample count update (called from UI when quality combo changes)
// ---------------------------------------------------------------------------

void AAPass::updateMSAASamples(const FramebufferManager& fb, GLuint qualityLevel)
{
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, fb.multiSamplingTex);
    glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE,
        msaaSamples[qualityLevel], GL_RGB,
        0, 0, GL_TRUE); // width/height updated via resize()
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);

    glBindRenderbuffer(GL_RENDERBUFFER, fb.multiSampledRBO);
    glRenderbufferStorageMultisample(GL_RENDERBUFFER,
        msaaSamples[qualityLevel],
        GL_DEPTH24_STENCIL8, 0, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

void AAPass::applySMAAQuality(GLuint idx)
{
    const SMAAParameters& p = smaaPresets[idx];

    smaaEdgeShader->use();
    smaaEdgeShader->setFloat("smaaThershold", p.threshold);
    smaaEdgeShader->setFloat("smaaDepthThreshold", p.depthThreshold);
    smaaEdgeShader->setInt("smaaMaxSearchSteps", p.maxSearchSteps);
    smaaEdgeShader->setInt("smaaMaxSearchStepsDiag", p.maxSearchStepsDiag);
    smaaEdgeShader->setInt("smaaCornerRounding", p.cornerRounding);

    smaaWeightShader->use();
    smaaWeightShader->setFloat("smaaThershold", p.threshold);
    smaaWeightShader->setFloat("smaaDepthThreshold", p.depthThreshold);
    smaaWeightShader->setInt("smaaMaxSearchSteps", p.maxSearchSteps);
    smaaWeightShader->setInt("smaaMaxSearchStepsDiag", p.maxSearchStepsDiag);
    smaaWeightShader->setInt("smaaCornerRounding", p.cornerRounding);

    smaaBlendShader->use();
    smaaBlendShader->setFloat("smaaThershold", p.threshold);
    smaaBlendShader->setFloat("smaaDepthThreshold", p.depthThreshold);
    smaaBlendShader->setInt("smaaMaxSearchSteps", p.maxSearchSteps);
    smaaBlendShader->setInt("smaaMaxSearchStepsDiag", p.maxSearchStepsDiag);
    smaaBlendShader->setInt("smaaCornerRounding", p.cornerRounding);
}
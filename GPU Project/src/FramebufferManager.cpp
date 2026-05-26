#include "FramebufferManager.h"

#include <stb_image.h>
#include <AreaTex.h>
#include <SearchTex.h>
#include <iostream>
#include <cstring>  // memcpy

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

bool FramebufferManager::init(const char* imagePath,
                              int width, int height,
                              GLuint msaaSamples)
{
    // Test image
    int imgW, imgH, channels;
    unsigned char* imageData = stbi_load(imagePath, &imgW, &imgH, &channels, 0);
    if (!imageData)
    {
        std::cout << "FramebufferManager: failed to load image: " << imagePath << std::endl;
        return false;
    }
    glGenTextures(1, &imageTex);
    glBindTexture(GL_TEXTURE_2D, imageTex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, imgW, imgH, 0,
                 GL_RGB, GL_UNSIGNED_BYTE, imageData);
    stbi_image_free(imageData);

    // SMAA area
    unsigned char* buf = new unsigned char[AREATEX_SIZE];
    for (unsigned int y = 0; y < AREATEX_HEIGHT; ++y)
    {
        unsigned int srcY = AREATEX_HEIGHT - 1 - y;
        memcpy(&buf[y * AREATEX_PITCH],
               areaTexBytes + srcY * AREATEX_PITCH,
               AREATEX_PITCH);
    }
    glGenTextures(1, &areaTex);
    glBindTexture(GL_TEXTURE_2D, areaTex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RG8,
                 (GLsizei)AREATEX_WIDTH, (GLsizei)AREATEX_HEIGHT,
                 0, GL_RG, GL_UNSIGNED_BYTE, buf);

    // SMAA search
    delete[] buf;
    buf = new unsigned char[SEARCHTEX_SIZE];
    for (unsigned int y = 0; y < SEARCHTEX_HEIGHT; ++y)
    {
        unsigned int srcY = SEARCHTEX_HEIGHT - 1 - y;
        memcpy(&buf[y * SEARCHTEX_PITCH],
               searchTexBytes + srcY * SEARCHTEX_PITCH,
               SEARCHTEX_PITCH);
    }
    glGenTextures(1, &searchTex);
    glBindTexture(GL_TEXTURE_2D, searchTex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_R8,
                 (GLsizei)SEARCHTEX_WIDTH, (GLsizei)SEARCHTEX_HEIGHT,
                 0, GL_RED, GL_UNSIGNED_BYTE, buf);
    delete[] buf;

    glBindTexture(GL_TEXTURE_2D, 0);

    // Detail
    createDetailTexture();

    // --- Size-dependent resources ---
    createColorTextures(width, height);
    createMSAATextures(width, height, msaaSamples);
    createSMAATextures(width, height);
    createTAATextures(width, height);
    createSubsampleTextures(width, height);
    createFBOs(msaaSamples, width, height);

    return true;
}

void FramebufferManager::resize(int width, int height, GLuint msaaSamples)
{
    // Resize color texture
    glBindTexture(GL_TEXTURE_2D, colorTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

    // Resize MSAA texture
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, multiSamplingTex);
    glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE,
                            msaaSamples, GL_RGB, width, height, GL_TRUE);

    // Resize SMAA textures
    glBindTexture(GL_TEXTURE_2D, edgeTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glBindTexture(GL_TEXTURE_2D, blendTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

    // Resize TAA textures
    glBindTexture(GL_TEXTURE_2D, currentTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glBindTexture(GL_TEXTURE_2D, previousTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

    // Resize RBOs
    glBindRenderbuffer(GL_RENDERBUFFER, multiSampledRBO);
    glRenderbufferStorageMultisample(GL_RENDERBUFFER, msaaSamples,
                                     GL_DEPTH24_STENCIL8, width, height);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, width, height);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);

    glBindTexture(GL_TEXTURE_2D, 0);
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);
}

void FramebufferManager::cleanup()
{
    GLuint textures[] = {
        colorTex, multiSamplingTex, edgeTex, blendTex,
        imageTex, detailTex, areaTex, searchTex,
        currentTex, previousTex, Subsample1, Subsample2
    };
    glDeleteTextures(12, textures);

    GLuint fbos[] = {
        colorFBO, multisampledFBO, edgeFBO, blendFBO,
        detailFBO, currentFBO, previousFBO
    };
    glDeleteFramebuffers(7, fbos);

    GLuint rbos[] = { colorRBO, multiSampledRBO, detailRBO };
    glDeleteRenderbuffers(3, rbos);
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

GLuint FramebufferManager::makeLinearTex(int width, int height)
{
    GLuint id;
    glGenTextures(1, &id);
    glBindTexture(GL_TEXTURE_2D, id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    return id;
}

void FramebufferManager::createColorTextures(int width, int height)
{
    colorTex = makeLinearTex(width, height);
}

void FramebufferManager::createMSAATextures(int width, int height, GLuint msaaSamples)
{
    glGenTextures(1, &multiSamplingTex);
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, multiSamplingTex);
    glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE,
                            msaaSamples, GL_RGB, width, height, GL_TRUE);
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);
}

void FramebufferManager::createSMAATextures(int width, int height)
{
    edgeTex  = makeLinearTex(width, height);
    blendTex = makeLinearTex(width, height);
}

void FramebufferManager::createTAATextures(int width, int height)
{
    currentTex  = makeLinearTex(width, height);
    previousTex = makeLinearTex(width, height);
}

void FramebufferManager::createSubsampleTextures(int width, int height)
{
    Subsample1 = makeLinearTex(width, height);
    Subsample2 = makeLinearTex(width, height);
}

void FramebufferManager::createDetailTexture()
{
    glGenTextures(1, &detailTex);
    glBindTexture(GL_TEXTURE_2D, detailTex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 250, 250,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
}

void FramebufferManager::createFBOs(GLuint msaaSamples, int width, int height)
{
    // Color FBO (single-sample)
    glGenFramebuffers(1, &colorFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, colorFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, colorTex, 0);
    glGenRenderbuffers(1, &colorRBO);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT,
                              GL_RENDERBUFFER, colorRBO);

    // MSAA FBO
    glGenFramebuffers(1, &multisampledFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, multisampledFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D_MULTISAMPLE, multiSamplingTex, 0);
    glGenRenderbuffers(1, &multiSampledRBO);
    glBindRenderbuffer(GL_RENDERBUFFER, multiSampledRBO);
    glRenderbufferStorageMultisample(GL_RENDERBUFFER, msaaSamples,
                                     GL_DEPTH24_STENCIL8, width, height);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT,
                              GL_RENDERBUFFER, multiSampledRBO);

    // SMAA FBOs
    glGenFramebuffers(1, &edgeFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, edgeFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, edgeTex, 0);

    glGenFramebuffers(1, &blendFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, blendFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, blendTex, 0);

    // TAA FBOs
    glGenFramebuffers(1, &currentFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, currentFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, currentTex, 0);

    glGenFramebuffers(1, &previousFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, previousFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, previousTex, 0);

    // Detail inset FBO
    glGenFramebuffers(1, &detailFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, detailFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, detailTex, 0);
    glGenRenderbuffers(1, &detailRBO);
    glBindRenderbuffer(GL_RENDERBUFFER, detailRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, 250, 250);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT,
                              GL_RENDERBUFFER, detailRBO);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

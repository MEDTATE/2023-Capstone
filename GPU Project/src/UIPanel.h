#pragma once

#include "imgui/imgui.h"
#include "imgui/imgui_impl_glfw.h"
#include "imgui/imgui_impl_opengl3.h"

#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include "FramebufferManager.h"
#include "AAPass.h"

#include <fstream>
#include <string>
#include <thread>

class Model;
class Camera;

// --- Globals declared in main.cpp ---
extern float SCR_WIDTH;
extern float SCR_HEIGHT;
extern std::string frameDisplay;
extern GLFWwindow* window;

extern Camera camera;

extern bool antiAliasing;
extern bool msaa, fxaa, smaa, taa, wasTAAOn;
extern bool temporalAAFirstFrame;
extern bool isImage, detailScreen;

extern int  currentAA;
extern GLuint msaaQualityLevel;
extern GLuint smaaPreset;
extern int  currentMSAAQuality;
extern int  previousMSAAQuailty;
extern int  currentSMAAQuality;
extern int  previousSMAAQuality;

extern FramebufferManager fbManager;

// Models (전역 포인터)
extern Model* container;
extern Model* sponza;
extern Model* currentModel;

// Functions declared in main.cpp
void changeViewpoint(int view);
void timeChecker(std::ofstream& outputFile, bool& benchActive);

// Renders the ImGui control panel for one frame.
// Call between ImGui::NewFrame() and ImGui::Render().
void renderUIPanel(std::ofstream& outputFile);

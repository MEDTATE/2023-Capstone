#pragma once

#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <learnopengl/camera.h>
#include <fstream>

// --- Globals declared in main.cpp ---
extern float SCR_WIDTH;
extern float SCR_HEIGHT;

extern Camera camera;
extern float deltaTime;
extern float lastX;
extern float lastY;
extern bool firstMouse;
extern bool allowMouseInput;

extern bool taa;
extern bool wasTAAOn;
extern bool temporalAAFirstFrame;
extern bool isImage;

extern float cursorPosX;
extern float cursorPosY;

extern class FramebufferManager fbManager;
extern class AAPass aaPass;
extern const GLuint msaaSamples[];
extern GLuint msaaQualityLevel;

// GLFW 콜백
void framebuffer_size_callback(GLFWwindow* window, int width, int height);
void mouse_callback(GLFWwindow* window, double xposIn, double yposIn);
void scroll_callback(GLFWwindow* window, double xoffset, double yoffset);
void MouseButtonCallback(GLFWwindow* window, int button, int action, int mods);
void CursorPosCallback(GLFWwindow* window, double xpos, double ypos);
void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods);

// 매 프레임 키 입력 처리
void processInput(GLFWwindow* window);

// 카메라 뷰포인트 프리셋
void changeViewpoint(int view);

// 벤치마크 타이머 (별도 스레드에서 실행)
void timeChecker(std::ofstream& outputFile, bool& benchActive);

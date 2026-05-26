#include "InputHandler.h"
#include "FramebufferManager.h"
#include "AAPass.h"

#include <glm/glm.hpp>
#include <iostream>
#include <chrono>
#include <thread>

// ---------------------------------------------------------------------------
// Per-frame key input
// ---------------------------------------------------------------------------

void processInput(GLFWwindow* window)
{
    if (taa && !wasTAAOn)
        wasTAAOn = true;

    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);

    auto resetTAA = [&]() 
    {
        if (taa && wasTAAOn) 
        {
            wasTAAOn = false;
            temporalAAFirstFrame = true;
        }
    };

    if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS) 
    {
        resetTAA();
        camera.ProcessKeyboard(FORWARD, deltaTime);
    }
    if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
    {
        resetTAA();
        camera.ProcessKeyboard(BACKWARD, deltaTime);
    }
    if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
    {
        resetTAA();
        camera.ProcessKeyboard(LEFT, deltaTime);
    }
    if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS) 
    {
        resetTAA();
        camera.ProcessKeyboard(RIGHT, deltaTime);
    }

    float velocity = deltaTime * 5.0f;
    if (glfwGetKey(window, GLFW_KEY_UP) == GLFW_PRESS) 
    {
        resetTAA();
        camera.Position += camera.Up * velocity;
    }
    if (glfwGetKey(window, GLFW_KEY_DOWN) == GLFW_PRESS) 
    {
        resetTAA();
        camera.Position -= camera.Up * velocity;
    }
}

// ---------------------------------------------------------------------------
// GLFW callbacks
// ---------------------------------------------------------------------------

void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
    SCR_WIDTH  = width;
    SCR_HEIGHT = height;
    fbManager.resize(width, height, msaaSamples[msaaQualityLevel]);
    aaPass.onResize(width, height);
    glViewport(0, 0, width, height);
}

void mouse_callback(GLFWwindow* window, double xposIn, double yposIn)
{
    float xpos = static_cast<float>(xposIn);
    float ypos = static_cast<float>(yposIn);

    if (glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_RELEASE)
    {
        if (taa && !wasTAAOn)
            wasTAAOn = true;
        lastX = xpos;
        lastY = ypos;
        return;
    }

    if (firstMouse)
    {
        lastX = xpos;
        lastY = ypos;
        firstMouse = false;
    }

    float xoffset = xpos - lastX;
    float yoffset = lastY - ypos;
    lastX = xpos;
    lastY = ypos;

    if (!allowMouseInput)
        return;

    if (taa && wasTAAOn) 
    {
        wasTAAOn = false;
        temporalAAFirstFrame = true;
    }

    camera.ProcessMouseMovement(xoffset, yoffset);
}

void scroll_callback(GLFWwindow* window, double xoffset, double yoffset)
{
    camera.ProcessMouseScroll(static_cast<float>(yoffset));
}

void MouseButtonCallback(GLFWwindow* window, int button, int action, int mods)
{
    std::cout << "Button Clicked!: " << button << std::endl;
}

void CursorPosCallback(GLFWwindow* window, double xpos, double ypos)
{
    std::cout << "Cursor moved! x: " << xpos << " y: " << ypos << std::endl;
}

void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
    if (key == GLFW_KEY_P && action == GLFW_PRESS)
    {
        printf("Pos: (%f, %f, %f), POV: (%f, %f)\n",
               camera.Position.x, camera.Position.y, camera.Position.z,
               camera.Yaw, camera.Pitch);
    }
}

// ---------------------------------------------------------------------------
// Viewpoint presets
// ---------------------------------------------------------------------------

void changeViewpoint(int view)
{
    if (!isImage)
    {
        if (view == 1) {
            camera.Position = glm::vec3(-35.0f, 10.0f, 0.0f);
            camera.Yaw   = -360.0f;
            camera.Pitch = -0.5f;
            camera.ProcessMouseMovement(0, 0);
        }
        if (view == 2) {
            camera.Position = glm::vec3(-1.70f, 7.44f, -7.60f);
            camera.Yaw   = 111.90f;
            camera.Pitch = -6.60f;
            camera.ProcessMouseMovement(0, 0);
        }
        if (view == 3) {
            camera.Position = glm::vec3(-10.09f, 7.89f, -6.09f);
            camera.Yaw   = -40.60f;
            camera.Pitch = 33.30f;
            camera.ProcessMouseMovement(0, 0);
        }
    }
}

// ---------------------------------------------------------------------------
// Benchmark timer (runs on a separate thread)
// ---------------------------------------------------------------------------

void timeChecker(std::ofstream& outputFile, bool& benchActive)
{
    std::cout << "timer set" << std::endl;
    outputFile << "start benchmarking" << std::endl;

    std::this_thread::sleep_for(std::chrono::seconds(10));

    outputFile << "recorded fps for 10s" << std::endl;
    benchActive = false;
    std::cout << "timer ended" << std::endl;
}

#define _CRT_SECURE_NO_WARNINGS

#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include "FramebufferManager.h"
#include "AAPass.h"
#include "UIPanel.h"
#include "InputHandler.h"

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

#include <learnopengl/shader.h>
#include <learnopengl/camera.h>
#include <learnopengl/model.h>

#include <iostream>
#include <iomanip>
#include <thread>
#include <chrono>

// settings
float SCR_WIDTH = 1600.0;
float SCR_HEIGHT = 900.0;

// camera
Camera camera(glm::vec3(-35.0f, 10.0f, 0.0f), glm::vec3(0.0f, 1.0f, 0.0f), -360.0f, -0.5f);
float lastX = (float)SCR_WIDTH / 2.0;
float lastY = (float)SCR_HEIGHT / 2.0;
bool firstMouse = true;
bool allowMouseInput = true;

// timing
float deltaTime = 0.0f;
float lastFrame = 0.0f;

float offsetX = 0.0f;
float offsetY = 0.0f;

// fps counter
double prevTime = 0.0;
double crntTime = 0.0;
double timeDiff;
unsigned int counter = 0;
std::string frameDisplay;
void timeChecker(std::ofstream& outputFile, bool& benchActive);

// global projection variables
glm::mat4 globalCurrProj;
glm::mat4 globalPrevProj;

// TAA reprojection
unsigned int temporalFrame = 0;
bool temporalReproject = false;
glm::mat4 currViewProj;
glm::mat4 prevViewProj;
float reprojectionWeightScale = 30.0f;

// jittering
glm::vec2 jitter;
const glm::vec2 jitters[2] = {
    { -0.25f,  0.25f }
    ,{ 0.25f,  -0.25f }
};

// detail screen
float cursorPosX = 0.0;
float cursorPosY = 0.0;

// AA variables
bool antiAliasing;
bool msaa;
bool fxaa;
bool smaa;
bool taa;
bool wasTAAOn;

int currentAA = 0;

bool temporalAAFirstFrame = true;

bool isImage;

bool detailScreen;

FramebufferManager fbManager;
AAPass aaPass;
GLFWwindow* window = nullptr;

GLuint quadVAO, quadVBO;

Model* container = nullptr;
Model* sponza = nullptr;
Model* currentModel = nullptr;

// highest as default
GLuint msaaQualityLevel = 4;
GLuint smaaPreset = 3;

int currentMSAAQuality = 4;
int previousMSAAQuailty = 0;

int currentSMAAQuality = 3;
int previousSMAAQuality = 0;

static void glfw_error_callback(int error, const char* description)
{
    fprintf(stderr, "GLFW Error %d: %s\n", error, description);
}

int main()
{
    // glfw: initialize and configure
    // ------------------------------
    glfwSetErrorCallback(glfw_error_callback);
    if (!glfwInit())
        return 1;
    const char* glsl_version = "#version 450";
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 5);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

#ifdef __APPLE__
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif

    // glfw window creation
    // --------------------
    window = glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "Anti Aliasing Project", NULL, NULL);
    if (window == NULL)
    {
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    // glfwSetMouseButtonCallback(window, mouse_callback);
    glfwSetCursorPosCallback(window, mouse_callback);
    glfwSetScrollCallback(window, scroll_callback);
    glfwSetKeyCallback(window, key_callback);

    // tell GLFW to capture our mouse
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);

    // Setup Dear ImGui context
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    (void)io;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard; // Enable Keyboard Controls
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;  // Enable Gamepad Controls
    io.ConfigWindowsResizeFromEdges = false;

    // Setup Dear ImGui style
    ImGui::StyleColorsDark();
    // ImGui::StyleColorsLight();

    // Setup Platform/Renderer backends
    ImGui_ImplGlfw_InitForOpenGL(window, true);
    ImGui_ImplOpenGL3_Init(glsl_version);

    // Load Fonts
    // - If no fonts are loaded, dear imgui will use the default font. You can also load multiple fonts and use ImGui::PushFont()/PopFont() to select them.
    // - AddFontFromFileTTF() will return the ImFont* so you can store it if you need to select the font among multiple.
    // - If the file cannot be loaded, the function will return NULL. Please handle those errors in your application (e.g. use an assertion, or display an error and quit).
    // - The fonts will be rasterized at a given size (w/ oversampling) and stored into a texture when calling ImFontAtlas::Build()/GetTexDataAsXXXX(), which ImGui_ImplXXXX_NewFrame below will call.
    // - Use '#define IMGUI_ENABLE_FREETYPE' in your imconfig file to use Freetype for higher quality font rendering.
    // - Read 'docs/FONTS.md' for more instructions and details.
    // - Remember that in C/C++ if you want to include a backslash \ in a string literal you need to write a double backslash \\ !
    // - Our Emscripten build process allows embedding fonts to be accessible at runtime from the "fonts/" folder. See Makefile.emscripten for details.
    // io.Fonts->AddFontDefault();
    // io.Fonts->AddFontFromFileTTF("c:\\Windows\\Fonts\\segoeui.ttf", 18.0f);
    // io.Fonts->AddFontFromFileTTF("../../misc/fonts/DroidSans.ttf", 16.0f);
    // io.Fonts->AddFontFromFileTTF("../../misc/fonts/Roboto-Medium.ttf", 16.0f);
    // io.Fonts->AddFontFromFileTTF("../../misc/fonts/Cousine-Regular.ttf", 15.0f);
    // ImFont* font = io.Fonts->AddFontFromFileTTF("c:\\Windows\\Fonts\\ArialUni.ttf", 18.0f, NULL, io.Fonts->GetGlyphRangesJapanese());
    // IM_ASSERT(font != NULL);

    // Our state
    bool show_demo_window = true;
    bool show_another_window = false;
    ImVec4 clear_color = ImVec4(0.5f, 0.5f, 0.5f, 1.00f);

    // glad: load all OpenGL function pointers
    // ---------------------------------------
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        std::cout << "Failed to initialize GLAD" << std::endl;
        return -1;
    }

    // configure global opengl state
    // -----------------------------
    glEnable(GL_DEPTH_TEST);

    // load textures
    glEnable(GL_TEXTURE_2D);

    // create a color attachment texture
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_TEXTURE_2D);

    if (!fbManager.init("resources/Images/SyntheticTests.png", SCR_WIDTH, SCR_HEIGHT, msaaSamples[msaaQualityLevel]))
        return -1;

    // build and compile shaders
    // -------------------------
    Shader modelShader("shader/basicModel.vs", "shader/basicModel.fs");
    Shader imageShader("shader/ImageShader.vs", "shader/ImageShader.fs");

    // load models
    container = new Model("resources/objects/container/Container.obj");           
    sponza = new Model("resources/objects/sponza-master/sponza.obj");             
    currentModel = container;                                         

    modelShader.use();
    modelShader.setInt("texture_diffuse1", 0);
    imageShader.use();                                                      
    imageShader.setInt("texture_diffuse1", 0);

    float quadVertices[] = { // vertex attributes for a quad that fills the entire screen in Normalized Device Coordinates.
        // positions   // texCoords
        -1.0f,  1.0f,  0.0f, 1.0f,
        -1.0f, -1.0f,  0.0f, 0.0f,
         1.0f, -1.0f,  1.0f, 0.0f,

        -1.0f,  1.0f,  0.0f, 1.0f,
         1.0f, -1.0f,  1.0f, 0.0f,
         1.0f,  1.0f,  1.0f, 1.0f
    };

    // screen quad VAO
    glGenVertexArrays(1, &quadVAO);
    glGenBuffers(1, &quadVBO);
    glBindVertexArray(quadVAO);
    glBindBuffer(GL_ARRAY_BUFFER, quadVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), &quadVertices, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));

    aaPass.init(SCR_WIDTH, SCR_HEIGHT, fbManager, quadVAO);

    // load txt for benchmark result
    ofstream outputFile("result.txt");
    if (!outputFile)
    {
        std::cerr << "Failed to open text files(frame)" << std::endl;
        return 1;
    }

    // render loop
    // -----------
    while (!glfwWindowShouldClose(window))
    {
        // frame counter implementation
        // -----------------------------
        crntTime = glfwGetTime();
        timeDiff = crntTime - prevTime;
        counter++;

        if (timeDiff >= 1.0 / 5.0)
        {
            double FPS = (1.0 / timeDiff) * counter;
            double ms = (timeDiff / counter) * 1000;

            std::stringstream fpsStream, msStream;
            fpsStream << std::fixed << std::setprecision(1) << FPS;
            msStream << std::fixed << std::setprecision(1) << ms;
            frameDisplay = fpsStream.str() + "FPS/ " + msStream.str() + "ms";

            outputFile << fpsStream.str() + "\n";

            prevTime = crntTime;
            counter = 0;
        }
        // per-frame time logic
        // --------------------
        float currentFrame = static_cast<float>(glfwGetTime());
        deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;

        // Start the Dear ImGui frame
        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();

        // input
        // -----
        processInput(window);

        /* ----- Render Control Panel GUI ----- */
        renderUIPanel(outputFile);

        if (antiAliasing)
        {
            if (msaa)
            {
                glBindFramebuffer(GL_FRAMEBUFFER, fbManager.multisampledFBO);
            }
            else
            {
                glBindFramebuffer(GL_FRAMEBUFFER, fbManager.colorFBO);
            }
        }
        else
        {
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
        }

        glEnable(GL_DEPTH_TEST); // enable depth testing (is disabled for rendering screen-space quad)

        glClearColor(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        // view/projection transformations
        glm::mat4 model;

        glm::mat4 projection = glm::perspective(glm::radians(camera.Zoom), (float)SCR_WIDTH / (float)SCR_HEIGHT, 0.1f, 10000.0f);
        glm::mat4 view = camera.GetViewMatrix();

        glm::mat4 viewProj = projection * view * model;

        if (!isImage)
        {
            allowMouseInput = true;
            modelShader.use();

            if (!taa)
            {
                modelShader.setMat4("projection", projection);
                modelShader.setMat4("view", view);
            }
            else
            {
                temporalFrame = (temporalFrame + 1) % 2;

                jitter = jitters[temporalFrame];
                jitter = jitter * 2.0f * glm::vec2(1.0f / SCR_WIDTH, 1.0f / SCR_HEIGHT);
                glm::mat4 jitterMatrix = glm::translate(glm::identity<glm::mat4>(), glm::vec3(jitter, 0.0f));
                projection = jitterMatrix * projection;

                modelShader.setMat4("projection", globalCurrProj);
                modelShader.setMat4("view", view);

                prevViewProj = currViewProj;
                currViewProj = projection;
                globalCurrProj = currViewProj;
                globalPrevProj = prevViewProj;

            }
            glm::mat4 model = glm::mat4(1.0f);
            model = glm::translate(model, glm::vec3(0.0f, 0.0f, 0.0f)); // translate it down so it's at the center of the scene
            model = glm::scale(model, glm::vec3(0.05f, 0.05f, 0.05f));  // it's a bit too big for our scene, so scale it down
            modelShader.setMat4("model", model);
            currentModel->Draw(modelShader);
        }
        else
        {
            allowMouseInput = false;
            imageShader.use();

            if (!taa)
            {
                imageShader.setMat4("projection", projection);
                imageShader.setMat4("view", view);
            }
            else
            {
                temporalFrame = (temporalFrame + 1) % 2;

                jitter = jitters[temporalFrame];
                jitter = jitter * 2.0f * glm::vec2(1.0f / SCR_WIDTH, 1.0f / SCR_HEIGHT);
                glm::mat4 jitterMatrix = glm::translate(glm::identity<glm::mat4>(), glm::vec3(jitter, 0.0f));
                projection = jitterMatrix * projection;

                imageShader.setMat4("projection", globalCurrProj);
                imageShader.setMat4("view", view);

                prevViewProj = currViewProj;
                currViewProj = projection;
                globalCurrProj = currViewProj;
                globalPrevProj = prevViewProj;

            }

            glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
            glClear(GL_COLOR_BUFFER_BIT);
            // render the loaded model
            glm::mat4 model = glm::mat4(1.0f);
            model = glm::translate(model, glm::vec3(0.0f, 0.0f, 0.0f)); // translate it down so it's at the center of the scene
            model = glm::scale(model, glm::vec3(2.15f, 2.15f, 1.0f));   // scale

            // projection matrix (needed for final 2D views)
            // glm::mat4 projection = glm::ortho(0, width, height, 0, 0, 1000);

            // modelShader.setMat4("projection", projection);
            imageShader.setMat4("model", model);

            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, fbManager.imageTex);

            glBindVertexArray(quadVAO);
            glDrawArrays(GL_TRIANGLES, 0, 6);
        }

        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        if (antiAliasing)
        {
            glDisable(GL_DEPTH_TEST);
            glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
            glClear(GL_COLOR_BUFFER_BIT);

            if (msaa) aaPass.renderMSAA(fbManager, quadVAO, SCR_WIDTH, SCR_HEIGHT, wasTAAOn);
            if (fxaa) aaPass.renderFXAA(fbManager, quadVAO, wasTAAOn);
            if (smaa) aaPass.renderSMAA(fbManager, quadVAO, smaaPreset, wasTAAOn);

            if (wasTAAOn)
                aaPass.renderTAA(fbManager, quadVAO, temporalAAFirstFrame, SCR_WIDTH, SCR_HEIGHT);

            temporalAAFirstFrame = false;
        }

        /* ----- Render detail image where cursor located ----- */
        if (detailScreen) {
            unsigned int viewportSize = 300;
            unsigned int viewportBeginX = SCR_WIDTH - 360;
            unsigned int viewportBeginY = SCR_HEIGHT - 360;

            if (glfwGetKey(window, GLFW_KEY_SPACE) == GLFW_PRESS) {
                cursorPosX = cursorPosX;
                cursorPosY = cursorPosY;
            }
            else {
                if (lastX < 50) {
                    cursorPosX = 50;
                }
                else if (lastX > SCR_WIDTH - 70) {
                    cursorPosX = SCR_WIDTH - 70;
                }
                else {
                    cursorPosX = lastX;
                }
                if (lastY < 50) {
                    cursorPosY = SCR_HEIGHT - 50;
                }
                else if (lastY > SCR_HEIGHT - 70) {
                    cursorPosY = 70;
                }
                else {
                    cursorPosY = SCR_HEIGHT - lastY;
                }
            }

            ImGui::SetNextWindowSize(ImVec2(viewportSize + 10, viewportSize + 70), 0);
            ImGui::SetNextWindowPos(ImVec2(viewportBeginX, 60));
            ImGui::Begin("Detail Screen", NULL, ImGuiWindowFlags_NoMove);

            glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fbManager.detailFBO);
            /* ----- Cursor is the center of the detail screen ----- */
            glBlitFramebuffer(cursorPosX - 50, cursorPosY - 50, cursorPosX + 70, cursorPosY + 70, 0, 0, 300, 300, GL_COLOR_BUFFER_BIT, GL_NEAREST);

            glBindFramebuffer(GL_FRAMEBUFFER, 0);

            //glViewport(viewportBeginX, viewportBeginY, viewportSize, viewportSize);

            // we get the screen position of the window
            ImVec2 pos = ImGui::GetCursorScreenPos();

            ImGui::GetWindowDrawList()->AddImage(
                (void*)fbManager.detailTex,
                ImVec2(pos.x, pos.y + 30),
                ImVec2(pos.x + viewportSize, pos.y + viewportSize + 30),
                ImVec2(0, 1),
                ImVec2(1, 0)
            );

            ImGui::SeparatorText("Press and hold SPACE to lock the view");

            ImGui::End();

            //if (glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_RIGHT) == GLFW_PRESS) {
            //    //printf("lastX: %f, lastY: %f\n", xPos, yPos);
            //    screenShader.use();
            //    glBindVertexArray(quadVAO);
            //    glActiveTexture(GL_TEXTURE0);
            //    glBindTexture(GL_TEXTURE_2D, detailTex); // use the now resolved color attachment as the quad's texture
            //    glDrawArrays(GL_TRIANGLES, 0, 6);
            //}

        }

        ImGui::Render();

        // Render dear imgui into screen
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

        // glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
        int display_w, display_h;
        glfwGetFramebufferSize(window, &display_w, &display_h);
        glViewport(0, 0, display_w, display_h);
        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    // Cleanup
    glDeleteVertexArrays(1, &quadVAO);
    glDeleteBuffers(1, &quadVBO);
    fbManager.cleanup();
    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();
    delete container;
    delete sponza;

    glfwDestroyWindow(window);
    glfwTerminate();

    outputFile.close();

    return 0;
}
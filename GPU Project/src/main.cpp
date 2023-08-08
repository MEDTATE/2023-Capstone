#define _CRT_SECURE_NO_WARNINGS

#include "imgui/imgui.h"
#include "imgui/imgui_impl_glfw.h"
#include "imgui/imgui_impl_opengl3.h"

#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <stb_image.h>

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

#include <learnopengl/shader.h>
#include <learnopengl/camera.h>
#include <learnopengl/model.h>

#include <iostream>
#include <AreaTex.h>
#include <SearchTex.h>

void framebuffer_size_callback(GLFWwindow* window, int width, int height);
void mouse_callback(GLFWwindow* window, double xpos, double ypos);
void scroll_callback(GLFWwindow* window, double xoffset, double yoffset);
void processInput(GLFWwindow* window);
void MouseButtonCallback(GLFWwindow* window, int button, int action, int mods);
void CursorPosCallback(GLFWwindow* window, double xpos, double ypos);
void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods);
void changeViewpoint(int view);

// settings
const unsigned int SCR_WIDTH = 1200;
const unsigned int SCR_HEIGHT = 900;

// camera
Camera camera(glm::vec3(-35.0f, 10.0f, 0.0f), glm::vec3(0.0f, 1.0f, 0.0f), -360.0f, -0.5f);
float lastX = (float)SCR_WIDTH / 2.0;
float lastY = (float)SCR_HEIGHT / 2.0;
bool firstMouse = true;

// timing
float deltaTime = 0.0f;
float lastFrame = 0.0f;

// AA variables
static bool antiAliasing;
static bool fxaa;
static bool smaa;
static bool taa;
static bool cmaa;
// fxaa = 1, smaa = 2, taa = 3, cmaa = 4
// default = fxaa
static int currentAA = 1;

GLuint colorTex;
GLuint edgeTex;
GLuint blendTex;
GLuint areaTex;
GLuint searchTex;

GLuint colorFBO;
GLuint edgeFBO;
GLuint blendFBO;

GLuint colorRBO;
//GLuint edgeRBO;
//GLuint blendRBO;

GLuint quadVAO, quadVBO;

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

    // num of samples for MSAA 
    //glfwWindowHint(GLFW_SAMPLES, 4);

#ifdef __APPLE__
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif

    // glfw window creation
    // --------------------
    GLFWwindow* window = glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "Anti Aliasing Project", NULL, NULL);
    if (window == NULL)
    {
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    //glfwSetMouseButtonCallback(window, mouse_callback);
    glfwSetCursorPosCallback(window, mouse_callback);
    glfwSetScrollCallback(window, scroll_callback);
    glfwSetKeyCallback(window, key_callback);

    // tell GLFW to capture our mouse
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);

    // Setup Dear ImGui context
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls
    io.ConfigWindowsResizeFromEdges = false;

    // Setup Dear ImGui style
    ImGui::StyleColorsDark();
    //ImGui::StyleColorsLight();

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
    //io.Fonts->AddFontDefault();
    //io.Fonts->AddFontFromFileTTF("c:\\Windows\\Fonts\\segoeui.ttf", 18.0f);
    //io.Fonts->AddFontFromFileTTF("../../misc/fonts/DroidSans.ttf", 16.0f);
    //io.Fonts->AddFontFromFileTTF("../../misc/fonts/Roboto-Medium.ttf", 16.0f);
    //io.Fonts->AddFontFromFileTTF("../../misc/fonts/Cousine-Regular.ttf", 15.0f);
    //ImFont* font = io.Fonts->AddFontFromFileTTF("c:\\Windows\\Fonts\\ArialUni.ttf", 18.0f, NULL, io.Fonts->GetGlyphRangesJapanese());
    //IM_ASSERT(font != NULL);

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
    glGenTextures(1, &colorTex);
    glBindTexture(GL_TEXTURE_2D, colorTex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, SCR_WIDTH, SCR_HEIGHT, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

    glGenTextures(1, &edgeTex);
    glBindTexture(GL_TEXTURE_2D, edgeTex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, SCR_WIDTH, SCR_HEIGHT, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

    glGenTextures(1, &blendTex);
    glBindTexture(GL_TEXTURE_2D, blendTex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, SCR_WIDTH, SCR_HEIGHT, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

    // flip SMAA textures
    unsigned char* buffer1 = new unsigned char[AREATEX_SIZE];
    //std::vector<unsigned char> tempBuffer1(AREATEX_SIZE);
    for (unsigned int y = 0; y < AREATEX_HEIGHT; y++) {
        unsigned int srcY = AREATEX_HEIGHT - 1 - y;
        //unsigned int srcY = y;
        memcpy(&buffer1[y * AREATEX_PITCH], areaTexBytes + srcY * AREATEX_PITCH, AREATEX_PITCH);
    }

    glGenTextures(1, &areaTex);
    glBindTexture(GL_TEXTURE_2D, areaTex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RG8, (GLsizei)AREATEX_WIDTH, (GLsizei)AREATEX_HEIGHT, 0, GL_RG, GL_UNSIGNED_BYTE, buffer1);// areaTexBytes);

    delete[] buffer1;
    buffer1 = new unsigned char[SEARCHTEX_SIZE];

    //std::vector<unsigned char> tempBuffer2(SEARCHTEX_SIZE);
    for (unsigned int y = 0; y < SEARCHTEX_HEIGHT; y++) {
        unsigned int srcY = SEARCHTEX_HEIGHT - 1 - y;
        //unsigned int srcY = y;
        memcpy(&buffer1[y * SEARCHTEX_PITCH], searchTexBytes + srcY * SEARCHTEX_PITCH, SEARCHTEX_PITCH);
    }
    glGenTextures(1, &searchTex);
    glBindTexture(GL_TEXTURE_2D, searchTex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, (GLsizei)SEARCHTEX_WIDTH, (GLsizei)SEARCHTEX_HEIGHT, 0, GL_RED, GL_UNSIGNED_BYTE, buffer1);// searchTexBytes);

    delete[] buffer1;
    glBindTexture(GL_TEXTURE_2D, 0);

    // Initialize FBOs
    // ---------------
    glGenFramebuffers(1, &colorFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, colorFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, colorTex, 0);

    glGenRenderbuffers(1, &colorRBO);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, SCR_WIDTH, SCR_HEIGHT);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, colorRBO);

    glGenFramebuffers(1, &edgeFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, edgeFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, edgeTex, 0);

    /*
    glGenRenderbuffers(1, &edgeRBO);
    glBindRenderbuffer(GL_RENDERBUFFER, edgeRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, SCR_WIDTH, SCR_HEIGHT);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, edgeRBO);
    */

    glGenFramebuffers(1, &blendFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, blendFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, blendTex, 0);

    /*
    glGenRenderbuffers(1, &blendRBO);
    glBindRenderbuffer(GL_RENDERBUFFER, blendRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, SCR_WIDTH, SCR_HEIGHT);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, blendRBO);
    */

    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    // build and compile shaders
    // -------------------------
    Shader modelShader("shader/basicModel.vs", "shader/basicModel.fs");
    Shader fxaaShader("shader/fxaa_demo.vs", "shader/fxaa_demo.fs");

    Shader smaaEdgeShader("shader/smaaEdge.vs", "shader/smaaEdge.fs");
    Shader smaaweightShader("shader/smaaBlendWeight.vs", "shader/smaaBlendWeight.fs");
    Shader smaablendShader("shader/smaaNeighbor.vs", "shader/smaaNeighbor.fs");
    
    // load models
    // -----------
    Model container("resources/objects/container/Container.obj");
    Model sponza("resources/objects/sponza/sponza.obj");

    Model currentModel = container;

    modelShader.use();
    modelShader.setInt("texture_diffuse1", 0);

    // FXAA Shader
    // -----------
    fxaaShader.use();
    fxaaShader.setInt("colorTex", 0);
    fxaaShader.setVec4("screenSize", glm::vec4(1.0f / float(SCR_WIDTH), 1.0f / float(SCR_HEIGHT), SCR_WIDTH, SCR_HEIGHT));

    /*
    SMAA Shader
    */
    float smaa_quailty = 3; // (index, sample) : (0, 4), (1, 8), (2, 16), (3, 32)

    // Edge Shader
    // -----------
    smaaEdgeShader.use();
    //smaaEdgeShader.setInt("depthTex", 0);
    smaaEdgeShader.setInt("colorTex", 0);
    //smaaEdgeShader.setInt("predicationTex", 0);

    /*smaaEdgeShader.setFloat("predicationThreshold", 0.0);
    smaaEdgeShader.setFloat("predicationScale", 0.0);
    smaaEdgeShader.setFloat("predicationStrength", 0.0);*/

    smaaEdgeShader.setVec4("screenSize", glm::vec4(1.0f / float(SCR_WIDTH), 1.0f / float(SCR_HEIGHT), SCR_WIDTH, SCR_HEIGHT));
    smaaEdgeShader.setFloat("SMAA_QUALITY", smaa_quailty);

    // Weight Shader
    // -------------
    smaaweightShader.use();
    smaaweightShader.setInt("edgesTex", 0);
    smaaweightShader.setInt("areaTex", 1);
    smaaweightShader.setInt("searchTex", 2);

    /*smaaweightShader.setFloat("predicationThreshold", 0.0);
    smaaweightShader.setFloat("predicationScale", 0.0);
    smaaweightShader.setFloat("predicationStrength", 0.0);*/

    smaaweightShader.setVec4("screenSize", glm::vec4(1.0f / float(SCR_WIDTH), 1.0f / float(SCR_HEIGHT), SCR_WIDTH, SCR_HEIGHT));
    smaaweightShader.setFloat("SMAA_QUALITY", smaa_quailty);

    // Blend Shader
    // ------------
    smaablendShader.use();
    smaablendShader.setInt("colorTex", 0);
    smaablendShader.setInt("blendTex", 1);

    /*smaablendShader.setFloat("predicationThreshold", 0.0);
    smaablendShader.setFloat("predicationScale", 0.0);
    smaablendShader.setFloat("predicationStrength", 0.0);*/

    smaablendShader.setVec4("screenSize", glm::vec4(1.0f / float(SCR_WIDTH), 1.0f / float(SCR_HEIGHT), SCR_WIDTH, SCR_HEIGHT));
    smaablendShader.setFloat("SMAA_QUALITY", smaa_quailty);

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

    // render loop
    // -----------
    while (!glfwWindowShouldClose(window))
    {
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

        // render GUI
        {
            // Set window size before create it
            ImGui::SetNextWindowSize(ImVec2(150, 270), 0);
            ImGui::Begin("Control Pannel", NULL, ImGuiWindowFlags_NoMove);  // Create a window called "Hello, world!" and append into it.

            ImGui::SeparatorText("Anti Aliasing");
            if (ImGui::Checkbox("AA On", &antiAliasing)) {
                switch (currentAA) {
                    // remember which option was activated last time
                case 1:
                    fxaa = true;
                    break;
                case 2:
                    smaa = true;
                    break;
                case 3:
                    taa = true;
                    break;
                case 4:
                    cmaa = true;
                    break;
                }
            }

            if (ImGui::BeginTable("split", 2)) {
                ImGui::TableNextColumn();
                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                if (ImGui::Checkbox("FXAA", &fxaa)) {
                    smaa = taa = cmaa = false;
                    currentAA = 1;
                }
                ImGui::TableNextColumn();
                if (ImGui::Checkbox("SMAA", &smaa)) {
                    fxaa = taa = cmaa = false;
                    currentAA = 2;
                }
                ImGui::TableNextColumn();
                if (ImGui::Checkbox("TAA", &taa)) {
                    fxaa = smaa = cmaa = false;
                    currentAA = 3;
                }
                ImGui::TableNextColumn();
                if (ImGui::Checkbox("CMAA", &cmaa)) {
                    fxaa = smaa = taa = false;
                    currentAA = 4;
                }

                // Bind to 'AA on' button
                if (antiAliasing == false) {
                    fxaa = false;
                    smaa = false;
                    taa = false;
                    cmaa = false;
                }

                ImGui::EndTable();
            }

            // Change Viewpoint
            ImGui::SeparatorText("Viewpoint");
            if (ImGui::Button("1"))
                changeViewpoint(1);
            ImGui::SameLine();
            if (ImGui::Button("2"))
                changeViewpoint(2);
            ImGui::SameLine();
            if (ImGui::Button("3"))
                changeViewpoint(3);

            // Change Scene
            const char* items[] = { "Container", "Sponza" };
            static int item_current = 0;
            ImGui::SeparatorText("Scene");
            ImGui::Combo("Scene", &item_current, items, IM_ARRAYSIZE(items));

            switch (item_current) {
            case 0:
                currentModel = container;
                break;
            case 1:
                currentModel = sponza;
                break;
            }

            ImGui::NewLine();
            if (ImGui::Button("Exit"))
                return 0;

            ImGui::End();
        }

        if (antiAliasing)
            glBindFramebuffer(GL_FRAMEBUFFER, colorFBO);
        else
            glBindFramebuffer(GL_FRAMEBUFFER, 0);

        glEnable(GL_DEPTH_TEST); // enable depth testing (is disabled for rendering screen-space quad)

        glClearColor(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        // don't forget to enable shader before setting uniforms
        modelShader.use();

        // view/projection transformations
        glm::mat4 projection = glm::perspective(glm::radians(camera.Zoom), (float)SCR_WIDTH / (float)SCR_HEIGHT, 0.1f, 10000.0f);
        glm::mat4 view = camera.GetViewMatrix();
        modelShader.setMat4("projection", projection);
        modelShader.setMat4("view", view);

        // render the loaded model
        glm::mat4 model = glm::mat4(1.0f);
        model = glm::translate(model, glm::vec3(0.0f, 0.0f, 0.0f)); // translate it down so it's at the center of the scene
        model = glm::scale(model, glm::vec3(0.05f, 0.05f, 0.05f));	// it's a bit too big for our scene, so scale it down
        modelShader.setMat4("model", model);
        currentModel.Draw(modelShader);

        if (fxaa) {
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
            glDisable(GL_DEPTH_TEST); // disable depth test so screen-space quad isn't discarded due to depth test.
            // clear all relevant buffers
            glClearColor(1.0f, 1.0f, 1.0f, 1.0f); // set clear color to white (not really necessary actually, since we won't be able to see behind the quad anyways)
            glClear(GL_COLOR_BUFFER_BIT);

            fxaaShader.use();
            glBindVertexArray(quadVAO);
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, colorTex);	// use the color attachment texture as the texture of the quad plane
            glDrawArrays(GL_TRIANGLES, 0, 6);
        }
        if (smaa) {
            /* EDGE DETECTION PASS */
            glBindFramebuffer(GL_FRAMEBUFFER, edgeFBO);           
            glDisable(GL_DEPTH_TEST); // disable depth test so screen-space quad isn't discarded due to depth test.
            // clear all relevant buffers
            glClearColor(0.0f, 0.0f, 0.0f, 1.0f); // set clear color to white (not really necessary actually, since we won't be able to see behind the quad anyways)
            glClear(GL_COLOR_BUFFER_BIT);

            smaaEdgeShader.use();
            glBindVertexArray(quadVAO);
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, colorTex);	// use the color attachment texture as the texture of the quad plane
            glDrawArrays(GL_TRIANGLES, 0, 6);


            glBindFramebuffer(GL_FRAMEBUFFER, 0);

            /* BLENDING WEIGHT PASS */
            glBindFramebuffer(GL_FRAMEBUFFER, blendFBO);
        
            // clear all relevant buffers
            glClearColor(0.0f, 0.0f, 0.0f, 1.0f); // set clear color to white (not really necessary actually, since we won't be able to see behind the quad anyways)
            glClear(GL_COLOR_BUFFER_BIT);

            smaaweightShader.use();
            glBindVertexArray(quadVAO);

            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, edgeTex);
            glActiveTexture(GL_TEXTURE1);
            glBindTexture(GL_TEXTURE_2D, areaTex);
            glActiveTexture(GL_TEXTURE2);
            glBindTexture(GL_TEXTURE_2D, searchTex);

            glDrawArrays(GL_TRIANGLES, 0, 6);

            glBindFramebuffer(GL_FRAMEBUFFER, 0);

            /*
            /* NEIGHBORHOOD BLENDING PASS */           
            smaablendShader.use();

            glBindVertexArray(quadVAO);

            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, colorTex);
            glActiveTexture(GL_TEXTURE1);
            glBindTexture(GL_TEXTURE_2D, blendTex);

            glDrawArrays(GL_TRIANGLES, 0, 6);

        }


        // Render dear imgui into screen
        ImGui::Render();
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
    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();

    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}

// process all input: query GLFW whether relevant keys are pressed/released this frame and react accordingly
// ---------------------------------------------------------------------------------------------------------
void processInput(GLFWwindow* window)
{
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);

    if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
        camera.ProcessKeyboard(FORWARD, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
        camera.ProcessKeyboard(BACKWARD, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
        camera.ProcessKeyboard(LEFT, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
        camera.ProcessKeyboard(RIGHT, deltaTime);

    /*
    if (glfwGetKey(window, GLFW_KEY_SPACE) == GLFW_PRESS && !fxaa)
    {
        fxaa = true;
        printf("KEY PRESSED!\n");
    }
    if (glfwGetKey(window, GLFW_KEY_SPACE) == GLFW_RELEASE)
    {
        fxaa = false;
    }
    */
}

// glfw: whenever the window size changed (by OS or user resize) this callback function executes
// ---------------------------------------------------------------------------------------------
void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
    // make sure the viewport matches the new window dimensions; note that width and 
    // height will be significantly larger than specified on retina displays.
    glViewport(0, 0, width, height);
}

// glfw: whenever the mouse moves, this callback is called
// -------------------------------------------------------
void mouse_callback(GLFWwindow* window, double xposIn, double yposIn)
{
    float xpos = static_cast<float>(xposIn);
    float ypos = static_cast<float>(yposIn);
    if (glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_RELEASE)
    {
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
    float yoffset = lastY - ypos; // reversed since y-coordinates go from bottom to top

    lastX = xpos;
    lastY = ypos;


    camera.ProcessMouseMovement(xoffset, yoffset);
}

// glfw: whenever the mouse scroll wheel scrolls, this callback is called
// ----------------------------------------------------------------------
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
        double x = camera.Position.x;
        double y = camera.Position.y;
        double z = camera.Position.z;
        double yaw = camera.Yaw;
        double pitch = camera.Pitch;

        printf("Pos: (%f, %f, %f), POV: (%f, %f)\n", x, y, z, yaw, pitch);
    }

    /*
    if (key == GLFW_KEY_1 && action == GLFW_PRESS)
    {
        camera.Position = glm::vec3(-1.70f, 7.44f, -7.60f);
        camera.Yaw = 111.90;
        camera.Pitch = -6.60;
        camera.ProcessMouseMovement(0, 0);
    }
    if (key == GLFW_KEY_2 && action == GLFW_PRESS)
    {
        camera.Position = glm::vec3(-10.09f, 7.89f, -6.09f);
        camera.Yaw = -40.60;
        camera.Pitch = 33.30;
        camera.ProcessMouseMovement(0, 0);
    }
    */
}

void changeViewpoint(int view)
{
    if (view == 1)
    {
        camera.Position = glm::vec3(-35.0f, 10.0f, 0.0f);
        camera.Yaw = -360.0f;
        camera.Pitch = -0.5f;
        camera.ProcessMouseMovement(0, 0);
    }
    if (view == 2)
    {
        camera.Position = glm::vec3(-1.70f, 7.44f, -7.60f);
        camera.Yaw = 111.90;
        camera.Pitch = -6.60;
        camera.ProcessMouseMovement(0, 0);
    }
    if (view == 3)
    {
        camera.Position = glm::vec3(-10.09f, 7.89f, -6.09f);
        camera.Yaw = -40.60;
        camera.Pitch = 33.30;
        camera.ProcessMouseMovement(0, 0);
    }
}
#include "UIPanel.h"

#include <learnopengl/camera.h>

void renderUIPanel(std::ofstream& outputFile)
{
    ImGui::SetNextWindowSize(ImVec2(200, 550), 0);
    ImGui::Begin("Control Panel", NULL, ImGuiWindowFlags_NoMove);

    /* ----- Frame Counter ----- */
    ImGui::SeparatorText("Frame Counter");
    ImGui::TextColored(ImVec4(1, 1, 0, 1), frameDisplay.c_str());

    /* ----- Anti Aliasing ----- */
    ImGui::SeparatorText("Anti Aliasing");
    if (ImGui::Checkbox("AA On", &antiAliasing))
    {
        switch (currentAA %= 4)
        {
        case 0: msaa = true; break;
        case 1: fxaa = true; break;
        case 2: smaa = true; break;
        }
        if (wasTAAOn)
            taa = true;
    }

    if (ImGui::BeginTable("split", 2))
    {
        ImGui::TableNextColumn();
        ImGui::TableNextRow();
        ImGui::TableNextColumn();
        if (ImGui::RadioButton("MSAA", &currentAA, 0)) 
        {
            msaa = true; fxaa = smaa = false;
            outputFile << "AA Method : MSAA " << std::endl;
        }
        ImGui::TableNextColumn();
        if (ImGui::RadioButton("FXAA", &currentAA, 1)) 
        {
            fxaa = true; smaa = msaa = false;
            outputFile << "AA Method : FXAA " << std::endl;
        }
        ImGui::TableNextRow();
        ImGui::TableNextColumn();
        if (ImGui::RadioButton("SMAA", &currentAA, 2)) 
        {
            smaa = true; fxaa = msaa = false;
            outputFile << "AA Method : SMAA " << std::endl;
        }
        ImGui::EndTable();
    }

    /* ----- Temporal AA ----- */
    ImGui::SeparatorText("Temporal AA");
    if (ImGui::Checkbox("TAA", &taa))
    {
        if (taa) 
        {
            wasTAAOn = true;
        }
        else 
        {
            wasTAAOn = false;
            temporalAAFirstFrame = true;
        }
        outputFile << "AA Method : TAA " << std::endl;
        if (msaa) outputFile << "AA Method : MSAA + TAA " << std::endl;
        if (fxaa) outputFile << "AA Method : FXAA + TAA" << std::endl;
        if (smaa) outputFile << "AA Method : SMAA + TAA" << std::endl;
    }

    // AA Off �� ��� �ɼ� ����
    if (!antiAliasing)
    {
        currentAA += 4;
        msaa = fxaa = smaa = taa = false;
    }

    /* ----- MSAA Quality ----- */
    const char* msaaQualities[] = { "1X", "2X", "4X", "8X", "16X" };
    ImGui::SeparatorText("MSAA Quality");
    ImGui::Combo("##MSAA Quality", &currentMSAAQuality, msaaQualities, IM_ARRAYSIZE(msaaQualities));

    if (currentMSAAQuality != previousMSAAQuailty)
    {
        switch (currentMSAAQuality)
        {
        case 0: msaaQualityLevel = 0; outputFile << "MSAA 1X " << std::endl; break;
        case 1: msaaQualityLevel = 1; outputFile << "MSAA 2X " << std::endl; break;
        case 2: msaaQualityLevel = 2; outputFile << "MSAA 4X " << std::endl; break;
        case 3: msaaQualityLevel = 3; outputFile << "MSAA 8X " << std::endl; break;
        case 4: msaaQualityLevel = 4; outputFile << "MSAA 16X " << std::endl; break;
        }
        previousMSAAQuailty = currentMSAAQuality;
    }

    if (msaa)
    {
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, fbManager.multiSamplingTex);
        glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE,
            msaaSamples[msaaQualityLevel], GL_RGB,
            SCR_WIDTH, SCR_HEIGHT, GL_TRUE);
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);

        glBindRenderbuffer(GL_RENDERBUFFER, fbManager.multiSampledRBO);
        glRenderbufferStorageMultisample(GL_RENDERBUFFER,
            msaaSamples[msaaQualityLevel],
            GL_DEPTH24_STENCIL8,
            SCR_WIDTH, SCR_HEIGHT);
        glBindRenderbuffer(GL_RENDERBUFFER, 0);
    }

    /* ----- SMAA Quality ----- */
    const char* smaaQualities[] = { "LOW", "MEDIUM", "HIGH", "ULTRA" };
    ImGui::SeparatorText("SMAA Quality");
    ImGui::Combo("##SMAA Quality", &currentSMAAQuality, smaaQualities, IM_ARRAYSIZE(smaaQualities));

    if (currentSMAAQuality != previousSMAAQuality)
    {
        switch (currentSMAAQuality)
        {
        case 0: smaaPreset = 0; outputFile << "SMAA LOW " << std::endl; break;
        case 1: smaaPreset = 1; outputFile << "SMAA MEDIUM " << std::endl; break;
        case 2: smaaPreset = 2; outputFile << "SMAA HIGH " << std::endl; break;
        case 3: smaaPreset = 3; outputFile << "SMAA ULTRA " << std::endl; break;
        }
        previousSMAAQuality = currentSMAAQuality;
    }

    /* ----- Change Viewpoint ----- */
    ImGui::SeparatorText("Viewpoint");
    if (ImGui::Button("1")) changeViewpoint(1);
    ImGui::SameLine();
    if (ImGui::Button("2")) changeViewpoint(2);
    ImGui::SameLine();
    if (ImGui::Button("3")) changeViewpoint(3);

    /* ----- Change Scene ----- */
    const char* scenes[] = { "Container", "Sponza", "Image" };
    static int currentScene = 0;
    static int previousScene = 3;
    ImGui::SeparatorText("Scene");
    ImGui::Combo("Scene", &currentScene, scenes, IM_ARRAYSIZE(scenes));

    if (currentScene != previousScene)
    {
        switch (currentScene)
        {
        case 0:
            isImage = false;
            changeViewpoint(1);
            currentModel = container;
            outputFile << "Current Scene : Container " << std::endl;
            break;
        case 1:
            isImage = false;
            changeViewpoint(1);
            currentModel = sponza;
            outputFile << "Current Scene : Sponza " << std::endl;
            break;
        case 2:
            isImage = true;
            camera.Position = glm::vec3(-0.122459f, 0.039916f, 5.372975f);
            camera.Yaw = -89.200050f;
            camera.Pitch = -0.900008f;
            camera.ProcessMouseMovement(0, 0);
            outputFile << "Current Scene : Image " << std::endl;
            break;
        }
        previousScene = currentScene;
    }

    /* ----- Detail Screen ----- */
    ImGui::SeparatorText("Detail Screen");
    ImGui::Checkbox("Show", &detailScreen);

    /* ----- Benchmarking ----- */
    bool benchActive = false;
    ImGui::NewLine();
    if (ImGui::Button("Benchmark(10s)"))
    {
        benchActive = true;
        std::thread timeCheckerThread(timeChecker, std::ref(outputFile), std::ref(benchActive));
        timeCheckerThread.detach();
    }

    /* ----- Exit ----- */
    ImGui::NewLine();
    if (ImGui::Button("Exit"))
        glfwSetWindowShouldClose(window, true);

    ImGui::End();
}
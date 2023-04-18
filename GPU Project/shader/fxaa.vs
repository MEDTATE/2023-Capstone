#version 330 core

#include <shaderDefines.h>
#include <shaderUtils.h>

#define FXAA_PC 1
#define FXAA_GLSL_130 1

layout (location = 1) in vec3 aPos;
layout (location = 2) in vec3 aNormal;
layout (location = 3) in vec2 aTexCoords;

layout (location = 0) out vec2 texcoord;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main()
{
    texcoord = aTexCoords;
    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
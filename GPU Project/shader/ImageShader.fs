#version 330 core
out vec4 FragColor;

in vec2 TexCoord;

uniform sampler2D textureImage; // 텍스처 유닛

void main()
{
    FragColor = texture(textureImage, TexCoord); // 텍스처를 샘플하여 색상을 결정
}
#version 330 core
out vec4 FragColor;

in vec2 TexCoord;

uniform sampler2D textureImage; // �ؽ�ó ����

void main()
{
    FragColor = texture(textureImage, TexCoord); // �ؽ�ó�� �����Ͽ� ������ ����
}
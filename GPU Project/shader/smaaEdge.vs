/*
Copyright (c) 2015-2022 Alternative Games Ltd / Turo Lamminen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/


#version 450 core

uniform vec4 screenSize;

#define SMAA_RT_METRICS screenSize
#define SMAA_GLSL_4 1

#define SMAA_INCLUDE_PS 0
#define SMAA_INCLUDE_VS 1

#define API_V_DIR(v) -(v)

#define mad(a, b, c) (a * b + c)

void SMAAEdgeDetectionVS(vec2 texcoord,
                         out vec4 offset[3]) {
    offset[0] = mad(SMAA_RT_METRICS.xyxy, vec4(-1.0, 0.0, 0.0, API_V_DIR(-1.0)), texcoord.xyxy);
    offset[1] = mad(SMAA_RT_METRICS.xyxy, vec4( 1.0, 0.0, 0.0, API_V_DIR(1.0)), texcoord.xyxy);
    offset[2] = mad(SMAA_RT_METRICS.xyxy, vec4(-2.0, 0.0, 0.0, API_V_DIR(-2.0)), texcoord.xyxy);
}

vec2 triangleVertex(in int vertID, out vec2 texcoord)
{
    vec2 position;

    texcoord.x = (vertID == 2) ?  2.0 :  0.0;
    texcoord.y = (vertID == 1) ?  2.0 :  0.0;

		position = texcoord * vec2(2.0, 2.0) + vec2(-1.0, -1.0);

    return position;
} 


out vec2 texcoord;
out vec4 offset0;
out vec4 offset1;
out vec4 offset2;


void main(void)
{
    vec2 pos = triangleVertex(gl_VertexID, texcoord);

    vec4 offsets[3];
    offsets[0] = vec4(0.0, 0.0, 0.0, 0.0);
    offsets[1] = vec4(0.0, 0.0, 0.0, 0.0);
    offsets[2] = vec4(0.0, 0.0, 0.0, 0.0);
    SMAAEdgeDetectionVS(texcoord, offsets);
    offset0 = offsets[0];
    offset1 = offsets[1];
    offset2 = offsets[2];
    gl_Position = vec4(pos, 1.0, 1.0);
}
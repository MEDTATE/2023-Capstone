#version 330 core

//#include "PostProcessingCMAA_Common.glsl"

layout(location = 0) out vec4 OutColor;
layout(early_fragment_tests) in;

void main()
{
    uint packedEdges;
    uint shapeType;
    UnpackBlurAAInfo(textureLod(g_src0TextureFlt, ivec2(gl_FragCoord.xy), 0).r, packedEdges, shapeType);
    vec4 edges = vec4(UnpackEdge(packedEdges));

    bool showShapes = true;

    if (!showShapes)
    {
        float alpha = clamp(dot(edges, vec4(1, 1, 1, 1)) * 255.5, 0.0, 1.0);

        edges.rgb *= 0.8;
        edges.rgb += edges.aaa * vec3(15 / 255.0, 31 / 255.0, 63 / 255.0);

        OutColor = vec4(edges.rgb, alpha);
    }
    else
    {
        if (any(greaterThan(edges, vec4(0))))
        {
            OutColor = vec4(c_edgeDebugColours[shapeType].xyz, 0.8);
            if (shapeType == 0)
                OutColor.a = 0.4;
        }
    }
}

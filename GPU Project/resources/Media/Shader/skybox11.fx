//--------------------------------------------------------------------------------------
// Copyright 2012 Intel Corporation
// All Rights Reserved
//
// Permission is granted to use, copy, distribute and prepare derivative works of this
// software for any purpose and without fee, provided, that the above copyright notice
// and this statement appear in all copies.  Intel makes no representations about the
// suitability of this software for any purpose.  THIS SOFTWARE IS PROVIDED "AS IS."
// INTEL SPECIFICALLY DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, AND ALL LIABILITY,
// INCLUDING CONSEQUENTIAL AND OTHER INDIRECT DAMAGES, FOR THE USE OF THIS SOFTWARE,
// INCLUDING LIABILITY FOR INFRINGEMENT OF ANY PROPRIETARY RIGHTS, AND INCLUDING THE
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  Intel does not
// assume any responsibility for any errors which may appear in this software nor any
// responsibility to update it.
//--------------------------------------------------------------------------------------

#include "..\..\..\CPUT\CPUT\CPUTGlobalShaderInclude.fx"

// -------------------------------------
cbuffer cbPerModelValues
{
    row_major float4x4 World : WORLD;
    row_major float4x4 WorldViewProjection : WORLDVIEWPROJECTION;
    row_major float4x4 InverseWorld : INVERSEWORLD;
              float3   LightDirection  : Direction < string UIName = "Light Direction";  string Object = "TargetLight"; int Ref_ID=0; >;
              float4   EyePosition;
    row_major float4x4 LightWorldViewProjection;
};

struct VS_INPUT
{
    float3 Pos     : POSITION;
    float2 Uv      : TEXCOORD0;
};

struct PS_INPUT
{
    float4 Pos : SV_POSITION;
    float3 Tex : TEXCOORD0;
};


// -------------------------------------
SamplerState SAMPLER0 : register( s0 );
TextureCube texture_EM : register( t0 );


VS_INPUT VSMain( VS_INPUT Input )
{
    VS_INPUT Output;
    
    Output.Pos = Input.Pos;
    Output.Uv   = Input.Uv;
//    float4 viewSpacePosition = float4(Input.Position.xy, 1.0f, 0.0f);
 //   viewSpacePosition.xy /= Projection._m00_m11;
  //  Output.Tex = mul(viewSpacePosition, InverseView).xzy;
   
    return Output;
}

[MaxVertexCount(4)] 
void GSMain( point VS_INPUT input[1], inout TriangleStream<PS_INPUT> TriStream )
{
    PS_INPUT Verts[4];
	float4 viewSpacePosition;

    Verts[0].Pos    = float4(input[0].Pos.x, input[0].Pos.y, 0.5, 1.0);
    viewSpacePosition = float4(Verts[0].Pos.xy, 1.0f, 0.0f);
    viewSpacePosition.xy /= Projection._m00_m11;
    Verts[0].Tex = mul(viewSpacePosition, InverseView).xzy;

    Verts[1].Pos    = float4(input[0].Pos.x, input[0].Pos.y-input[0].Uv.y, 0.5, 1.0);
    viewSpacePosition = float4(Verts[1].Pos.xy, 1.0f, 0.0f);
    viewSpacePosition.xy /= Projection._m00_m11;
    Verts[1].Tex = mul(viewSpacePosition, InverseView).xzy;
        
    Verts[2].Pos    = float4(input[0].Pos.x+input[0].Uv.x, input[0].Pos.y, 0.5, 1.0);
    viewSpacePosition = float4(Verts[2].Pos.xy, 1.0f, 0.0f);
    viewSpacePosition.xy /= Projection._m00_m11;
    Verts[2].Tex = mul(viewSpacePosition, InverseView).xzy;
    
    Verts[3].Pos    = float4(input[0].Pos.x+input[0].Uv.x, input[0].Pos.y-input[0].Uv.y, 0.5, 1.0);
    viewSpacePosition = float4(Verts[3].Pos.xy, 1.0f, 0.0f);
    viewSpacePosition.xy /= Projection._m00_m11;
    Verts[3].Tex = mul(viewSpacePosition, InverseView).xzy;

    for(int i = 0; i < 4; ++i)
    {
        TriStream.Append(Verts[i]);
    }

    TriStream.RestartStrip();
}

float4 PSMain( PS_INPUT Input ) : SV_TARGET
{
    float4 color = texture_EM.Sample( SAMPLER0, Input.Tex);
	//color.rgb = 1;
	//color.rgb+=Input.Tex;
	//color.rgb*= 0.5; 
    return color * HDRScaleFactor;
}

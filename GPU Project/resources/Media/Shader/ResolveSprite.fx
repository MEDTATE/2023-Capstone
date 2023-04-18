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

// ********************************************************************************************************
struct VS_INPUT
{
    float3 Pos     : POSITION;
    float2 Uv      : TEXCOORD0;
};
struct PS_INPUT
{
    float4 Pos     : SV_POSITION;
    float2 Uv      : TEXCOORD0;
};
// ********************************************************************************************************
Texture2D    TEXTURE0 : register( t0 );
SamplerState SAMPLER0 : register( s0 );

// ********************************************************************************************************
VS_INPUT VSMain( VS_INPUT input )
{
    VS_INPUT output;
    output.Pos  = input.Pos;
    output.Uv   = input.Uv;
    return output;
}

[MaxVertexCount(4)] 
void GSMain( point VS_INPUT input[1], inout TriangleStream<PS_INPUT> TriStream )
{
    PS_INPUT Verts[4];

    Verts[0].Pos    = float4(input[0].Pos.x, input[0].Pos.y, 0.5, 1.0);
    Verts[0].Uv = float2(0.0, 0.0); 

    Verts[1].Pos    = float4(input[0].Pos.x, input[0].Pos.y-input[0].Uv.y, 0.5, 1.0);
    Verts[1].Uv = float2(0.0, 1.0);
        
    Verts[2].Pos    = float4(input[0].Pos.x+input[0].Uv.x, input[0].Pos.y, 0.5, 1.0);
    Verts[2].Uv = float2(1.0, 0.0);
    
    Verts[3].Pos    = float4(input[0].Pos.x+input[0].Uv.x, input[0].Pos.y-input[0].Uv.y, 0.5, 1.0);
    Verts[3].Uv = float2(1.0, 1.0);

    for(int i = 0; i < 4; ++i)
    {
        TriStream.Append(Verts[i]);
    }

    TriStream.RestartStrip();
}

// ********************************************************************************************************
float4 PSMain( PS_INPUT input ) : SV_Target
{
//	return float4(1,1,0,1);
    return TEXTURE0.Sample( SAMPLER0, input.Uv);
}

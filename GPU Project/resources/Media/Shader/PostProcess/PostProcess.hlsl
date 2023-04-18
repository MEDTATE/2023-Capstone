
//--------------------------------------------------------------------------------------
Texture2D    TEXTURE0 : register( t0 );
Texture2D    TEXTURE1 : register( t1 );
Texture2D    TEXTURE2 : register( t2 );
SamplerState SAMPLER0 : register( s0 );
SamplerState SAMPLER1 : register( s1 );

Texture2DMS <float4, 2> TEXTURE1_2xMSAA : register( t1 );
Texture2DMS <float4, 4> TEXTURE1_4xMSAA : register( t1 );

cbuffer cbPostProcessValues 
{
	float  middleGrey;
	float  bloomThreshold;
	float  bloomAmount;
	float  whitePointSquared;
	float  frameTime;
	float  ExposureAdaptSpeed;

	float2 padding2;
};

#define RGB_TO_LUMINANCE float3(0.212671, 0.715160, 0.072169)

//--------------------------------------------------------------------------------------
struct VS_OUTPUT10
{
    float4 Position : SV_POSITION;
    float2 Uv : TEXCOORD0;
};

VS_OUTPUT10 VSMain( VS_OUTPUT10 input )
{
    VS_OUTPUT10 output;
    output.Position  = input.Position;
    output.Uv   = input.Uv;
    return output;
}

[MaxVertexCount(4)] 
void GSMain( point VS_OUTPUT10 input[1], inout TriangleStream<VS_OUTPUT10> TriStream )
{
    VS_OUTPUT10 Verts[4];

    Verts[0].Position    = float4(input[0].Position.x, input[0].Position.y, 0.5, 1.0);
    Verts[0].Uv = float2(0.0, 0.0); 

    Verts[1].Position    = float4(input[0].Position.x, input[0].Position.y-input[0].Uv.y, 0.5, 1.0);
    Verts[1].Uv = float2(0.0, 1.0);
        
    Verts[2].Position    = float4(input[0].Position.x+input[0].Uv.x, input[0].Position.y, 0.5, 1.0);
    Verts[2].Uv = float2(1.0, 0.0);
    
    Verts[3].Position    = float4(input[0].Position.x+input[0].Uv.x, input[0].Position.y-input[0].Uv.y, 0.5, 1.0);
    Verts[3].Uv = float2(1.0, 1.0);

    for(int i = 0; i < 4; ++i)
    {
        TriStream.Append(Verts[i]);
    }

    TriStream.RestartStrip();
}

//--------------------------------------------------------------------------------------
float4 DownSample4x4PS( VS_OUTPUT10 In ) : SV_Target
{
    // Compute the average of an 4x4 pixel block by sampling 2x2 bilinear-filtered samples.
    float4 color = 
    (
          TEXTURE0.Sample( SAMPLER0, In.Uv, int2(0, 0) )
       +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(2, 0) )
       +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(0,-2) )
       +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(2,-2) )
    )
    * (1.0f/4.0f);
    return color;
}

// Scales input colors by thresholded luminance values.
// ------------------------------------------------------------------------------------------------
float4 PS_BrightPass(float4 position: SV_POSITION, float2 texCoords : TEXCOORD0) : SV_TARGET
{
	float4 color = TEXTURE0.Sample(SAMPLER0, texCoords);
	return color * max(dot(RGB_TO_LUMINANCE, color.rgb) - bloomThreshold, 0) * bloomAmount;
}

//--------------------------------------------------------------------------------------
float PS_AverageLogLum_Adapt( VS_OUTPUT10 In ) : SV_Target
{
    // Compute the average of an 4x4 pixel block by sampling 2x2 bilinear-filtered samples.
    float color = 
    (
          TEXTURE0.Sample( SAMPLER0, In.Uv, int2(0, 0) ).r
       +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(2, 0) ).r
       +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(0,-2) ).r
       +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(2,-2) ).r
    )
    * (1.0f/4.0f);

	float expC = exp(color.r);
	float L_measured = middleGrey/expC;

	float L_adapted  = TEXTURE1.Sample(SAMPLER0, float2(0.5, 0.5)).r;
	return L_adapted + (L_measured - L_adapted) * (1 - exp(-frameTime * ExposureAdaptSpeed));
}

//--------------------------------------------------------------------------------------
float4 BlurHorizontalPS( VS_OUTPUT10 In ) : SV_Target
{
    float gWeights[5] = {    
        0.28525234,
        0.221024189,
        0.102818575,
        0.028716039,
        0.004815026
    };

    // Compute a 17-tap gaussian blur using 9 bilinear samples.
    float4 color = 
          gWeights[0] *  TEXTURE0.Sample( SAMPLER1, In.Uv, int2( 0, 0) ) // use point-sampling for center sample
        + gWeights[1] * (TEXTURE0.Sample( SAMPLER0, In.Uv, int2(-1, 0) )
                      +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(+1, 0) ))
        + gWeights[2] * (TEXTURE0.Sample( SAMPLER0, In.Uv, int2(-2, 0) )
                      +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(+2, 0) ))
        + gWeights[3] * (TEXTURE0.Sample( SAMPLER0, In.Uv, int2(-3, 0) )
                      +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(+3, 0) ))
        + gWeights[4] * (TEXTURE0.Sample( SAMPLER0, In.Uv, int2(-4, 0) )
                      +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(+4, 0) ));
    return color;
}


//--------------------------------------------------------------------------------------
float4 BlurVerticalPS( VS_OUTPUT10 In ) : SV_Target
{
    float gWeights[5] = {    
        0.28525234,
        0.221024189,
        0.102818575,
        0.028716039,
        0.004815026
    };

    // Compute a 17-tap gaussian blur using 9 bilinear samples.
    float4 color = 
          gWeights[0] *  TEXTURE0.Sample( SAMPLER1, In.Uv, int2(0, 0) ) // use point-sampling for center sample
        + gWeights[1] * (TEXTURE0.Sample( SAMPLER0, In.Uv, int2(0,-1) )
                      +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(0,+1) ))
        + gWeights[2] * (TEXTURE0.Sample( SAMPLER0, In.Uv, int2(0,-2) )
                      +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(0,+2) ))
        + gWeights[3] * (TEXTURE0.Sample( SAMPLER0, In.Uv, int2(0,-3) )
                      +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(0,+3) ))
        + gWeights[4] * (TEXTURE0.Sample( SAMPLER0, In.Uv, int2(0,-4) )
                      +  TEXTURE0.Sample( SAMPLER0, In.Uv, int2(0,+4) ));
    return color;
}

//--------------------------------------------------------------------------------------
float4 DownSampleLogLumPS( VS_OUTPUT10 In ) : SV_Target
{
    float4 color = TEXTURE0.Sample( SAMPLER0, In.Uv );
    
    // Compute luminance
    float luminance = max(dot(RGB_TO_LUMINANCE, color.rgb), 0);
    
    // Return the log(luminance+epsilon)
    float result = log(luminance + 0.001); // avoid log(0)

    return float4(result.xxx, 1);
}

float4 ToneMap( float4 C_scene, float L_scene )
{
    float  L_pixel = dot(RGB_TO_LUMINANCE, C_scene.rgb);
	float  L_xy    = L_scene * L_pixel;
	float  L_d     = L_xy * (1 + L_xy / whitePointSquared) / (1 + L_xy);
	float  scale   = L_d / L_pixel;
	return float4(C_scene.rgb * scale, C_scene.a);
}

//--------------------------------------------------------------------------------------
float4 CompositePS( VS_OUTPUT10 In ) : SV_Target
{
    float3 C_scene = TEXTURE1.Sample( SAMPLER1, In.Uv ).rgb;
    float L_scene = TEXTURE2.Sample(SAMPLER0, float2(0,0) ).r;
	float4 C_bloom = TEXTURE0.Sample(SAMPLER0, In.Uv );

	
	float  L_pixel = dot(RGB_TO_LUMINANCE, C_scene + C_bloom.rgb);
	float  L_xy    = L_scene * L_pixel;
	float  L_d     = L_xy * (1 + L_xy / whitePointSquared) / (1 + L_xy);
	float  scale   = L_d /  L_pixel;
	return float4(C_scene * scale, 1) + C_bloom;
}

//--------------------------------------------------------------------------------------
float4 CompositePS_2xMSAA( VS_OUTPUT10 In ) : SV_Target
{
    int3 pixPos = int3( (int2)In.Position.xy, 0 );

    float L_scene = TEXTURE2.Sample(SAMPLER0, float2(0,0) ).r;
	float4 C_bloom = TEXTURE0.Sample(SAMPLER0, In.Uv );

    float3 ret = float3( 0, 0, 0 );
    for( int i = 0; i < 2; i++ )
    {
        float3 C_scene = TEXTURE1_2xMSAA.Load( pixPos.xy, i ).rgb;
	    float  L_pixel = dot(RGB_TO_LUMINANCE, C_scene + C_bloom.rgb);
	    float  L_xy    = L_scene * L_pixel;
	    float  L_d     = L_xy * (1 + L_xy / whitePointSquared) / (1 + L_xy);
	    float  scale   = L_d /  L_pixel;
	    ret += pow( float3(C_scene * scale) + C_bloom, 0.454545 );
    }
    return float4( pow(ret / 2.0, 2.2 ), 1 );
}

//--------------------------------------------------------------------------------------
float4 CompositePS_4xMSAA( VS_OUTPUT10 In ) : SV_Target
{
    int3 pixPos = int3( (int2)In.Position.xy, 0 );

    float L_scene = TEXTURE2.Sample(SAMPLER0, float2(0,0) ).r;
	float4 C_bloom = TEXTURE0.Sample(SAMPLER0, In.Uv );

    float3 ret = float3( 0, 0, 0 );
    for( int i = 0; i < 4; i++ )
    {
        float3 C_scene = TEXTURE1_4xMSAA.Load( pixPos.xy, i ).rgb;
	    float  L_pixel = dot(RGB_TO_LUMINANCE, C_scene + C_bloom.rgb);
	    float  L_xy    = L_scene * L_pixel;
	    float  L_d     = L_xy * (1 + L_xy / whitePointSquared) / (1 + L_xy);
	    float  scale   = L_d /  L_pixel;
	    ret += pow( float3(C_scene * scale) + C_bloom, 0.454545 );
    }
    return float4( pow(ret / 4.0, 2.2 ), 1 );
}


//--------------------------------------------------------------------------------------
float4 CompositeBasic( VS_OUTPUT10 In ) : SV_Target
{
    float4 C_scene = TEXTURE0.Sample( SAMPLER1, In.Uv );
	return C_scene;
}

//--------------------------------------------------------------------------------------
float4 CompositeBloomPS( VS_OUTPUT10 In ) : SV_Target
{
    float4 C_scene = TEXTURE1.Sample( SAMPLER1, In.Uv );
	float4 C_bloom = TEXTURE0.Sample(SAMPLER0, In.Uv );

	return C_scene + C_bloom;
}

//--------------------------------------------------------------------------------------
float4 CompositeTonePS( VS_OUTPUT10 In ) : SV_Target
{

    float3 C_scene = TEXTURE0.Sample( SAMPLER1, In.Uv ).rgb;
    float L_scene = TEXTURE1.Sample( SAMPLER0, float2(0,0) ).r;

	float  L_pixel = dot(RGB_TO_LUMINANCE, C_scene);
	float  L_xy    = L_scene * L_pixel;
	float  L_d     = L_xy * (1 + L_xy / whitePointSquared) / (1 + L_xy);
	float  scale   = L_d / L_pixel;
	return float4(C_scene * scale, 1);
}


//--------------------------------------------------------------------------------------
float4 DebugBloomPS( VS_OUTPUT10 In ) : SV_Target
{
	float4 C_bloom = TEXTURE0.Sample(SAMPLER0, In.Uv );

	return C_bloom;
}


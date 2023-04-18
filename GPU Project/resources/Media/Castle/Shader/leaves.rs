
[DepthStencilStateDX11]
DepthEnable = true

[RasterizerStateDX11]
CullMode = D3D11_CULL_NONE

[SamplerDX11_1]

[SamplerDX11_2]
ComparisonFunc = D3D11_COMPARISON_GREATER_EQUAL
Filter = D3D11_FILTER_COMPARISON_MIN_MAG_LINEAR_MIP_POINT

[BlendStateDX11]
AlphaToCoverageEnable = true

[RenderTargetBlendStateDX11_1] 
BlendEnable = false
SrcBlend = D3D11_BLEND_SRC_ALPHA 
DestBlend = D3D11_BLEND_INV_SRC_ALPHA 
BlendOp = D3D11_BLEND_OP_ADD

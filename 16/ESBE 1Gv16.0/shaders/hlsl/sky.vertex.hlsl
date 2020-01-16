#include "ShaderConstants.fxh"

struct VS_Input
{
	float3 position : POSITION;
	float4 color : COLOR;

#ifdef INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
};


struct PS_Input
{
	float4 position : SV_Position;
	float4 color : COLOR;
	float3 pos : ESBECloud;
	float sky : ESBESky;

	#ifdef GEOMETRY_INSTANCEDSTEREO
		uint instanceID : SV_InstanceID;
	#endif
	#ifdef VERTEXSHADER_INSTANCEDSTEREO
		uint renTarget_id : SV_RenderTargetArrayIndex;
	#endif
};


void main( in VS_Input VSInput, out PS_Input PSInput )
{
float4 pos = float4(VSInput.position, 1);
pos.y -= length(pos.xyz)*.2;
#ifdef INSTANCEDSTEREO
	int i = VSInput.instanceID;
	PSInput.position = mul( WORLDVIEWPROJ_STEREO[i], pos);
	PSInput.instanceID = i;
#else
	PSInput.position = mul(WORLDVIEWPROJ, pos);
#endif
#ifdef GEOMETRY_INSTANCEDSTEREO
	PSInput.instanceID = VSInput.instanceID;
#endif
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	PSInput.renTarget_id = VSInput.instanceID;
#endif

	PSInput.pos = VSInput.position.xyz;
	PSInput.sky = VSInput.color.r;
	PSInput.color = CURRENT_COLOR;
}

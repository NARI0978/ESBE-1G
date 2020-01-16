#include "ShaderConstants.fxh"
#include "ESBEutil.fxh"

struct VS_Input {
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD_0;
	float2 uv1 : TEXCOORD_1;
#ifdef INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
};


struct PS_Input {
	float4 position : SV_Position;
	float3 cPos : chunked_Pos;
	float3 wPos : wPos;
	float wf : WaterFlag;

#ifndef BYPASS_PIXEL_SHADER
	lpfloat4 color : COLOR;
	snorm float2 uv0 : TEXCOORD_0_FB_MSAA;
	snorm float2 uv1 : TEXCOORD_1_FB_MSAA;
#endif

#ifdef FOG
	float4 fogColor : FOG_COLOR;
#endif
#ifdef GEOMETRY_INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	uint renTarget_id : SV_RenderTargetArrayIndex;
#endif
};

static const float rA = 1.0;
static const float rB = 1.0;
static const float3 UNIT_Y = float3(0, 1, 0);
static const float DIST_DESATURATION = 56.0 / 255.0; //WARNING this value is also hardcoded in the water color, don'tchange

#ifdef WIND
float hash11(float p){
	float3 p3  = frac(p * 0.1031);
	p3 += dot(p3, p3.yzx + 19.19);
	return frac((p3.x + p3.y) * p3.z);
}
#endif

float random(float p){
	#ifdef WIND
		p = p/3.0+TIME;
		return lerp(hash11(floor(p)),hash11(floor(p+1.0)),smoothstep(0.0,1.0,frac(p)))*2.0;
	#else
		return 1.0;
	#endif
}


ROOT_SIGNATURE
void main(in VS_Input VSInput, out PS_Input PSInput)
{
PSInput.wf = 0.;
#ifndef BYPASS_PIXEL_SHADER
	PSInput.uv0 = VSInput.uv0;
	PSInput.uv1 = VSInput.uv1;
	PSInput.color = VSInput.color;
#endif

#ifdef AS_ENTITY_RENDERER
	#ifdef INSTANCEDSTEREO
		int i = VSInput.instanceID;
		PSInput.position = mul(WORLDVIEWPROJ_STEREO[i], float4(VSInput.position, 1));
	#else
		PSInput.position = mul(WORLDVIEWPROJ, float4(VSInput.position, 1));
	#endif
		float3 worldPos = PSInput.position;
#else
		float3 worldPos = (VSInput.position.xyz * CHUNK_ORIGIN_AND_SCALE.w) + CHUNK_ORIGIN_AND_SCALE.xyz;

		// Transform to view space before projection instead of all at once to avoid floating point errors
		// Not required for entities because they are already offset by camera translation before rendering
		// World position here is calculated above and can get huge
	#ifdef INSTANCEDSTEREO
		int i = VSInput.instanceID;

		PSInput.position = mul(WORLDVIEW_STEREO[i], float4(worldPos, 1 ));
		PSInput.position = mul(PROJ_STEREO[i], PSInput.position);

	#else
		PSInput.position = mul(WORLDVIEW, float4( worldPos, 1 ));
		PSInput.position = mul(PROJ, PSInput.position);
	#endif

#endif
#ifdef GEOMETRY_INSTANCEDSTEREO
		PSInput.instanceID = VSInput.instanceID;
#endif
#ifdef VERTEXSHADER_INSTANCEDSTEREO
		PSInput.renTarget_id = VSInput.instanceID;
#endif
///// find distance from the camera

#if defined(FOG) || defined(BLEND)
	#ifdef FANCY
		float3 relPos = -worldPos;
		float cameraDepth = length(relPos);
	#else
		float cameraDepth = PSInput.position.z;
	#endif
#endif

///// waves
#if defined ALPHA_TEST && defined(LEAVES_WAVES)
	if (PSInput.color.g != PSInput.color.b){
		float3 l = VSInput.position.xyz;
		l.y = abs(l.y-8.0);
		PSInput.position.x += sin(TIME * 3.5 + 2.0 * l.x + 2.0 * l.z + l.y) * 0.015 * random(l.x+l.y+l.z);
	}
#endif

#if !defined(BYPASS_PIXEL_SHADER) && !defined(ALPHA_TEST) && defined(BLEND)
	if (PSInput.color.g != PSInput.color.b){
		#ifdef WATER_WAVES
			float3 l = worldPos.xyz + VIEW_POS;
			PSInput.position.y += sin(TIME * 3.5 + 2.0 * l.x + 2.0 * l.z + l.y) * 0.04 * frac(VSInput.position.y) * random(l.x+l.y+l.z);
		#endif
		VSInput.color.a *= 0.5;
		PSInput.wf = 1.;
	}
#endif

	///// apply fog

#ifdef FOG
	float len = cameraDepth / RENDER_DISTANCE;
#ifdef ALLOW_FADE
	len += RENDER_CHUNK_FOG_ALPHA.r;
#endif

	PSInput.fogColor.rgb = FOG_COLOR.rgb;
	PSInput.fogColor.a = clamp((len - FOG_CONTROL.x) / (FOG_CONTROL.y - FOG_CONTROL.x), 0.0, 1.0);

#endif

///// blended layer (mostly water) magic
#ifdef BLEND
	//Mega hack: only things that become opaque are allowed to have vertex-driven transparency in the Blended layer...
	//to fix this we'd need to find more space for a flag in the vertex format. color.a is the only unused part
	if(VSInput.color.a < 0.95) {
		float cameraDist = cameraDepth / FAR_CHUNKS_DISTANCE;
		float alphaFadeOut = clamp(cameraDist, 0.0, 1.0);
		PSInput.color.a = lerp(VSInput.color.a, 1.0, alphaFadeOut);
	}
#endif
PSInput.cPos = VSInput.position;
PSInput.wPos = worldPos;
}

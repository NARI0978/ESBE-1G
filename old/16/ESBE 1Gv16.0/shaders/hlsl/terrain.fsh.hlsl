#include "ShaderConstants.fxh"
#include "util.fxh"
#include "ESBEutil.fxh"

struct PS_Input
{
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
};

struct PS_Output
{
	float4 color : SV_Target;
};


float filmic_curve(float x){
	float A = 0.20;									// Shoulder strength
	float B = 0.30;									// Linear strength
	float C = 0.15 * TM_BRIGHTNESS;		// Linear angle
	float D = 0.20 * TM_GAMMA;					// Toe strength
	float E = 0.02 * TM_CONTRAST;			// Toe numerator
	float F = 0.30;									// Toe denominator
	return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

float3 ESBEmapping(float3 clr){
	float W = 1.0 / TM_EXPOSURE;
	#ifdef ESBE_TONEMAP
		float Luma = dot(clr, float3(0.298912, 0.586611, 0.114478));
		float3 Chroma = clr - Luma;
		clr = (Chroma * TM_SATURATION) + Luma;
  	clr = float3(filmic_curve(clr.r), filmic_curve(clr.g), filmic_curve(clr.b)) / filmic_curve(W);
	#endif
	return clr;
}

float flat_shading(float3 pos, float dusk){
	dusk = dusk*0.75+0.25;
	float3 n = normalize(float3(cross(ddx(-pos),ddy(pos))));
	n.x = abs(n.x*lerp(1.5,0.8,dusk));
	n.yz = n.yz*0.5+0.5;
	n.yz *= lerp(float2(0.5,0.0),float2(1.0,1.0),dusk);
	return max(n.x,max(n.y,n.z));
}

#ifdef ESBE_WATER
float3 mod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
float2 mod289(float2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
float3 permute(float3 x) { return mod289(x*(x * 34.0 + 1.0)); }

float snoise(float2 v) {
	float4 C = float4(
		0.211324865405187,   // (3.0-sqrt(3.0))/6.0
		0.366025403784439,   // 0.5*(sqrt(3.0)-1.0)
		-0.577350269189626,  // -1.0 + 2.0 * C.x
		0.024390243902439);  // 1.0 / 41.0

	float2 i  = floor(v + dot(v, C.yy));
	float2 x0 = v -   i + dot(i, C.xx);
	float2 i1  = x0.x > x0.y ? float2(1.0, 0.0) : float2(0.0, 1.0);
	float4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;

	i = mod289(i);
	float3 p =permute(permute(i.y + float3(0.0, i1.y, 1.0)) + i.x + float3(0.0, i1.x, 1.0));

	float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
	m = m*m;
	m = m*m;

	float3 x  = 2.0 * frac(p * C.www) - 1.0;
	float3 h  = abs(x) - 0.5;
	float3 ox = round(x);
	float3 a0 = x - ox;

	m *= rsqrt(a0 * a0 + h * h);
	float3 g;
	g.x  = a0.x  * x0.x   + h.x  * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130.0 * dot(m, g);
}

float4 water(float4 col,float3 p,float3 look,float weather,float sun){
	sun = smoothstep(.5,.75,sun);
	float dist = smoothstep(100.,500.,(look.x*look.x+look.z*look.z)/max(1.,abs(look.y)));
	float gray = col.r+col.g+col.b;
	col.rgb = lerp(col.rgb,float3(gray,gray,gray),dist*.25);
	#ifdef C_REF
		col.rgb *= lerp(1.,snoise(float2(look.x-TIME,look.z)*.05)+.5,sun*((1.-dist)*.1+.1));
	#endif

	p.xz *= ESBE_WATER;
	p.xz += smoothstep(0.,8.,abs(p.y-8.))*.5;
	float n = (snoise(p.xz-TIME*.5)+snoise(float2(p.x-TIME,(p.z+TIME)*.5)))*.375+.25;
	float n2 = smoothstep(.5,1.,n);

	gray = col.r+col.g+col.b;
	float4 col2 = float4(lerp(col.rgb*1.2,float3(gray,gray,gray),.3),col.a*1.1);
	float4 col3 = lerp(col*1.1,float4(.8,.8,.9,.9),smoothstep(3.+abs(look.y)*.3,0.,abs(look.z))*sun*weather);

	return lerp(col,lerp(col2,col3,n2),n*((1.-dist)*.7+.3));
}
#endif

ROOT_SIGNATURE
void main(in PS_Input PSInput, out PS_Output PSOutput)
{
#ifdef BYPASS_PIXEL_SHADER
    PSOutput.color = float4(0.0f, 0.0f, 0.0f, 0.0f);
    return;
#else

#if USE_TEXEL_AA
	float4 diffuse = texture2D_AA(TEXTURE_0, TextureSampler0, PSInput.uv0 );
#else
	float4 diffuse = TEXTURE_0.Sample(TextureSampler0, PSInput.uv0);
#endif

#ifdef SEASONS_FAR
	diffuse.a = 1.0f;
#endif

#if USE_ALPHA_TEST
	#ifdef ALPHA_TO_COVERAGE
		#define ALPHA_THRESHOLD 0.05
	#else
		#define ALPHA_THRESHOLD 0.5
	#endif
	if(diffuse.a < ALPHA_THRESHOLD)
		discard;
#endif

#if defined(BLEND)
	diffuse.a *= PSInput.color.a;
#endif

#if !defined(ALWAYS_LIT)
	diffuse = diffuse * TEXTURE_1.Sample(TextureSampler1, PSInput.uv1);
#endif

#ifndef SEASONS
	#if !USE_ALPHA_TEST && !defined(BLEND)
		diffuse.a = PSInput.color.a;
	#endif

	diffuse.rgb *= PSInput.color.rgb;
#else
	float2 uv = PSInput.color.xy;
	diffuse.rgb *= lerp(1.0f, TEXTURE_2.Sample(TextureSampler2, uv).rgb*2.0f, PSInput.color.b);
	diffuse.rgb *= PSInput.color.aaa;
	diffuse.a = 1.0f;
#endif


//設定項目
float blur = 0.005;//影の境界(数が大きいほどぼやける)
float dusk1 = 0.25;//境界位置
float dusk2 = 0.25;//境界ブラー
//=*=-*-=*=


#ifdef FOG
	float weather = smoothstep(0.8,1.0,FOG_CONTROL.y);
#else
	float weather = 1.0;
#endif
float daylight = TEXTURE_1.Sample(TextureSampler1,float2(0.0, 1.0)).r;
float sunlight = smoothstep(0.87-blur,0.87+blur,PSInput.uv1.y);
float nolight = 1.0-PSInput.uv1.x;
float dusk = max(smoothstep(0.55,0.4,daylight),smoothstep(0.65,0.8,daylight));
float cosT = abs(dot(float3(0.,1.,0.),normalize(PSInput.wPos)));
float rend = smoothstep(.95,.9,length(PSInput.wPos)/FAR_CHUNKS_DISTANCE);
daylight *= weather;

#ifdef ESBE_LIGHT
	diffuse.rgb += ESBE_LIGHT*max(0.0,PSInput.uv1.x-0.5f)*lerp(1.0,smoothstep(1.0,0.8,PSInput.uv1.y)*0.5+0.5,daylight);
#endif

diffuse.rgb = ESBEmapping(diffuse.rgb);

#ifdef ESBE_SUN_LIGHT
diffuse.rgb += (float3(0.9,0.9,0.9)-diffuse.rgb)*diffuse.rgb*sunlight*daylight*ESBE_SUN_LIGHT;
#endif

#if defined(BLEND) && defined(ESBE_WATER)
	if(PSInput.wf > 0.0){
		diffuse = lerp(diffuse,water(diffuse,PSInput.cPos,PSInput.wPos,weather,PSInput.uv1.y),1.2-cosT);
	}
#endif

#ifdef ESBE_SHADOW
	float s_amount = lerp(0.45,0.0,sunlight);
	diffuse.rgb = lerp(diffuse.rgb,ESBE_SHADOW,s_amount*nolight*daylight);
#endif

#if !defined (ALPHA_TEST) && !defined(BLEND) && defined(ESBE_SIDE_SHADOW)
	float s_amount2 = lerp(0.45,0.0,smoothstep(0.5-blur*4.,0.5+blur*4.,PSInput.color.g));
	diffuse.rgb = lerp(diffuse.rgb,ESBE_SIDE_SHADOW,s_amount2*nolight*daylight*sunlight*rend);
#endif

#ifdef ESBE_FLAT_SHADING
	diffuse.rgb *= lerp(1.0,flat_shading(PSInput.cPos,dusk),smoothstep(0.7,0.95,PSInput.uv1.y)*min(1.25-PSInput.uv1.x,1.0)*daylight);
#endif

#if defined(ESBE_UNEVEN) && !defined(BLEND)
	if(PSInput.color.r<PSInput.color.g+PSInput.color.b){
		float t_br = smoothstep(2.,1.,length(diffuse.rgb));
		diffuse.rgb *= 1.+(.5-length(TEXTURE_0.Sample(TextureSampler0, PSInput.uv0-t_br*.00012).rgb/1.732))*t_br*ESBE_UNEVEN;
	}
#endif

#ifdef DUSK
	float dusk3 = DUSK*smoothstep(dusk1,dusk1+dusk2, PSInput.uv1.y)*weather;
	dusk = dusk*dusk3+(1.0-dusk3);
	diffuse.rgb *= float3(2.0-dusk,1.0,dusk);
#endif

#ifdef FOG
	diffuse.rgb = lerp( diffuse.rgb, PSInput.fogColor.rgb, PSInput.fogColor.a );
#endif

PSOutput.color = diffuse;

#ifdef VR_MODE
	// On Rift, the transition from 0 brightness to the lowest 8 bit value is abrupt, so clamp to
	// the lowest 8 bit value.
	PSOutput.color = max(PSOutput.color, 1 / 255.0f);
#endif

#endif // BYPASS_PIXEL_SHADER
}

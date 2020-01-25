#include "ShaderConstants.fxh"
#include "ESBEutil.fxh"

struct PS_Input
{
	float4 position : SV_Position;
	float4 color : COLOR;
	float3 pos : ESBECloud;
	float sky : ESBESky;
};
struct PS_Output
{
	float4 color : SV_Target;
};

#ifdef RENDERCLOUDS
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

float fBM(int octaves, float lowerBound, float upperBound, float2 st) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < octaves; i++) {
		value += amplitude * (snoise(st) * 0.5 + 0.5);
		if (value >= upperBound) {break;}
		else if (value + amplitude <= lowerBound) {break;}
		st        *= 2.0;
		st.x      -=TIME/256.0*float(i+1);
		amplitude *= 0.5;
	}
	return smoothstep(lowerBound, upperBound, value);
}
#endif

#ifdef RENDERAURORA
float tri(float x){return clamp(abs(frac(x)-.5),0.001,0.52);}
float triNoise2d(float2 p)
{
	float z=1.8;
	float z2=2.5;
	float rz = 0.;
	p *= 0.55*(p.x*0.2);
	float2 bp = p;
	for (float i=0.; i<5.; i++ )
	{
		p -= (bp*1.85)*4.5/z2;
		bp *= 1.3;
		z2 *= .45;
		z *= .42;
		p *= 1.21 + (rz-1.0)*.02;
		rz += tri(p.x+tri(p.y))*z;
		p*= -1.0;
	}
	return clamp(1./pow(rz*29., 1.3),0.,.55);
}
float4 aurora(float3 rd)
{
	float4 col = 0.0;
	float of = 0.006*frac(sin(0.96));
	float b = rd.y*2.+0.4;
	float3 c = sin(TIME*0.01)*0.5+1.5-float3(2.15,-.5, 1.2);
	for(float i=0.;i<RENDERAURORA;i++){
		float pt = (.8+pow(i+1.,AURORA_DS)*0.002)/b;
		float3 bpos = float3(0.0,0.0,-6.5) + (pt-of)*rd;
		float rzt = triNoise2d(bpos.zx);
		float4 col2 = float4(float3((sin(c+i*AURORA_CC)*0.5+0.5)*rzt),rzt)*.5;
		col += col2*exp2(-i*0.065 - 2.5)*smoothstep(0.,5., i);
	}
	return col*(clamp(rd.y*15.+.4,0.,1.))*AURORA_CS;
}
#endif

void main( in PS_Input PSInput, out PS_Output PSOutput )
{
float4 _color = PSInput.color;
float weather = smoothstep(0.8,1.0,FOG_CONTROL.y);
float ss = smoothstep(0.0,0.5,FOG_COLOR.r - FOG_COLOR.g);
_color = lerp(lerp(_color,FOG_COLOR,.33)+float4(0.0,0.03,0.05,0.0),FOG_COLOR*1.1,smoothstep(.1,.4,PSInput.sky));
float3 __color = _color.rgb;

#ifdef RENDERAURORA
	float night = smoothstep(0.4,0.2,PSInput.color.b);
	if(night*weather>0.0){
		float2 p = PSInput.pos.xz*4.0;
		float4 aur = smoothstep(0.,1.5,aurora(normalize(float3(p.x,1.0,p.y))));
		_color.rgb += aur.rgb*night*weather;
	}
#endif

#ifdef RENDERCLOUDS
	float day = smoothstep(0.15,0.25,FOG_COLOR.g);
	float3 cc = lerp(CLOUDS_NC,CLOUDS_DC,day);
	float3 cc2 = lerp(CLOUDS_NC*1.1,__color*float3(.8,.75,.6),day);
	float lb = lerp(0.25,0.5,weather);
	float cm = fBM(RENDERCLOUDS,lb,0.9,PSInput.pos.xz*3.5-TIME*0.001);
	#ifdef NEW_CS
		float cm2 = fBM(5,lb,1.,PSInput.pos.xz*3.4-TIME*0.001);
	#else
		float cm2 = max(cm-.5,0.);
	#endif
	_color.rgb = lerp(_color.rgb, cc, cm);
	_color.rgb = lerp(_color.rgb, lerp(cc2,CLOUDS_SC,ss), cm2);
#endif

	PSOutput.color = lerp(_color, FOG_COLOR,PSInput.sky );
}

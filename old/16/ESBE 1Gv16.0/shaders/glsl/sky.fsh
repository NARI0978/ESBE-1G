// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#if __VERSION__ >= 300
	// version 300 code
	#define varying in
	#define texture2D texture
	out vec4 FragColor;
	#define gl_FragColor FragColor
	#define texture2D texture
#else
	// version 100 code
#endif

#include "ESBEutil.h"

varying vec4 color;
varying vec4 fogcolor;
varying float fogintense;
varying highp vec3 position;

uniform highp float TIME;
uniform vec2 FOG_CONTROL;

#include "snoise.h"

highp float fBM(const int octaves, const float lowerBound, const float upperBound, highp vec2 st) {
	highp float value = 0.0;
	highp float amplitude = 0.5;
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


#ifdef RENDERAURORA
float tri(float x){return clamp(abs(fract(x)-.5),0.001,0.52);}

float triNoise2d(vec2 p)
{
	float z=1.8;
	float z2=2.5;
	float rz = 0.0;
	p *= 0.55*(p.x*0.2);
	vec2 bp = p;
	for (float i=0.0; i<5.0; i++ )
	{
		vec2 dg = (bp*1.85)*0.75;
		dg *= 6.0;
		p -= dg/z2;
		bp *= 1.3;
		z2 *= 0.45;
		z *= 0.42;
		p *= 1.21 + (rz-1.0)*0.02;
		rz += tri(p.x+tri(p.y))*z;
		p*= -1.0;
	}
	return clamp(1.0/pow(rz*29.0, 1.3),0.0,0.55);
}

vec4 aurora(vec3 rd)
{
	vec4 col = vec4(0.0);
	float of = 0.006*fract(sin(0.96));
	float b = rd.y*2.0+0.4;
	vec3 c = vec3(sin(TIME*0.01)*0.5+1.5-vec3(2.15,-0.5,1.2));
	for(float i=0.0;i<RENDERAURORA;i++)
	{
		float pt = (0.8+pow(i+1.0,AURORA_DS)*0.002)/b;
		vec3 bpos = vec3(0.0,0.0,-6.5) + (pt-of)*rd;
		float rzt = triNoise2d(bpos.zx);
		vec4 col2 = vec4(vec3((sin(c+i*AURORA_CC)*0.5+0.5)*rzt),rzt);
		col += col2*0.5*exp2(-i*0.065-2.5)*smoothstep(0.0,5.0,i);
	}
	return col*(clamp(rd.y*15.0+0.4,0.0,1.0))*AURORA_CS;
}
#endif

void main()
{
vec4 _color = color;
float weather = smoothstep(0.8,1.0,FOG_CONTROL.y);
float ss = smoothstep(0.0,0.5,fogcolor.r - fogcolor.g);
_color = mix(mix(_color,fogcolor,.33)+vec4(0.0,0.05,0.1,0.0),fogcolor*1.1,smoothstep(.1,.4,fogintense));
vec3 __color = _color.rgb;

#ifdef RENDERAURORA
	float night = smoothstep(0.4,0.2,color.b);
	if(night*weather>0.0){
		vec4 aur = vec4(smoothstep(0.0,1.5,aurora(normalize(vec3(position.x*4.0,1.0,position.z*4.0)))));
		_color.rgb += aur.rgb*night*weather;
	}
#endif

#ifdef RENDERCLOUDS
	float day = smoothstep(0.15,0.25,fogcolor.g);
	vec3 cc = mix(CLOUDS_NC,CLOUDS_DC,day);
	vec3 cc2 = mix(CLOUDS_NC*1.1,__color*vec3(1.,.9,.8),day);
	float lb = mix(0.1,0.5,weather);
	float cm = fBM(RENDERCLOUDS,lb,0.9,position.xz*3.5-TIME*0.001);
	#ifdef NEW_CS
		float cm2 = fBM(5,lb,1.,position.xz*3.4-TIME*0.001);
	#else
		float cm2 = max(cm-.5,0.);
	#endif
	_color.rgb = mix(_color.rgb, cc, cm);
	_color.rgb = mix(_color.rgb, mix(cc2,CLOUDS_SC,ss), cm2);
#endif

gl_FragColor = mix(_color, fogcolor, fogintense);
}

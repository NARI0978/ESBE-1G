// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "fragmentVersionCentroid.h"

#if __VERSION__ >= 300
	#ifndef BYPASS_PIXEL_SHADER
		#if defined(TEXEL_AA) && defined(TEXEL_AA_FEATURE)
			_centroid in highp vec2 uv0;
			_centroid in highp vec2 uv1;
		#else
			_centroid in vec2 uv0;
			_centroid in vec2 uv1;
		#endif
	#endif
#else
	#ifndef BYPASS_PIXEL_SHADER
		varying vec2 uv0;
		varying vec2 uv1;
	#endif
#endif

varying vec4 color;

#ifdef FOG
varying vec4 fogColor;
#endif

#ifdef GL_FRAGMENT_PRECISION_HIGH
	varying highp vec3 cPos;
#else
	varying mediump vec3 cPos;
#endif
varying POS3 wPos;
varying float wf;

#include "uniformShaderConstants.h"
#include "util.h"
#include "ESBEutil.h"
#include "snoise.h"
uniform vec2 FOG_CONTROL;
uniform float TIME;
uniform float FAR_CHUNKS_DISTANCE;

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;
LAYOUT_BINDING(1) uniform sampler2D TEXTURE_1;
LAYOUT_BINDING(2) uniform sampler2D TEXTURE_2;

float filmic_curve(float x) {
	float A = 0.48;								
	float B = 0.15;								
	float C = 0.50;
	float D = 0.65;
	float E = 0.05;
	float F = 0.20;								
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec3 ESBEmapping(vec3 clr) {
	#ifdef ESBE_TONEMAP
		float W = 1.4 / TM_EXPOSURE;
		float Luma = dot(clr, vec3(0.3, 0.6, 0.1));
		vec3 Chroma = clr - Luma;
		clr = (Chroma * TM_SATURATION) + Luma;
		clr = vec3(filmic_curve(clr.r), filmic_curve(clr.g), filmic_curve(clr.b)) / filmic_curve(W);
	#endif
	return clr;
}

float flat_shading(float dusk){
	dusk = dusk*0.75+0.25;
	vec3 n = normalize(cross(dFdx(cPos),dFdy(cPos)));
	n.x = abs(n.x*mix(1.5,0.8,dusk));
	n.yz = n.yz*0.5+0.5;
	n.yz *= mix(vec2(0.5,0.0),vec2(1.0),dusk);
	return max(n.x,max(n.y,n.z));
}

vec4 water(vec4 col,float weather,highp float time){
	vec3 p = cPos;
	float sun = smoothstep(.5,.75,uv1.y);
	float dist = smoothstep(100.,500.,(wPos.x*wPos.x+wPos.z*wPos.z)/max(1.,abs(wPos.y)));
	col.rgb = mix(col.rgb,vec3(col.r+col.g+col.b),dist*.25);
	#ifdef C_REF
		col.rgb *= mix(ESBE_HAN,snoise(vec2(wPos.x-time,wPos.z)*.05)+.5,sun*((1.-dist)*.1+.1));
	#endif

	p.xz *= ESBE_WATER;
	p.xz += smoothstep(0.,8.,abs(p.y-8.))*.5;
	float n = (snoise(p.xz-time*.5)+snoise(vec2(p.x-time,(p.z+time)*.5)))*.375+.25;
	float n2 = smoothstep(.5,1.,n);

	vec4 col2 = vec4(mix(col.rgb*1.2,vec3(col.r+col.g+col.b),.3),col.a*1.1);
	vec4 col3 = mix(col*1.1,vec4(.8,.8,.9,.9),smoothstep(3.+abs(wPos.y)*.3,0.,abs(wPos.z))*sun*weather);

	return mix(col,mix(col2,col3,n2),n*((1.-dist)*.7+.3));
}


void main()
{
#ifdef BYPASS_PIXEL_SHADER
	gl_FragColor = vec4(0);
	return;
#else

#if USE_TEXEL_AA
	highp vec4 diffuse = texture2D_AA(TEXTURE_0, uv0);
#else
	highp vec4 diffuse = texture2D(TEXTURE_0, uv0);
#endif

#ifdef SEASONS_FAR
	diffuse.a = 1.0;
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

vec4 inColor = color;

#if defined(BLEND)
	diffuse.a *= inColor.a;
#endif

#if !defined(ALWAYS_LIT)
	diffuse *= texture2D( TEXTURE_1, uv1 );
#endif

#ifndef SEASONS
	#if !USE_ALPHA_TEST && !defined(BLEND)
		diffuse.a = inColor.a;
	#endif
	diffuse.rgb *= inColor.rgb;
#else
	vec2 uv = inColor.xy;
	diffuse.rgb *= mix(vec3(1.0,1.0,1.0), texture2D( TEXTURE_2, uv).rgb*2.0, inColor.b);
	diffuse.rgb *= inColor.aaa;
	diffuse.a = 1.0;
#endif

#ifdef FOG
	float weather = smoothstep(0.8,1.0,FOG_CONTROL.y);
#else
	float weather = 1.0;
#endif
float daylight = texture2D(TEXTURE_1,vec2(0.0, 1.0)).r;
float sunlight = smoothstep(0.87-blur,0.87+blur,uv1.y);
float shset = ESBE_SHADOW_DARKNESS-uv1.x;
float dusk = max(smoothstep(0.55,0.4,daylight),smoothstep(0.65,0.8,daylight));
float w = step(FOG_CONTROL.x,.0001);
float cosT = abs(dot(vec3(0.,1.,0.),normalize(wPos)));
float rend = smoothstep(.95,.9,length(wPos)/FAR_CHUNKS_DISTANCE);
daylight *= weather;

#ifdef ESBE_LIGHT
	diffuse.rgb += ESBE_LIGHT*max(0.0,uv1.x-0.5)*mix(1.0,smoothstep(1.0,0.8,uv1.y)*0.5+0.5,daylight);
#endif

diffuse.rgb = ESBEmapping(diffuse.rgb);

#ifdef ESBE_SUN_LIGHT
	diffuse.rgb += (vec3(1.)-diffuse.rgb)*diffuse.rgb*sunlight*daylight*ESBE_SUN_LIGHT;
#endif

#if defined(ESBE_WATER)
	if(wf > 0.0){
		diffuse = mix(diffuse,water(diffuse,weather,TIME),1.2-cosT);
	}
#endif

#ifdef FANCY
	if(wf+w>.5)diffuse = water(diffuse,weather,TIME);
#endif

#ifdef ESBE_SHADOW
	float s_amount = mix(0.45,0.0,sunlight);
	diffuse.rgb = mix(diffuse.rgb,ESBE_SHADOW,s_amount*shset*daylight);
#endif

#if !defined(ALPHA_TEST) && !defined(BLEND) && defined(ESBE_SIDE_SHADOW)
	float s_amount2 = mix(0.45,0.0,smoothstep(0.5-blur*4.,0.5+blur*4.,color.g));
	if(color.r==color.g && color.g == color.b)diffuse.rgb = mix(diffuse.rgb,ESBE_SIDE_SHADOW,s_amount2*shset*daylight*sunlight*rend);
#endif

#ifdef ESBE_FLAT_SHADING
	diffuse.rgb *= mix(1.0,flat_shading(dusk),smoothstep(0.7,0.95,uv1.y)*min(1.25-uv1.x,1.0)*daylight);
#endif

#if defined(ESBE_UNEVEN) && !defined(BLEND)
	if(color.r<color.g+color.b){
		float t_br = smoothstep(2.,1.,length(diffuse.rgb));
		diffuse.rgb *= 1.+(.5-length(texture2D(TEXTURE_0, uv0-t_br*.00012).rgb/1.732))*t_br*ESBE_UNEVEN;
	}
#endif

#ifdef DUSK
	float dusk3 = DUSK*smoothstep(dusk1,dusk1+dusk2,uv1.y)*weather;
	dusk = dusk*dusk3+(1.0-dusk3);
	diffuse.rgb *= vec3(2.0-dusk,1.0,dusk);
#endif

#ifdef FOG
	diffuse.rgb = mix( diffuse.rgb, fogColor.rgb, fogColor.a );
#endif

gl_FragColor = diffuse;

#endif // BYPASS_PIXEL_SHADER
}

// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "vertexVersionCentroid.h"
#if __VERSION__ >= 300
	#ifndef BYPASS_PIXEL_SHADER
		_centroid out vec2 uv0;
		_centroid out vec2 uv1;
	#endif
#else
	#ifndef BYPASS_PIXEL_SHADER
		varying vec2 uv0;
		varying vec2 uv1;
	#endif
#endif

#ifndef BYPASS_PIXEL_SHADER
	varying vec4 color;
#endif

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

#include "uniformWorldConstants.h"
#include "uniformPerFrameConstants.h"
#include "uniformShaderConstants.h"
#include "uniformRenderChunkConstants.h"
#include "ESBEutil.h"
uniform highp float TOTAL_REAL_WORLD_TIME;

attribute POS4 POSITION;
attribute vec4 COLOR;
attribute vec2 TEXCOORD_0;
attribute vec2 TEXCOORD_1;

const float rA = 1.0;
const float rB = 1.0;
const vec3 UNIT_Y = vec3(0,1,0);
const float DIST_DESATURATION = 56.0 / 255.0; //WARNING this value is also hardcoded in the water color, don'tchange

#ifdef WIND
highp float hash11(highp float p){
	highp vec3 p3  = vec3(fract(p * 0.1031));
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}
#endif

highp float random(highp float p){
	#ifdef WIND
		p = p/3.0+TOTAL_REAL_WORLD_TIME;
		return mix(hash11(floor(p)),hash11(ceil(p)),smoothstep(0.0,1.0,fract(p)))*2.0;
	#else
		return 1.0;
	#endif
}

void main()
{
		wf = 0.;
		POS4 worldPos;
#ifdef AS_ENTITY_RENDERER
		POS4 pos = WORLDVIEWPROJ * POSITION;
		worldPos = pos;
#else
    worldPos.xyz = (POSITION.xyz * CHUNK_ORIGIN_AND_SCALE.w) + CHUNK_ORIGIN_AND_SCALE.xyz;
    worldPos.w = 1.0;

    // Transform to view space before projection instead of all at once to avoid floating point errors
    // Not required for entities because they are already offset by camera translation before rendering
    // World position here is calculated above and can get huge
    POS4 pos = WORLDVIEW * worldPos;
    pos = PROJ * pos;
#endif
    gl_Position = pos;
		cPos = POSITION.xyz;
		wPos = worldPos.xyz;

#ifndef BYPASS_PIXEL_SHADER
    uv0 = TEXCOORD_0;
    uv1 = TEXCOORD_1;
	color = COLOR;
#endif

///// find distance from the camera

#if defined(FOG) || defined(BLEND)
	#ifdef FANCY
		vec3 relPos = -worldPos.xyz;
		float cameraDepth = length(relPos);
	#else
		float cameraDepth = pos.z;
	#endif
#endif

///// waves
#if defined ALPHA_TEST && defined(LEAVES_WAVES)
	if(color.g != color.b && color.r < color.g+color.b){
		POS3 l = POSITION.xyz;
		l.y = abs(l.y-8.0);
		gl_Position.s += sin(TOTAL_REAL_WORLD_TIME * 3.5 + 2.0 * l.x + 2.0 * l.z + l.y) * 0.015 * random(l.x+l.y+l.z);
	}
#endif

#if !defined(BYPASS_PIXEL_SHADER) && !defined(ALPHA_TEST)
	if(color.a < 0.95 && color.a > 0.05 && color.g > color.r){
		#ifdef WATER_WAVES
			POS3 l = worldPos.xyz + VIEW_POS;
			gl_Position.t += sin(TOTAL_REAL_WORLD_TIME * 3.5 + 2.0 * l.x + 2.0 * l.z + l.y) * 0.06 * fract(POSITION.y) * random(l.x+l.y+l.z);
		#endif
		color.a *= 0.5;
		wf = 1.;
	}
#endif

///// apply fog

#ifdef FOG
	float len = cameraDepth / RENDER_DISTANCE;
	#ifdef ALLOW_FADE
		len += RENDER_CHUNK_FOG_ALPHA;
	#endif

    fogColor.rgb = FOG_COLOR.rgb;
	fogColor.a = clamp((len - FOG_CONTROL.x) / (FOG_CONTROL.y - FOG_CONTROL.x), 0.0, 1.0);
#endif

///// blended layer (mostly water) magic
#ifdef BLEND
	//Mega hack: only things that become opaque are allowed to have vertex-driven transparency in the Blended layer...
	//to fix this we'd need to find more space for a flag in the vertex format. color.a is the only unused part
	if(color.a < 0.95 && color.a > 0.05) {
		#ifdef FANCY  /////enhance water
		#else
			// Completely insane, but if I don't have these two lines in here, the water doesn't render on a Nexus 6
			vec4 surfColor = vec4(color.rgb, 1.0);
			color = surfColor;
		#endif //FANCY

		float cameraDist = cameraDepth / FAR_CHUNKS_DISTANCE;
		float alphaFadeOut = clamp(cameraDist, 0.0, 1.0);
		color.a = mix(color.a, 1.5, alphaFadeOut);
	}
#endif

#ifndef BYPASS_PIXEL_SHADER
	#ifndef FOG
		// If the FOG_COLOR isn't used, the reflection on NVN fails to compute the correct size of the constant buffer as the uniform will also be gone from the reflection data
		color.rgb += FOG_COLOR.rgb * 0.000001;
	#endif
#endif
}

// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#ifndef MOAIMETALSHADERS_H
#define MOAIMETALSHADERS_H

//================================================================//
// Built-in MSL shaders for the Metal backend.
//================================================================//
// These are line-by-line translations of the GLSL built-ins in
// src/moaicore/shaders/. This header contains only C string literals, so it
// is safe to include on every platform (MOAIShaderMgr includes it
// unconditionally; the strings are simply unused by the GL backend).
//
// MSL conventions (also the contract for content-provided MSL shaders):
//
// - entry points are named "vertexMain" / "fragmentMain".
// - vertex attributes use [[attribute(i)]] with the same indices the GLSL
//   attribute bindings used (MOAIShader::SetVertexAttribute):
//     XYZWUVC: position = 0, uv = 1, color = 2
//     XYZWC:   position = 0, color = 1
//   The vertex stream is bound at buffer(30) via [[stage_in]]
//   (MOAI_METAL_VERTEX_BUFFER_INDEX keeps 0..29 free for uniform buffers).
// - varyings are passed in a struct using [[user(name)]] semantics carrying
//   the GLSL varying names (colorVarying, uvVarying).
// - per-shader uniforms live in a single struct named "Uniforms" bound at
//   buffer(0) of each stage, with the GLSL uniform names as members. The
//   backend resolves uniform names against this struct by reflection.
// - pass-level uniforms (the y-flip factor) are bound at buffer(1) of the
//   vertex stage: struct PassUniforms { float yFlip; }.
// - the single texture sampler uses texture(0)/sampler(0).
//
// COORDINATES: vertices arrive in GL clip space (the engine CPU-transforms
// vertices; these vertex shaders are pass-throughs, exactly like their GLSL
// counterparts). Every vertex function therefore ends with the GL->Metal
// clip-space fixup:
//
//     p.y *= pass.yFlip;              // pass orientation (see backend notes)
//     p.z = ( p.z + p.w ) * 0.5;      // GL depth [-w,w] -> Metal [0,w]
//
// The vertex output also always carries [[point_size]] = 1.0: Metal requires
// a point size output when drawing point primitives, and the member is
// harmless for other primitive types. (GL parity: the legacy renderer drew
// 1px points/lines.)

// variadic so that any stray top-level commas in the shader body cannot
// split the macro argument list
#define MOAI_METAL_SHADER(...) #__VA_ARGS__

//----------------------------------------------------------------//
// common preamble: pass uniforms + XYZWUVC vertex layout + varyings
#define MOAI_METAL_PREAMBLE \
	"#include <metal_stdlib>\n" \
	"using namespace metal;\n" \
	MOAI_METAL_SHADER ( \
		struct PassUniforms { \
			float yFlip; \
		}; \
	)

#define MOAI_METAL_XYZWUVC_IO \
	MOAI_METAL_SHADER ( \
		struct VertexIn { \
			float4 position		[[ attribute ( 0 ) ]]; \
			float2 uv			[[ attribute ( 1 ) ]]; \
			float4 color		[[ attribute ( 2 ) ]]; \
		}; \
		struct VertexOut { \
			float4 position		[[ position ]]; \
			float pointSize		[[ point_size ]]; \
			float4 colorVarying	[[ user ( colorVarying ) ]]; \
			float2 uvVarying	[[ user ( uvVarying ) ]]; \
		}; \
		struct FragmentIn { \
			float4 colorVarying	[[ user ( colorVarying ) ]]; \
			float2 uvVarying	[[ user ( uvVarying ) ]]; \
		}; \
	)

//----------------------------------------------------------------//
// DECK2D: gl_FragColor = texture2D ( sampler, uvVarying ) * colorVarying
static const char* _deck2DShaderVSHMSL =
	MOAI_METAL_PREAMBLE
	MOAI_METAL_XYZWUVC_IO
	MOAI_METAL_SHADER (
		vertex VertexOut vertexMain ( VertexIn in [[ stage_in ]], constant PassUniforms& pass [[ buffer ( 1 ) ]] ) {
			VertexOut out;
			float4 p = in.position;
			p.y *= pass.yFlip;
			p.z = ( p.z + p.w ) * 0.5;
			out.position = p;
			out.pointSize = 1.0;
			out.uvVarying = in.uv;
			out.colorVarying = in.color;
			return out;
		}
	);

static const char* _deck2DShaderFSHMSL =
	MOAI_METAL_PREAMBLE
	MOAI_METAL_XYZWUVC_IO
	MOAI_METAL_SHADER (
		fragment float4 fragmentMain ( FragmentIn in [[ stage_in ]], texture2d < float > tex [[ texture ( 0 ) ]], sampler smp [[ sampler ( 0 ) ]] ) {
			return tex.sample ( smp, in.uvVarying ) * in.colorVarying;
		}
	);

//----------------------------------------------------------------//
// DECK2D_TEX_ONLY: gl_FragColor = texture2D ( sampler, uvVarying )
// (the GLSL vertex shader declares the color attribute but does not use it;
// here we simply omit it from the stage_in struct - the vertex format still
// supplies attribute 2, which Metal ignores)
static const char* _deck2DTexOnlyShaderVSHMSL =
	MOAI_METAL_PREAMBLE
	MOAI_METAL_XYZWUVC_IO
	MOAI_METAL_SHADER (
		vertex VertexOut vertexMain ( VertexIn in [[ stage_in ]], constant PassUniforms& pass [[ buffer ( 1 ) ]] ) {
			VertexOut out;
			float4 p = in.position;
			p.y *= pass.yFlip;
			p.z = ( p.z + p.w ) * 0.5;
			out.position = p;
			out.pointSize = 1.0;
			out.uvVarying = in.uv;
			out.colorVarying = float4 ( 1.0, 1.0, 1.0, 1.0 );
			return out;
		}
	);

static const char* _deck2DTexOnlyShaderFSHMSL =
	MOAI_METAL_PREAMBLE
	MOAI_METAL_XYZWUVC_IO
	MOAI_METAL_SHADER (
		fragment float4 fragmentMain ( FragmentIn in [[ stage_in ]], texture2d < float > tex [[ texture ( 0 ) ]], sampler smp [[ sampler ( 0 ) ]] ) {
			return tex.sample ( smp, in.uvVarying );
		}
	);

//----------------------------------------------------------------//
// FONT: exact translation of the component-wise GLSL:
//   gl_FragColor [ 0..2 ] = colorVarying [ 0..2 ];
//   gl_FragColor [ 3 ] = colorVarying [ 3 ] * texture2D ( sampler, uvVarying )[ 3 ];
// (font textures are GL_ALPHA -> MTLPixelFormatA8Unorm; sampling yields
// (0,0,0,a) in both APIs, and only the alpha component is read here)
static const char* _fontShaderVSHMSL =
	MOAI_METAL_PREAMBLE
	MOAI_METAL_XYZWUVC_IO
	MOAI_METAL_SHADER (
		vertex VertexOut vertexMain ( VertexIn in [[ stage_in ]], constant PassUniforms& pass [[ buffer ( 1 ) ]] ) {
			VertexOut out;
			float4 p = in.position;
			p.y *= pass.yFlip;
			p.z = ( p.z + p.w ) * 0.5;
			out.position = p;
			out.pointSize = 1.0;
			out.uvVarying = in.uv;
			out.colorVarying = in.color;
			return out;
		}
	);

static const char* _fontShaderFSHMSL =
	MOAI_METAL_PREAMBLE
	MOAI_METAL_XYZWUVC_IO
	MOAI_METAL_SHADER (
		fragment float4 fragmentMain ( FragmentIn in [[ stage_in ]], texture2d < float > tex [[ texture ( 0 ) ]], sampler smp [[ sampler ( 0 ) ]] ) {
			return float4 ( in.colorVarying.rgb, in.colorVarying.a * tex.sample ( smp, in.uvVarying ).a );
		}
	);

//----------------------------------------------------------------//
// LINE: position = 0, color = 1 (XYZWC preset)
static const char* _lineShaderVSHMSL =
	MOAI_METAL_PREAMBLE
	MOAI_METAL_SHADER (
		struct VertexIn {
			float4 position		[[ attribute ( 0 ) ]];
			float4 color		[[ attribute ( 1 ) ]];
		};
		struct VertexOut {
			float4 position		[[ position ]];
			float pointSize		[[ point_size ]];
			float4 colorVarying	[[ user ( colorVarying ) ]];
		};
		vertex VertexOut vertexMain ( VertexIn in [[ stage_in ]], constant PassUniforms& pass [[ buffer ( 1 ) ]] ) {
			VertexOut out;
			float4 p = in.position;
			p.y *= pass.yFlip;
			p.z = ( p.z + p.w ) * 0.5;
			out.position = p;
			out.pointSize = 1.0;
			out.colorVarying = in.color;
			return out;
		}
	);

static const char* _lineShaderFSHMSL =
	MOAI_METAL_PREAMBLE
	MOAI_METAL_SHADER (
		struct FragmentIn {
			float4 colorVarying	[[ user ( colorVarying ) ]];
		};
		fragment float4 fragmentMain ( FragmentIn in [[ stage_in ]] ) {
			return in.colorVarying;
		}
	);

//----------------------------------------------------------------//
// MESH: gl_Position = position * transform; colorVarying = color * ucolor
// The matrix bytes uploaded by glUniformMatrix4fv and by the Metal backend
// are identical; float4x4 constructs columns from consecutive float4s just
// like GLSL mat4, so `position * transform` computes the exact same result.
// Do not transpose anything.
static const char* _meshShaderVSHMSL =
	MOAI_METAL_PREAMBLE
	MOAI_METAL_XYZWUVC_IO
	MOAI_METAL_SHADER (
		struct Uniforms {
			float4x4 transform;
			float4 ucolor;
		};
		vertex VertexOut vertexMain ( VertexIn in [[ stage_in ]], constant Uniforms& uniforms [[ buffer ( 0 ) ]], constant PassUniforms& pass [[ buffer ( 1 ) ]] ) {
			VertexOut out;
			float4 p = in.position * uniforms.transform;
			p.y *= pass.yFlip;
			p.z = ( p.z + p.w ) * 0.5;
			out.position = p;
			out.pointSize = 1.0;
			out.uvVarying = in.uv;
			out.colorVarying = in.color * uniforms.ucolor;
			return out;
		}
	);

static const char* _meshShaderFSHMSL =
	MOAI_METAL_PREAMBLE
	MOAI_METAL_XYZWUVC_IO
	MOAI_METAL_SHADER (
		fragment float4 fragmentMain ( FragmentIn in [[ stage_in ]], texture2d < float > tex [[ texture ( 0 ) ]], sampler smp [[ sampler ( 0 ) ]] ) {
			return tex.sample ( smp, in.uvVarying ) * in.colorVarying;
		}
	);

#endif

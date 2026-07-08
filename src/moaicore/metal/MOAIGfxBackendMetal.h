// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#ifndef MOAIGFXBACKENDMETAL_H
#define MOAIGFXBACKENDMETAL_H

#include <moaicore/MOAIGfxBackend.h>

#if defined ( MOAI_OS_OSX ) || defined ( MOAI_OS_IPHONE )

class MOAIVertexFormat;

// Opaque implementation context (ObjC++, defined in MOAIGfxBackendMetal.mm).
// This header stays C++-safe so it can be included from .cpp files (AKU.cpp
// instantiates the backend).
struct MOAIMetalContext;

// POD vertex layout snapshot (defined in MOAIMetalPipelineCache.h)
struct MOAIMetalVertexLayout;

//================================================================//
// MOAIGfxBackendMetal
//================================================================//
/**
 * Native Metal implementation of MOAIGfxBackend.
 *
 * COORDINATE INVARIANT (fidelity-critical; see the .mm for the full
 * derivation and worked examples):
 *
 * - The "default framebuffer" (SetFrameBuffer ( 0 )) is a persistent
 *   RGBA8 canvas texture owned by the backend, stored TOP-DOWN (row 0 =
 *   visual top, normal image orientation). Rendering GL clip-space
 *   vertices with Metal's default conventions produces exactly that, so
 *   the canvas pass uses yFlip = +1. The canvas -> drawable present quad
 *   is an identity mapping and ReadPixelsRGBA8's top-down contract is a
 *   straight copy.
 *
 * - Offscreen targets (MOAIFrameBufferTexture) must keep GL's BOTTOM-UP
 *   memory layout (row 0 = visual bottom) because content UVs compensate
 *   for it. Offscreen passes therefore render with yFlip = -1 (and
 *   inverted front-face winding when culling), and ReadPixelsRGBA8 flips
 *   rows on the way out.
 *
 * - Viewport/scissor rects arrive in GL window coordinates (origin
 *   bottom-left). For the top-down canvas: y_mtl = H - ( y_gl + h ).
 *   For bottom-up (NDC-flipped) offscreen targets: y_mtl = y_gl.
 */
class MOAIGfxBackendMetal :
	public MOAIGfxBackend {
private:

	MOAIMetalContext* mCtx;

	//----------------------------------------------------------------//
	// snapshot a MOAIVertexFormat's attributes (this class is a friend of
	// MOAIVertexFormat); consumed by the pipeline cache
	void				BuildVertexLayout				( const MOAIVertexFormat& format, MOAIMetalVertexLayout& layout ) const;

public:

	//----------------------------------------------------------------//
						MOAIGfxBackendMetal				();
	virtual				~MOAIGfxBackendMetal			();

	Backend				GetBackendID					() const;

	bool				DetectContext					( MOAIGfxCaps& caps );

	void				BeginFrame						();
	void				EndFrame						();

	void				DeleteResource					( u32 type, MOAIGfxResID id );
	void				FlushHint						();

	u32					GetError						();
	cc8*				GetErrorString					( u32 error );

	void				SetFrameBuffer					( MOAIGfxResID id );
	void				Clear							( u32 glMask, float r, float g, float b, float a );
	void				ReadPixelsRGBA8					( u32 width, u32 height, void* buffer );

	void				SetViewport						( int x, int y, int width, int height );
	void				SetScissor						( bool enabled, int x, int y, int width, int height );
	void				SetBlend						( bool enabled, u32 glSrcFactor, u32 glDstFactor, u32 glEquation );
	void				SetDepth						( u32 glDepthFuncOrZero, bool depthMask );
	void				SetCull							( u32 glCullModeOrZero );
	void				SetLineWidth					( float width );
	void				SetPointSize					( float size );

	void				DrawArrays						( u32 glPrimType, u32 count, const MOAIVertexFormat& format, const void* buffer, size_t sizeInBytes );
	void				DrawIndexed						( u32 glPrimType, u32 indexCount, MOAIGfxResID indexBuffer, const MOAIVertexFormat& format, const void* buffer, size_t sizeInBytes );

	MOAIGfxResID		CreateTexture					( const MOAIGfxTextureDesc& desc, const void* data, size_t dataSize );
	bool				UploadTextureMip				( MOAIGfxResID id, const MOAIGfxTextureDesc& desc, u32 level, u32 width, u32 height, const void* data, size_t dataSize );
	bool				UpdateTextureRegion				( MOAIGfxResID id, const MOAIGfxTextureDesc& desc, int x, int y, u32 width, u32 height, const void* data );
	void				BindTexture						( u32 unit, MOAIGfxResID id, const MOAIGfxSamplerDesc* sampler );
	void				SetActiveTexture				( u32 unit );

	MOAIGfxResID		CreateFrameBuffer				( u32 width, u32 height, u32 glColorFormat, u32 glDepthFormat, u32 glStencilFormat, MOAIGfxResID& outColorTexture, MOAIGfxResID& outColorBuffer, MOAIGfxResID& outDepthBuffer, MOAIGfxResID& outStencilBuffer, bool& outComplete );

	MOAIGfxResID		CreateIndexBuffer				( const u16* indices, u32 count );

	MOAIGfxResID		CreateProgram					( const MOAIGfxShaderProgramDesc& desc );
	u32					ResolveUniform					( MOAIGfxResID program, cc8* name, u32 uniformType );
	void				UseProgram						( MOAIGfxResID program );
	void				SetUniform						( u32 addr, u32 uniformType, const void* data );

	// GLES1 fixed-function legacy: no-ops on the programmable-only Metal backend
	void				MatrixMode						( u32 glMatrixMode );
	void				LoadIdentity					();
	void				LoadMatrix						( const float* m );
	void				MultMatrix						( const float* m );
	void				Color4f							( float r, float g, float b, float a );
};

#endif
#endif

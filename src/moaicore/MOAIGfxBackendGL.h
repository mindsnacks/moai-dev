// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#ifndef	MOAIGFXBACKENDGL_H
#define	MOAIGFXBACKENDGL_H

#include <moaicore/MOAIGfxBackend.h>

class MOAIVertexFormat;

//================================================================//
// MOAIGfxBackendGL
//================================================================//
/**
 * OpenGL implementation of MOAIGfxBackend. Contains the raw GL code that
 * previously lived at the call sites in moaicore, moved verbatim. GL headers
 * come in via the moaicore pch, so this class compiles on all current
 * platforms (desktop GL, GLES1/2).
 */
class MOAIGfxBackendGL :
	public MOAIGfxBackend {
private:

	//----------------------------------------------------------------//
	// from MOAIVertexFormat::Bind/BindFixed/BindProgrammable/Unbind
	void				BindVertexFormat				( const MOAIVertexFormat& format, void* buffer );
	void				BindVertexFormatFixed			( const MOAIVertexFormat& format, void* buffer );
	void				BindVertexFormatProgrammable	( const MOAIVertexFormat& format, void* buffer );
	void				UnbindVertexFormat				( const MOAIVertexFormat& format );
	void				UnbindVertexFormatFixed			( const MOAIVertexFormat& format );
	void				UnbindVertexFormatProgrammable	( const MOAIVertexFormat& format );

	//----------------------------------------------------------------//
	// from MOAIShader::CompileShader/PrintShaderLog/PrintProgramLog
	GLuint				CompileShader					( GLuint type, cc8* source );
	void				PrintProgramLog					( GLuint program );
	void				PrintShaderLog					( GLuint shader );

public:

	//----------------------------------------------------------------//
						MOAIGfxBackendGL				();
	virtual				~MOAIGfxBackendGL				();

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

	void				MatrixMode						( u32 glMatrixMode );
	void				LoadIdentity					();
	void				LoadMatrix						( const float* m );
	void				MultMatrix						( const float* m );
	void				Color4f							( float r, float g, float b, float a );
};

#endif

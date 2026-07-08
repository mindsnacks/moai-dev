// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#ifndef	MOAIGFXBACKEND_H
#define	MOAIGFXBACKEND_H

class MOAIVertexFormat;

//================================================================//
// MOAIGfxBackend
//================================================================//
/**
 * Abstract rendering backend.
 *
 * Altitude: "GL as actually used by moaicore" — each method corresponds to
 * one cluster of raw GL calls that used to live at a single call site, with
 * the information that call site had at hand. The OpenGL implementation
 * (MOAIGfxBackendGL) contains the previous GL code verbatim; the Metal
 * implementation maps each method onto command-encoder state.
 *
 * Conventions:
 * - Enum values on this interface are RAW GL CONSTANTS (GL_TRIANGLES,
 *   GL_SRC_ALPHA, GL_LINEAR, GL_RGBA, ...). They leak into Lua scripts via
 *   RegisterLuaClass tables, so they are the stable wire format. Backends
 *   translate internally.
 * - Coordinates arrive in GL conventions (viewport/scissor origin at the
 *   window bottom-left, as produced by MOAIFrameBuffer::WndRectToDevice).
 *   Backends convert as needed.
 * - Resource handles are opaque MOAIGfxResID values. For the GL backend
 *   these are the GL object names; other backends use handle-table indices.
 *   0 is reserved: "no resource" (and, for SetFrameBuffer, the default
 *   framebuffer provided by the host).
 * - All calls happen on the single render thread, between BeginFrame and
 *   EndFrame when drawing, or at resource-creation time otherwise
 *   (textures/shaders may be created outside a frame, matching GL).
 */

typedef uintptr_t MOAIGfxResID;

//----------------------------------------------------------------//
// Capabilities discovered at context detection.
struct MOAIGfxCaps {

	bool	mIsOpenGLES;
	u32		mMajorVersion;
	u32		mMinorVersion;
	bool	mIsProgrammable;
	bool	mIsFramebufferSupported;
	u32		mMaxTextureUnits;
	u32		mMaxTextureSize;
};

//----------------------------------------------------------------//
// Immutable description for texture creation. GL enum values as used by
// MOAITextureBase (mGLInternalFormat / mGLPixelType).
struct MOAIGfxTextureDesc {

	u32		mWidth;
	u32		mHeight;
	u32		mGLInternalFormat;	// GL_RGBA, GL_RGB, GL_ALPHA, GL_LUMINANCE, ... or compressed format
	u32		mGLPixelType;		// GL_UNSIGNED_BYTE, GL_UNSIGNED_SHORT_5_6_5, ...
	bool	mIsCompressed;		// use compressed upload path (PVRTC)
	bool	mHasMipmaps;		// mip levels beyond 0 will be uploaded
};

//----------------------------------------------------------------//
// Sampler state, GL enum values as used by MOAITextureBase::OnBind.
struct MOAIGfxSamplerDesc {

	u32		mMinFilter;			// GL_LINEAR, GL_NEAREST, GL_*_MIPMAP_*
	u32		mMagFilter;
	u32		mWrapS;				// GL_REPEAT or GL_CLAMP_TO_EDGE
	u32		mWrapT;				// ADJUSTED: split S/T; MOAITextureBase tracks mWrapS/mWrapT independently (Lua setWrap takes both)
};

//----------------------------------------------------------------//
// Everything MOAIShader knows when creating a program.
struct MOAIGfxShaderProgramDesc {

	cc8*		mVertexSource;			// GLSL (GL backend)
	cc8*		mFragmentSource;		// GLSL (GL backend)
	cc8*		mVertexSourceMSL;		// MSL (Metal backend); may be 0 during transition
	cc8*		mFragmentSourceMSL;		// MSL (Metal backend); may be 0 during transition

	// attribute bindings, applied before link: index -> name
	u32			mAttributeCount;
	const u32*	mAttributeIndices;
	cc8* const*	mAttributeNames;
};

//================================================================//
// MOAIGfxBackend
//================================================================//
class MOAIGfxBackend {
public:

	enum Backend {
		BACKEND_OPENGL,
		BACKEND_METAL,
	};

	virtual				~MOAIGfxBackend			() {}

	virtual Backend		GetBackendID			() const = 0;

	//----------------------------------------------------------------//
	// lifecycle / caps
	//----------------------------------------------------------------//

	// Query the live context and fill caps. Called from
	// MOAIGfxDevice::DetectContext once the host context/layer exists.
	virtual bool		DetectContext			( MOAIGfxCaps& caps ) = 0;

	// Frame brackets, called from MOAIRenderMgr::Render. GL: no-ops.
	virtual void		BeginFrame				() = 0;
	virtual void		EndFrame				() = 0;

	// Deferred resource deletion (backs MOAIGfxDeleter and direct deletes).
	// type is a MOAIGfxDeleter::DELETE_* value.
	virtual void		DeleteResource			( u32 type, MOAIGfxResID id ) = 0;

	// glFlush analog, used by SoftReleaseResources. GL: glFlush.
	virtual void		FlushHint				() = 0;

	// ADJUSTED: error reporting seam, needed by MOAIGfxDevice::ClearErrors /
	// LogErrors and the PVR upload error checks in MOAITextureBase.
	// GetError returns 0 (GL_NO_ERROR) when no error is pending.
	virtual u32			GetError				() = 0;
	virtual cc8*		GetErrorString			( u32 error ) = 0;

	//----------------------------------------------------------------//
	// render target / pass
	//----------------------------------------------------------------//

	// Bind a framebuffer as the render target. id 0 = the host-provided
	// default target. (GL: glBindFramebuffer.)
	virtual void		SetFrameBuffer			( MOAIGfxResID id ) = 0;

	// Clear the current target. glMask is a GL_*_BUFFER_BIT combination;
	// color applies when GL_COLOR_BUFFER_BIT is set. Always called at the
	// start of a pass (right after SetFrameBuffer, scissor disabled).
	virtual void		Clear					( u32 glMask, float r, float g, float b, float a ) = 0;

	// Read back the current target as RGBA8 in TOP-DOWN row order into
	// buffer (width*height*4 bytes). The GL implementation absorbs the
	// bottom-up flip that used to live in MOAIFrameBuffer::GrabImage.
	virtual void		ReadPixelsRGBA8			( u32 width, u32 height, void* buffer ) = 0;

	//----------------------------------------------------------------//
	// pipeline state
	//----------------------------------------------------------------//

	virtual void		SetViewport				( int x, int y, int width, int height ) = 0;
	virtual void		SetScissor				( bool enabled, int x, int y, int width, int height ) = 0;

	// glSrcFactor/glDstFactor/glEquation are GL blend enums. Equation is
	// recorded but MUST behave as GL_FUNC_ADD for parity: the legacy GL
	// path never applied the equation (MOAIBlendMode::Bind was dead code).
	virtual void		SetBlend				( bool enabled, u32 glSrcFactor, u32 glDstFactor, u32 glEquation ) = 0;

	// glDepthFunc 0 = depth test disabled. Mask = depth writes.
	virtual void		SetDepth				( u32 glDepthFuncOrZero, bool depthMask ) = 0;

	// glCullMode 0 = culling disabled; else GL_FRONT/GL_BACK/GL_FRONT_AND_BACK.
	virtual void		SetCull					( u32 glCullModeOrZero ) = 0;

	virtual void		SetLineWidth			( float width ) = 0;
	virtual void		SetPointSize			( float size ) = 0;

	//----------------------------------------------------------------//
	// drawing (client-memory vertex data, exactly as the engine streams it)
	//----------------------------------------------------------------//

	// Draw count vertices of glPrimType reading interleaved attributes
	// described by format from client memory at buffer (sizeInBytes valid
	// bytes). (GL: MOAIVertexFormat::Bind + glDrawArrays + Unbind.)
	virtual void		DrawArrays				( u32 glPrimType, u32 count, const MOAIVertexFormat& format, const void* buffer, size_t sizeInBytes ) = 0;

	// Indexed variant for MOAIMesh: u16 indices from an index buffer object.
	virtual void		DrawIndexed				( u32 glPrimType, u32 indexCount, MOAIGfxResID indexBuffer, const MOAIVertexFormat& format, const void* buffer, size_t sizeInBytes ) = 0;

	//----------------------------------------------------------------//
	// textures
	//----------------------------------------------------------------//

	// Create a texture and upload mip level 0 (data may be 0 for a
	// renderable/updatable texture; dataSize used for compressed uploads).
	// Returns 0 on failure.
	virtual MOAIGfxResID	CreateTexture		( const MOAIGfxTextureDesc& desc, const void* data, size_t dataSize ) = 0;

	// Upload one additional mip level (level >= 1).
	virtual bool		UploadTextureMip		( MOAIGfxResID id, const MOAIGfxTextureDesc& desc, u32 level, u32 width, u32 height, const void* data, size_t dataSize ) = 0;

	// Partial update of mip level 0 (glyph atlases). Data is tightly packed
	// width*height pixels in the texture's format.
	virtual bool		UpdateTextureRegion		( MOAIGfxResID id, const MOAIGfxTextureDesc& desc, int x, int y, u32 width, u32 height, const void* data ) = 0;

	// Bind texture to a unit. sampler is non-null when sampler params are
	// dirty and must be (re)applied. id 0 unbinds the unit.
	virtual void		BindTexture				( u32 unit, MOAIGfxResID id, const MOAIGfxSamplerDesc* sampler ) = 0;

	// ADJUSTED: make a texture unit active before the resource state machine
	// runs. MOAIGfxDevice::SetTexture activates the unit BEFORE texture
	// creation may happen (GL texture creation binds on the active unit), so
	// this cannot be folded into BindTexture without changing behavior.
	// (GL: glActiveTexture; also applies the GLES1 fixed-function
	// glEnable ( GL_TEXTURE_2D ) that used to live at the same call site.)
	virtual void		SetActiveTexture		( u32 unit ) = 0;

	//----------------------------------------------------------------//
	// offscreen render targets (MOAIFrameBufferTexture)
	//----------------------------------------------------------------//

	// Create a complete offscreen target. GL format enums as used by
	// MOAIFrameBufferTexture (color GL_RGBA8/GL_RGB565/..., depth
	// GL_DEPTH_COMPONENT16/, stencil GL_STENCIL_INDEX8/...; 0 = absent).
	// outColorTexture receives the sampleable color texture handle.
	// Returns the framebuffer handle for SetFrameBuffer, or 0 if a
	// framebuffer name could not be generated (caller may retry).
	// ADJUSTED: also outputs the intermediate color/depth/stencil buffer
	// handles (GL renderbuffers) plus a completeness flag, so
	// MOAIFrameBufferTexture can keep its deleter-based OnDestroy and its
	// original "incomplete -> Clear ()" handling. When outComplete is false
	// the caller must destroy the returned resources.
	virtual MOAIGfxResID	CreateFrameBuffer	( u32 width, u32 height, u32 glColorFormat, u32 glDepthFormat, u32 glStencilFormat, MOAIGfxResID& outColorTexture, MOAIGfxResID& outColorBuffer, MOAIGfxResID& outDepthBuffer, MOAIGfxResID& outStencilBuffer, bool& outComplete ) = 0;

	//----------------------------------------------------------------//
	// index buffers (MOAIIndexBuffer)
	//----------------------------------------------------------------//

	virtual MOAIGfxResID	CreateIndexBuffer	( const u16* indices, u32 count ) = 0;

	//----------------------------------------------------------------//
	// shaders (MOAIShader)
	//----------------------------------------------------------------//

	// Compile and link. Returns 0 on failure (errors go to MOAILog, matching
	// the previous PrintShaderLog behavior).
	virtual MOAIGfxResID	CreateProgram		( const MOAIGfxShaderProgramDesc& desc ) = 0;

	// Resolve a uniform by name. GL: glGetUniformLocation (u32)-1 when
	// absent; Metal: byte offset into the uniform block, (u32)-1 when
	// absent. uniformType is the MOAIShaderUniform type constant.
	virtual u32			ResolveUniform			( MOAIGfxResID program, cc8* name, u32 uniformType ) = 0;

	virtual void		UseProgram				( MOAIGfxResID program ) = 0;

	// Write a uniform value for the CURRENT program. addr is the value
	// ResolveUniform returned. count/data interpretation per uniformType
	// mirrors MOAIShaderUniform::Bind (float, int, vec4, mat3, mat4).
	virtual void		SetUniform				( u32 addr, u32 uniformType, const void* data ) = 0;

	//----------------------------------------------------------------//
	// GLES1 fixed-function legacy
	//----------------------------------------------------------------//
	// ADJUSTED: added so the USE_OPENGLES1 fixed-function paths in
	// MOAIGfxDevice (UpdateGpuVertexMtx / UpdateUVMtx / ResetState /
	// GpuLoadMatrix / GpuMultMatrix) can keep their structure. Matrices are
	// float[16] column-major, matching glLoadMatrixf. No-ops on
	// programmable-only backends; the GL backend compiles them out when
	// USE_OPENGLES1 is 0.

	virtual void		MatrixMode				( u32 glMatrixMode ) = 0;	// glMatrixMode
	virtual void		LoadIdentity			() = 0;						// glLoadIdentity
	virtual void		LoadMatrix				( const float* m ) = 0;		// glLoadMatrixf
	virtual void		MultMatrix				( const float* m ) = 0;		// glMultMatrixf
	virtual void		Color4f					( float r, float g, float b, float a ) = 0;	// glColor4f
};

//================================================================//
// MOAIGfx
//================================================================//
// Backend installation and access. The backend is process-global and
// outlives AKU contexts.
namespace MOAIGfx {

	MOAIGfxBackend&		Get						();
	void				Set						( MOAIGfxBackend* backend );	// takes ownership
	bool				IsSet					();
}

#endif

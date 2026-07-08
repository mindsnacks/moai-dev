// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#ifndef MOAIMETALRESOURCES_H
#define MOAIMETALRESOURCES_H

// ObjC++ header: include only from .mm files, after <moaicore/pch.h>.
#if ( defined ( MOAI_OS_OSX ) || defined ( MOAI_OS_IPHONE )) && defined ( __OBJC__ )

#import <Metal/Metal.h>
#include <map>
#include <string>
#include <vector>

#include <moaicore/MOAIGfxBackend.h>

//================================================================//
// resource records
//================================================================//

//----------------------------------------------------------------//
// One name->member entry of a reflected MSL uniform struct (buffer(0)).
struct MOAIMetalUniformMember {
	u32				mOffset;
	MTLDataType		mDataType;
};

//----------------------------------------------------------------//
// One resolved uniform "address" (the u32 ResolveUniform hands back is an
// index into MOAIMetalProgram::mSlots). A slot records where the uniform
// lives in each stage's CPU shadow block; -1 offset = absent in that stage.
struct MOAIMetalUniformSlot {
	int				mVsOffset;
	MTLDataType		mVsType;
	int				mFsOffset;
	MTLDataType		mFsType;
};

//----------------------------------------------------------------//
struct MOAIMetalProgram {

	id < MTLFunction >	mVertexFunction;
	id < MTLFunction >	mFragmentFunction;

	// CPU shadow of the buffer(0) uniform block per stage. ZERO-FILLED at
	// creation: GLSL zero-initializes uniforms and content relies on it
	// (e.g. uniforms that are declared but never set from Lua).
	std::vector < u8 >	mVsBlock;
	std::vector < u8 >	mFsBlock;

	// reflected members by name, per stage
	std::map < std::string, MOAIMetalUniformMember >	mVsMembers;
	std::map < std::string, MOAIMetalUniformMember >	mFsMembers;

	// resolved uniform slots (see MOAIMetalUniformSlot)
	std::vector < MOAIMetalUniformSlot >	mSlots;
	std::map < std::string, u32 >			mSlotsByName;

	MOAIMetalProgram () :
		mVertexFunction ( nil ),
		mFragmentFunction ( nil ) {
	}
};

//----------------------------------------------------------------//
struct MOAIMetalTexture {

	id < MTLTexture >			mTexture;

	// GL semantics: sampler params are *texture* state. The last sampler
	// state applied via BindTexture sticks to the texture.
	id < MTLSamplerState >		mSampler;

	// serial of the last frame whose command buffer encoded a draw that
	// references this texture (used by UpdateTextureRegion to decide
	// between replaceRegion and a blit-through-staging update)
	u64							mLastReferencedFrame;

	// creation formats, kept for region updates / mip uploads
	u32							mGLFormat;
	u32							mGLPixelType;

	MOAIMetalTexture () :
		mTexture ( nil ),
		mSampler ( nil ),
		mLastReferencedFrame ( 0 ),
		mGLFormat ( 0 ),
		mGLPixelType ( 0 ) {
	}
};

//----------------------------------------------------------------//
struct MOAIMetalIndexBuffer {

	id < MTLBuffer >		mBuffer;
	std::vector < u16 >		mCpuCopy;	// kept for TRIANGLE_FAN/LINE_LOOP index expansion

	MOAIMetalIndexBuffer () :
		mBuffer ( nil ) {
	}
};

//----------------------------------------------------------------//
struct MOAIMetalRenderTarget {

	id < MTLTexture >	mColor;			// RGBA8Unorm, renderTarget | shaderRead
	id < MTLTexture >	mDepthStencil;	// Depth32Float / Depth32Float_Stencil8 / Stencil8, or nil
	u32					mWidth;
	u32					mHeight;
	MOAIGfxResID		mColorTextureHandle;	// texture-table handle of mColor (for BindTexture)

	MOAIMetalRenderTarget () :
		mColor ( nil ),
		mDepthStencil ( nil ),
		mWidth ( 0 ),
		mHeight ( 0 ),
		mColorTextureHandle ( 0 ) {
	}
};

//================================================================//
// MOAIMetalResources
//================================================================//
// Handle table: MOAIGfxResID = slot index + 1 into a growable array; 0 is
// "no resource". Handles are u32-safe (the engine stores them in GLuint
// fields). Freed slots are recycled via a free list, mirroring GL name
// reuse. DeleteResource moves a slot's ObjC references into the caller's
// graveyard array (released once every in-flight command buffer that could
// reference them has completed - see MOAIGfxBackendMetal's frame lifecycle).
class MOAIMetalResources {
public:

	enum Kind {
		KIND_NONE,
		KIND_TEXTURE,
		KIND_INDEX_BUFFER,
		KIND_PROGRAM,
		KIND_RENDER_TARGET,
	};

	struct Slot {
		Kind					mKind;
		MOAIMetalTexture*		mTexture;
		MOAIMetalIndexBuffer*	mIndexBuffer;
		MOAIMetalProgram*		mProgram;
		MOAIMetalRenderTarget*	mTarget;

		Slot () :
			mKind ( KIND_NONE ),
			mTexture ( 0 ),
			mIndexBuffer ( 0 ),
			mProgram ( 0 ),
			mTarget ( 0 ) {
		}
	};

private:

	std::vector < Slot >	mSlots;
	std::vector < u32 >		mFreeList;

	//----------------------------------------------------------------//
	Slot* GetSlot ( MOAIGfxResID id ) {

		if (( id == 0 ) || ( id > this->mSlots.size ())) return 0;
		return &this->mSlots [( size_t )( id - 1 )];
	}

public:

	//----------------------------------------------------------------//
	MOAIGfxResID			AllocSlot			();
	void					DeleteResource		( MOAIGfxResID id, NSMutableArray* graveyard );
	MOAIMetalIndexBuffer*	GetIndexBuffer		( MOAIGfxResID id );
	MOAIMetalProgram*		GetProgram			( MOAIGfxResID id );
	MOAIMetalRenderTarget*	GetTarget			( MOAIGfxResID id );
	MOAIMetalTexture*		GetTexture			( MOAIGfxResID id );
	void					SetIndexBuffer		( MOAIGfxResID id, MOAIMetalIndexBuffer* ib );
	void					SetProgram			( MOAIGfxResID id, MOAIMetalProgram* program );
	void					SetTarget			( MOAIGfxResID id, MOAIMetalRenderTarget* target );
	void					SetTexture			( MOAIGfxResID id, MOAIMetalTexture* texture );
};

//================================================================//
// texture format helpers (implemented in MOAIMetalResources.mm)
//================================================================//

// Map a (GL internal format, GL pixel type) pair onto the Metal pixel format
// the backend stores it as. Returns MTLPixelFormatInvalid when unsupported.
MTLPixelFormat	MOAIMetalResolvePixelFormat		( u32 glFormat, u32 glPixelType, bool isCompressed );

// Bytes per pixel of the *Metal* storage format (0 for compressed).
u32				MOAIMetalStorageBytesPerPixel	( MTLPixelFormat format );

// Convert source pixels (GL layout, tightly packed) into the Metal storage
// format. Returns a pointer to the upload data: either src (no conversion
// needed) or scratch.data () after filling scratch with converted RGBA8.
const void*		MOAIMetalConvertPixels			( u32 glFormat, u32 glPixelType, u32 width, u32 height, const void* src, std::vector < u8 >& scratch );

// Full mip chain count for a base level size.
u32				MOAIMetalMipChainCount			( u32 width, u32 height );

// Compile MSL sources and reflect the buffer(0) uniform struct of each
// stage. Returns 0 on failure (errors logged via USLog).
MOAIMetalProgram*	MOAIMetalCreateProgram		( id < MTLDevice > device, const char* vshMSL, const char* fshMSL );

#endif
#endif

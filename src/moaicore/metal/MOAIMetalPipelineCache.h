// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#ifndef MOAIMETALPIPELINECACHE_H
#define MOAIMETALPIPELINECACHE_H

// ObjC++ header: include only from .mm files, after <moaicore/pch.h>.
#if ( defined ( MOAI_OS_OSX ) || defined ( MOAI_OS_IPHONE )) && defined ( __OBJC__ )

#import <Metal/Metal.h>
#include <map>

#include <moaicore/metal/MOAIMetalResources.h>

// vertex stream buffer binding: keeps 0..29 free for uniform/user buffers
#define MOAI_METAL_VERTEX_BUFFER_INDEX 30

//================================================================//
// MOAIMetalVertexLayout
//================================================================//
// POD snapshot of a MOAIVertexFormat (extracted by MOAIGfxBackendMetal,
// which is a friend of MOAIVertexFormat).
struct MOAIMetalVertexLayout {

	static const u32 MAX_ATTRIBUTES = 16;

	struct Attr {
		u32		mIndex;
		u32		mSize;
		u32		mType;			// raw GL type enum
		bool	mNormalized;
		u32		mOffset;
	};

	Attr	mAttrs [ MAX_ATTRIBUTES ];
	u32		mCount;
	u32		mStride;
	u64		mHash;			// FNV-1a over the above

	void ComputeHash () {

		u64 h = 0xcbf29ce484222325ULL;
		const u8* p = ( const u8* )this->mAttrs;
		size_t n = sizeof ( Attr ) * this->mCount;
		for ( size_t i = 0; i < n; ++i ) {
			h = ( h ^ p [ i ]) * 0x100000001b3ULL;
		}
		h = ( h ^ this->mStride ) * 0x100000001b3ULL;
		this->mHash = h;
	}
};

//================================================================//
// MOAIMetalPipelineCache
//================================================================//
class MOAIMetalPipelineCache {
private:

	//----------------------------------------------------------------//
	struct PipelineKey {
		u64		mProgramHandle;
		u64		mLayoutHash;
		u32		mBlendEnabled;
		u32		mSrcFactor;			// raw GL blend enum
		u32		mDstFactor;			// raw GL blend enum
		u32		mColorFormat;		// MTLPixelFormat
		u32		mDepthStencilFormat;	// MTLPixelFormat (Invalid = none)

		bool operator < ( const PipelineKey& other ) const {
			return memcmp ( this, &other, sizeof ( PipelineKey )) < 0;
		}
	};

	struct DepthKey {
		u32		mFunc;		// raw GL depth func, 0 = disabled
		u32		mMask;

		bool operator < ( const DepthKey& other ) const {
			return memcmp ( this, &other, sizeof ( DepthKey )) < 0;
		}
	};

	struct SamplerKey {
		u32		mMinFilter;
		u32		mMagFilter;
		u32		mWrapS;
		u32		mWrapT;

		bool operator < ( const SamplerKey& other ) const {
			return memcmp ( this, &other, sizeof ( SamplerKey )) < 0;
		}
	};

	std::map < PipelineKey, id < MTLRenderPipelineState > >	mPipelines;
	std::map < DepthKey, id < MTLDepthStencilState > >			mDepthStates;
	std::map < SamplerKey, id < MTLSamplerState > >				mSamplers;

	//----------------------------------------------------------------//
	id < MTLRenderPipelineState >	BuildPipeline		( id < MTLDevice > device, const MOAIMetalProgram& program, const MOAIMetalVertexLayout& layout, const PipelineKey& key );

public:

	//----------------------------------------------------------------//
	id < MTLRenderPipelineState >	GetPipeline			( id < MTLDevice > device, MOAIGfxResID programHandle, const MOAIMetalProgram& program, const MOAIMetalVertexLayout& layout, bool blendEnabled, u32 glSrcFactor, u32 glDstFactor, MTLPixelFormat colorFormat, MTLPixelFormat depthStencilFormat );
	id < MTLDepthStencilState >		GetDepthStencil		( id < MTLDevice > device, u32 glDepthFuncOrZero, bool depthMask );
	id < MTLSamplerState >			GetSampler			( id < MTLDevice > device, u32 glMinFilter, u32 glMagFilter, u32 glWrapS, u32 glWrapT );
};

#endif
#endif

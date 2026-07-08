// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#include <moaicore/pch.h>

#if defined ( MOAI_OS_OSX ) || defined ( MOAI_OS_IPHONE )

#include <moaicore/metal/MOAIMetalPipelineCache.h>
#include <uslscore/USLog.h>

//================================================================//
// local
//================================================================//

//----------------------------------------------------------------//
// (GL type, size, normalized) -> MTLVertexFormat. Covers every type the
// engine can put in a MOAIVertexFormat (Lua declareAttribute passes raw GL
// type enums). Returns false when unmappable.
static bool _vertexFormatForAttr ( u32 glType, u32 size, bool normalized, MTLVertexFormat& out ) {

	if (( size < 1 ) || ( size > 4 )) return false;

	switch ( glType ) {

		case GL_FLOAT: {
			static const MTLVertexFormat table [] = { MTLVertexFormatFloat, MTLVertexFormatFloat2, MTLVertexFormatFloat3, MTLVertexFormatFloat4 };
			out = table [ size - 1 ];
			return true;
		}
		case GL_UNSIGNED_BYTE: {
			static const MTLVertexFormat plain [] = { MTLVertexFormatUChar, MTLVertexFormatUChar2, MTLVertexFormatUChar3, MTLVertexFormatUChar4 };
			static const MTLVertexFormat norm [] = { MTLVertexFormatUCharNormalized, MTLVertexFormatUChar2Normalized, MTLVertexFormatUChar3Normalized, MTLVertexFormatUChar4Normalized };
			out = normalized ? norm [ size - 1 ] : plain [ size - 1 ];
			return true;
		}
		case GL_BYTE: {
			static const MTLVertexFormat plain [] = { MTLVertexFormatChar, MTLVertexFormatChar2, MTLVertexFormatChar3, MTLVertexFormatChar4 };
			static const MTLVertexFormat norm [] = { MTLVertexFormatCharNormalized, MTLVertexFormatChar2Normalized, MTLVertexFormatChar3Normalized, MTLVertexFormatChar4Normalized };
			out = normalized ? norm [ size - 1 ] : plain [ size - 1 ];
			return true;
		}
		case GL_SHORT: {
			static const MTLVertexFormat plain [] = { MTLVertexFormatShort, MTLVertexFormatShort2, MTLVertexFormatShort3, MTLVertexFormatShort4 };
			static const MTLVertexFormat norm [] = { MTLVertexFormatShortNormalized, MTLVertexFormatShort2Normalized, MTLVertexFormatShort3Normalized, MTLVertexFormatShort4Normalized };
			out = normalized ? norm [ size - 1 ] : plain [ size - 1 ];
			return true;
		}
		case GL_UNSIGNED_SHORT: {
			static const MTLVertexFormat plain [] = { MTLVertexFormatUShort, MTLVertexFormatUShort2, MTLVertexFormatUShort3, MTLVertexFormatUShort4 };
			static const MTLVertexFormat norm [] = { MTLVertexFormatUShortNormalized, MTLVertexFormatUShort2Normalized, MTLVertexFormatUShort3Normalized, MTLVertexFormatUShort4Normalized };
			out = normalized ? norm [ size - 1 ] : plain [ size - 1 ];
			return true;
		}
	}
	return false;
}

//----------------------------------------------------------------//
// GL blend factor -> Metal blend factor for the RGB channels.
static MTLBlendFactor _blendFactorRGB ( u32 glFactor ) {

	switch ( glFactor ) {
		case GL_ZERO:					return MTLBlendFactorZero;
		case GL_ONE:					return MTLBlendFactorOne;
		case GL_SRC_COLOR:				return MTLBlendFactorSourceColor;
		case GL_ONE_MINUS_SRC_COLOR:	return MTLBlendFactorOneMinusSourceColor;
		case GL_DST_COLOR:				return MTLBlendFactorDestinationColor;
		case GL_ONE_MINUS_DST_COLOR:	return MTLBlendFactorOneMinusDestinationColor;
		case GL_SRC_ALPHA:				return MTLBlendFactorSourceAlpha;
		case GL_ONE_MINUS_SRC_ALPHA:	return MTLBlendFactorOneMinusSourceAlpha;
		case GL_DST_ALPHA:				return MTLBlendFactorDestinationAlpha;
		case GL_ONE_MINUS_DST_ALPHA:	return MTLBlendFactorOneMinusDestinationAlpha;
		case GL_SRC_ALPHA_SATURATE:		return MTLBlendFactorSourceAlphaSaturated;
	}
	return MTLBlendFactorOne;
}

//----------------------------------------------------------------//
// GL blend factor -> Metal blend factor for the ALPHA channel. Per the GL
// spec, the *_COLOR factors use the alpha component when applied to the
// alpha channel, and SRC_ALPHA_SATURATE's alpha factor is 1.
static MTLBlendFactor _blendFactorAlpha ( u32 glFactor ) {

	switch ( glFactor ) {
		case GL_ZERO:					return MTLBlendFactorZero;
		case GL_ONE:					return MTLBlendFactorOne;
		case GL_SRC_COLOR:				return MTLBlendFactorSourceAlpha;
		case GL_ONE_MINUS_SRC_COLOR:	return MTLBlendFactorOneMinusSourceAlpha;
		case GL_DST_COLOR:				return MTLBlendFactorDestinationAlpha;
		case GL_ONE_MINUS_DST_COLOR:	return MTLBlendFactorOneMinusDestinationAlpha;
		case GL_SRC_ALPHA:				return MTLBlendFactorSourceAlpha;
		case GL_ONE_MINUS_SRC_ALPHA:	return MTLBlendFactorOneMinusSourceAlpha;
		case GL_DST_ALPHA:				return MTLBlendFactorDestinationAlpha;
		case GL_ONE_MINUS_DST_ALPHA:	return MTLBlendFactorOneMinusDestinationAlpha;
		case GL_SRC_ALPHA_SATURATE:		return MTLBlendFactorOne;
	}
	return MTLBlendFactorOne;
}

//----------------------------------------------------------------//
static MTLCompareFunction _compareFunction ( u32 glFunc ) {

	switch ( glFunc ) {
		case GL_NEVER:		return MTLCompareFunctionNever;
		case GL_LESS:		return MTLCompareFunctionLess;
		case GL_EQUAL:		return MTLCompareFunctionEqual;
		case GL_LEQUAL:		return MTLCompareFunctionLessEqual;
		case GL_GREATER:	return MTLCompareFunctionGreater;
		case GL_NOTEQUAL:	return MTLCompareFunctionNotEqual;
		case GL_GEQUAL:		return MTLCompareFunctionGreaterEqual;
		case GL_ALWAYS:		return MTLCompareFunctionAlways;
	}
	return MTLCompareFunctionAlways;
}

//================================================================//
// MOAIMetalPipelineCache
//================================================================//

//----------------------------------------------------------------//
id < MTLRenderPipelineState > MOAIMetalPipelineCache::BuildPipeline ( id < MTLDevice > device, const MOAIMetalProgram& program, const MOAIMetalVertexLayout& layout, const PipelineKey& key ) {

	MTLRenderPipelineDescriptor* desc = [[ MTLRenderPipelineDescriptor alloc ] init ];
	desc.vertexFunction = program.mVertexFunction;
	desc.fragmentFunction = program.mFragmentFunction;

	// vertex descriptor from the engine's vertex format
	MTLVertexDescriptor* vertexDesc = [ MTLVertexDescriptor vertexDescriptor ];
	for ( u32 i = 0; i < layout.mCount; ++i ) {

		const MOAIMetalVertexLayout::Attr& attr = layout.mAttrs [ i ];

		MTLVertexFormat format;
		if ( !_vertexFormatForAttr ( attr.mType, attr.mSize, attr.mNormalized, format )) {
			USLog::Print ( "MOAIGfxBackendMetal: unsupported vertex attribute type 0x%04x (size %u)\n", attr.mType, attr.mSize );
			return nil;
		}

		vertexDesc.attributes [ attr.mIndex ].format = format;
		vertexDesc.attributes [ attr.mIndex ].offset = attr.mOffset;
		vertexDesc.attributes [ attr.mIndex ].bufferIndex = MOAI_METAL_VERTEX_BUFFER_INDEX;
	}
	vertexDesc.layouts [ MOAI_METAL_VERTEX_BUFFER_INDEX ].stride = layout.mStride;
	vertexDesc.layouts [ MOAI_METAL_VERTEX_BUFFER_INDEX ].stepFunction = MTLVertexStepFunctionPerVertex;
	vertexDesc.layouts [ MOAI_METAL_VERTEX_BUFFER_INDEX ].stepRate = 1;
	desc.vertexDescriptor = vertexDesc;

	MTLRenderPipelineColorAttachmentDescriptor* color = desc.colorAttachments [ 0 ];
	color.pixelFormat = ( MTLPixelFormat )key.mColorFormat;

	if ( key.mBlendEnabled ) {

		color.blendingEnabled = YES;

		// blend equation is always ADD for GL parity: the legacy GL path
		// never applied the equation (MOAIBlendMode::Bind was dead code)
		color.rgbBlendOperation = MTLBlendOperationAdd;
		color.alphaBlendOperation = MTLBlendOperationAdd;

		color.sourceRGBBlendFactor = _blendFactorRGB ( key.mSrcFactor );
		color.destinationRGBBlendFactor = _blendFactorRGB ( key.mDstFactor );
		color.sourceAlphaBlendFactor = _blendFactorAlpha ( key.mSrcFactor );
		color.destinationAlphaBlendFactor = _blendFactorAlpha ( key.mDstFactor );
	}
	else {
		color.blendingEnabled = NO;
	}

	// depth/stencil attachment formats of the current pass
	switch (( MTLPixelFormat )key.mDepthStencilFormat ) {

		case MTLPixelFormatDepth32Float_Stencil8:
			desc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
			desc.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
			break;

		case MTLPixelFormatDepth32Float:
			desc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
			break;

		case MTLPixelFormatStencil8:
			desc.stencilAttachmentPixelFormat = MTLPixelFormatStencil8;
			break;

		default:
			break;
	}

	NSError* error = nil;
	id < MTLRenderPipelineState > pso = [ device newRenderPipelineStateWithDescriptor:desc error:&error ];

	if ( !pso ) {
		USLog::Print ( "MOAIGfxBackendMetal: render pipeline creation failed: %s\n", error ? [[ error localizedDescription ] UTF8String ] : "(unknown)" );
	}
	return pso;
}

//----------------------------------------------------------------//
id < MTLRenderPipelineState > MOAIMetalPipelineCache::GetPipeline ( id < MTLDevice > device, MOAIGfxResID programHandle, const MOAIMetalProgram& program, const MOAIMetalVertexLayout& layout, bool blendEnabled, u32 glSrcFactor, u32 glDstFactor, MTLPixelFormat colorFormat, MTLPixelFormat depthStencilFormat ) {

	PipelineKey key;
	memset ( &key, 0, sizeof ( key ));	// zero padding so memcmp ordering is stable

	key.mProgramHandle = ( u64 )programHandle;
	key.mLayoutHash = layout.mHash;
	key.mBlendEnabled = blendEnabled ? 1 : 0;
	key.mSrcFactor = blendEnabled ? glSrcFactor : 0;
	key.mDstFactor = blendEnabled ? glDstFactor : 0;
	key.mColorFormat = ( u32 )colorFormat;
	key.mDepthStencilFormat = ( u32 )depthStencilFormat;

	std::map < PipelineKey, id < MTLRenderPipelineState > >::iterator it = this->mPipelines.find ( key );
	if ( it != this->mPipelines.end ()) return it->second;

	id < MTLRenderPipelineState > pso = this->BuildPipeline ( device, program, layout, key );

	// negative results are cached too (nil) so a broken combination logs once
	this->mPipelines [ key ] = pso;
	return pso;
}

//----------------------------------------------------------------//
// NOTE on GL parity: when the depth test is DISABLED, GL bypasses depth
// writes entirely, whatever glDepthMask says. Metal would happily write
// depth with compare=Always, so a disabled depth test maps to
// Always + writes off.
id < MTLDepthStencilState > MOAIMetalPipelineCache::GetDepthStencil ( id < MTLDevice > device, u32 glDepthFuncOrZero, bool depthMask ) {

	DepthKey key;
	memset ( &key, 0, sizeof ( key ));
	key.mFunc = glDepthFuncOrZero;
	key.mMask = ( glDepthFuncOrZero && depthMask ) ? 1 : 0;

	std::map < DepthKey, id < MTLDepthStencilState > >::iterator it = this->mDepthStates.find ( key );
	if ( it != this->mDepthStates.end ()) return it->second;

	MTLDepthStencilDescriptor* desc = [[ MTLDepthStencilDescriptor alloc ] init ];
	desc.depthCompareFunction = glDepthFuncOrZero ? _compareFunction ( glDepthFuncOrZero ) : MTLCompareFunctionAlways;
	desc.depthWriteEnabled = key.mMask ? YES : NO;

	id < MTLDepthStencilState > state = [ device newDepthStencilStateWithDescriptor:desc ];
	this->mDepthStates [ key ] = state;
	return state;
}

//----------------------------------------------------------------//
id < MTLSamplerState > MOAIMetalPipelineCache::GetSampler ( id < MTLDevice > device, u32 glMinFilter, u32 glMagFilter, u32 glWrapS, u32 glWrapT ) {

	SamplerKey key;
	memset ( &key, 0, sizeof ( key ));
	key.mMinFilter = glMinFilter;
	key.mMagFilter = glMagFilter;
	key.mWrapS = glWrapS;
	key.mWrapT = glWrapT;

	std::map < SamplerKey, id < MTLSamplerState > >::iterator it = this->mSamplers.find ( key );
	if ( it != this->mSamplers.end ()) return it->second;

	MTLSamplerDescriptor* desc = [[ MTLSamplerDescriptor alloc ] init ];

	switch ( glMinFilter ) {
		case GL_NEAREST:
			desc.minFilter = MTLSamplerMinMagFilterNearest;
			desc.mipFilter = MTLSamplerMipFilterNotMipmapped;
			break;
		case GL_LINEAR:
			desc.minFilter = MTLSamplerMinMagFilterLinear;
			desc.mipFilter = MTLSamplerMipFilterNotMipmapped;
			break;
		case GL_NEAREST_MIPMAP_NEAREST:
			desc.minFilter = MTLSamplerMinMagFilterNearest;
			desc.mipFilter = MTLSamplerMipFilterNearest;
			break;
		case GL_LINEAR_MIPMAP_NEAREST:
			desc.minFilter = MTLSamplerMinMagFilterLinear;
			desc.mipFilter = MTLSamplerMipFilterNearest;
			break;
		case GL_NEAREST_MIPMAP_LINEAR:
			desc.minFilter = MTLSamplerMinMagFilterNearest;
			desc.mipFilter = MTLSamplerMipFilterLinear;
			break;
		case GL_LINEAR_MIPMAP_LINEAR:
			desc.minFilter = MTLSamplerMinMagFilterLinear;
			desc.mipFilter = MTLSamplerMipFilterLinear;
			break;
		default:
			desc.minFilter = MTLSamplerMinMagFilterLinear;
			desc.mipFilter = MTLSamplerMipFilterNotMipmapped;
			break;
	}

	desc.magFilter = ( glMagFilter == GL_NEAREST ) ? MTLSamplerMinMagFilterNearest : MTLSamplerMinMagFilterLinear;
	desc.sAddressMode = ( glWrapS == GL_REPEAT ) ? MTLSamplerAddressModeRepeat : MTLSamplerAddressModeClampToEdge;
	desc.tAddressMode = ( glWrapT == GL_REPEAT ) ? MTLSamplerAddressModeRepeat : MTLSamplerAddressModeClampToEdge;

	id < MTLSamplerState > sampler = [ device newSamplerStateWithDescriptor:desc ];
	this->mSamplers [ key ] = sampler;
	return sampler;
}

#endif

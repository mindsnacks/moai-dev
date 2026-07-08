// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#include <moaicore/pch.h>

#if defined ( MOAI_OS_OSX ) || defined ( MOAI_OS_IPHONE )

#include <moaicore/metal/MOAIMetalResources.h>
#include <uslscore/USLog.h>

//================================================================//
// MOAIMetalResources
//================================================================//

//----------------------------------------------------------------//
MOAIGfxResID MOAIMetalResources::AllocSlot () {

	if ( this->mFreeList.size ()) {
		u32 idx = this->mFreeList.back ();
		this->mFreeList.pop_back ();
		this->mSlots [ idx ] = Slot ();
		return ( MOAIGfxResID )( idx + 1 );
	}

	this->mSlots.push_back ( Slot ());
	return ( MOAIGfxResID )this->mSlots.size ();
}

//----------------------------------------------------------------//
void MOAIMetalResources::DeleteResource ( MOAIGfxResID id, NSMutableArray* graveyard ) {

	Slot* slot = this->GetSlot ( id );
	if ( !slot ) return;

	switch ( slot->mKind ) {

		case KIND_TEXTURE:
			if ( slot->mTexture ) {
				if ( slot->mTexture->mTexture )	[ graveyard addObject:slot->mTexture->mTexture ];
				if ( slot->mTexture->mSampler )	[ graveyard addObject:slot->mTexture->mSampler ];
				delete slot->mTexture;
			}
			break;

		case KIND_INDEX_BUFFER:
			if ( slot->mIndexBuffer ) {
				if ( slot->mIndexBuffer->mBuffer ) [ graveyard addObject:slot->mIndexBuffer->mBuffer ];
				delete slot->mIndexBuffer;
			}
			break;

		case KIND_PROGRAM:
			if ( slot->mProgram ) {
				if ( slot->mProgram->mVertexFunction )		[ graveyard addObject:slot->mProgram->mVertexFunction ];
				if ( slot->mProgram->mFragmentFunction )	[ graveyard addObject:slot->mProgram->mFragmentFunction ];
				delete slot->mProgram;
			}
			break;

		case KIND_RENDER_TARGET:
			if ( slot->mTarget ) {
				if ( slot->mTarget->mColor )		[ graveyard addObject:slot->mTarget->mColor ];
				if ( slot->mTarget->mDepthStencil )	[ graveyard addObject:slot->mTarget->mDepthStencil ];
				// NOTE: mColorTextureHandle is a *separate* slot holding its
				// own strong reference to the color texture; the engine
				// deletes it independently (MOAITextureBase::OnDestroy).
				delete slot->mTarget;
			}
			break;

		default:
			break;
	}

	*slot = Slot ();
	this->mFreeList.push_back (( u32 )( id - 1 ));
}

//----------------------------------------------------------------//
MOAIMetalIndexBuffer* MOAIMetalResources::GetIndexBuffer ( MOAIGfxResID id ) {

	Slot* slot = this->GetSlot ( id );
	return ( slot && ( slot->mKind == KIND_INDEX_BUFFER )) ? slot->mIndexBuffer : 0;
}

//----------------------------------------------------------------//
MOAIMetalProgram* MOAIMetalResources::GetProgram ( MOAIGfxResID id ) {

	Slot* slot = this->GetSlot ( id );
	return ( slot && ( slot->mKind == KIND_PROGRAM )) ? slot->mProgram : 0;
}

//----------------------------------------------------------------//
MOAIMetalRenderTarget* MOAIMetalResources::GetTarget ( MOAIGfxResID id ) {

	Slot* slot = this->GetSlot ( id );
	return ( slot && ( slot->mKind == KIND_RENDER_TARGET )) ? slot->mTarget : 0;
}

//----------------------------------------------------------------//
MOAIMetalTexture* MOAIMetalResources::GetTexture ( MOAIGfxResID id ) {

	Slot* slot = this->GetSlot ( id );
	return ( slot && ( slot->mKind == KIND_TEXTURE )) ? slot->mTexture : 0;
}

//----------------------------------------------------------------//
void MOAIMetalResources::SetIndexBuffer ( MOAIGfxResID id, MOAIMetalIndexBuffer* ib ) {

	Slot* slot = this->GetSlot ( id );
	if ( slot ) {
		slot->mKind = KIND_INDEX_BUFFER;
		slot->mIndexBuffer = ib;
	}
}

//----------------------------------------------------------------//
void MOAIMetalResources::SetProgram ( MOAIGfxResID id, MOAIMetalProgram* program ) {

	Slot* slot = this->GetSlot ( id );
	if ( slot ) {
		slot->mKind = KIND_PROGRAM;
		slot->mProgram = program;
	}
}

//----------------------------------------------------------------//
void MOAIMetalResources::SetTarget ( MOAIGfxResID id, MOAIMetalRenderTarget* target ) {

	Slot* slot = this->GetSlot ( id );
	if ( slot ) {
		slot->mKind = KIND_RENDER_TARGET;
		slot->mTarget = target;
	}
}

//----------------------------------------------------------------//
void MOAIMetalResources::SetTexture ( MOAIGfxResID id, MOAIMetalTexture* texture ) {

	Slot* slot = this->GetSlot ( id );
	if ( slot ) {
		slot->mKind = KIND_TEXTURE;
		slot->mTexture = texture;
	}
}

//================================================================//
// texture format helpers
//================================================================//

//----------------------------------------------------------------//
MTLPixelFormat MOAIMetalResolvePixelFormat ( u32 glFormat, u32 glPixelType, bool isCompressed ) {

	if ( isCompressed ) {
		#if defined ( MOAI_OS_IPHONE ) && defined ( GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG )
			switch ( glFormat ) {
				case GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG:	return MTLPixelFormatPVRTC_RGB_4BPP;
				case GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG:	return MTLPixelFormatPVRTC_RGBA_4BPP;
				case GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG:	return MTLPixelFormatPVRTC_RGB_2BPP;
				case GL_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG:	return MTLPixelFormatPVRTC_RGBA_2BPP;
			}
		#endif
		// PVRTC is unsupported on macOS (and unknown compressed formats
		// everywhere); the caller logs and returns 0
		return MTLPixelFormatInvalid;
	}

	switch ( glFormat ) {

		case GL_RGBA:
			// packed 4444/5551 variants are CPU-converted to RGBA8
			return MTLPixelFormatRGBA8Unorm;

		#ifdef GL_BGRA
		case GL_BGRA:
			return MTLPixelFormatBGRA8Unorm;
		#endif

		case GL_RGB:
			// 24-bit RGB and packed 565 are CPU-converted to RGBA8 (alpha = 255)
			return MTLPixelFormatRGBA8Unorm;

		case GL_ALPHA:
			// GL_ALPHA sampling yields (0,0,0,a); A8Unorm matches exactly
			return MTLPixelFormatA8Unorm;

		case GL_LUMINANCE:
			// CPU-expanded to RGBA8 (l,l,l,255): GL_LUMINANCE samples as (l,l,l,1).
			// (Chosen over R8Unorm + texture swizzle: swizzle needs macOS
			// 10.15/iOS 13, the project's deployment target is lower.)
			return MTLPixelFormatRGBA8Unorm;

		case GL_LUMINANCE_ALPHA:
			// CPU-expanded to RGBA8 (l,l,l,a): GL_LUMINANCE_ALPHA samples as (l,l,l,a)
			return MTLPixelFormatRGBA8Unorm;
	}

	UNUSED ( glPixelType );
	return MTLPixelFormatInvalid;
}

//----------------------------------------------------------------//
u32 MOAIMetalStorageBytesPerPixel ( MTLPixelFormat format ) {

	switch ( format ) {
		case MTLPixelFormatRGBA8Unorm:
		case MTLPixelFormatBGRA8Unorm:
			return 4;
		case MTLPixelFormatA8Unorm:
		case MTLPixelFormatR8Unorm:
			return 1;
		default:
			return 0;
	}
}

//----------------------------------------------------------------//
// GL packed-format channel extraction notes (glTexImage2D semantics: the
// first component named by the format occupies the MOST significant bits of
// each native-endian u16):
//   5_6_5:   R = bits 15..11, G = 10..5, B = 4..0
//   4_4_4_4: R = 15..12, G = 11..8, B = 7..4, A = 3..0
//   5_5_5_1: R = 15..11, G = 10..6, B = 5..1, A = 0
// Channel replication ((v << 3) | (v >> 2) style) matches the GL reference
// expansion to 8 bits.
const void* MOAIMetalConvertPixels ( u32 glFormat, u32 glPixelType, u32 width, u32 height, const void* src, std::vector < u8 >& scratch ) {

	if ( !src ) return 0;

	size_t count = ( size_t )width * ( size_t )height;

	if (( glFormat == GL_RGB ) && ( glPixelType == GL_UNSIGNED_BYTE )) {

		scratch.resize ( count * 4 );
		const u8* in = ( const u8* )src;
		u8* out = &scratch [ 0 ];
		for ( size_t i = 0; i < count; ++i ) {
			out [ i * 4 + 0 ] = in [ i * 3 + 0 ];
			out [ i * 4 + 1 ] = in [ i * 3 + 1 ];
			out [ i * 4 + 2 ] = in [ i * 3 + 2 ];
			out [ i * 4 + 3 ] = 0xff;
		}
		return &scratch [ 0 ];
	}

	if (( glFormat == GL_RGB ) && ( glPixelType == GL_UNSIGNED_SHORT_5_6_5 )) {

		scratch.resize ( count * 4 );
		const u16* in = ( const u16* )src;
		u8* out = &scratch [ 0 ];
		for ( size_t i = 0; i < count; ++i ) {
			u16 v = in [ i ];
			u8 r = ( v >> 11 ) & 0x1f;
			u8 g = ( v >> 5 ) & 0x3f;
			u8 b = v & 0x1f;
			out [ i * 4 + 0 ] = ( u8 )(( r << 3 ) | ( r >> 2 ));
			out [ i * 4 + 1 ] = ( u8 )(( g << 2 ) | ( g >> 4 ));
			out [ i * 4 + 2 ] = ( u8 )(( b << 3 ) | ( b >> 2 ));
			out [ i * 4 + 3 ] = 0xff;
		}
		return &scratch [ 0 ];
	}

	if (( glFormat == GL_RGBA ) && ( glPixelType == GL_UNSIGNED_SHORT_4_4_4_4 )) {

		scratch.resize ( count * 4 );
		const u16* in = ( const u16* )src;
		u8* out = &scratch [ 0 ];
		for ( size_t i = 0; i < count; ++i ) {
			u16 v = in [ i ];
			u8 r = ( v >> 12 ) & 0x0f;
			u8 g = ( v >> 8 ) & 0x0f;
			u8 b = ( v >> 4 ) & 0x0f;
			u8 a = v & 0x0f;
			out [ i * 4 + 0 ] = ( u8 )(( r << 4 ) | r );
			out [ i * 4 + 1 ] = ( u8 )(( g << 4 ) | g );
			out [ i * 4 + 2 ] = ( u8 )(( b << 4 ) | b );
			out [ i * 4 + 3 ] = ( u8 )(( a << 4 ) | a );
		}
		return &scratch [ 0 ];
	}

	if (( glFormat == GL_RGBA ) && ( glPixelType == GL_UNSIGNED_SHORT_5_5_5_1 )) {

		scratch.resize ( count * 4 );
		const u16* in = ( const u16* )src;
		u8* out = &scratch [ 0 ];
		for ( size_t i = 0; i < count; ++i ) {
			u16 v = in [ i ];
			u8 r = ( v >> 11 ) & 0x1f;
			u8 g = ( v >> 6 ) & 0x1f;
			u8 b = ( v >> 1 ) & 0x1f;
			u8 a = v & 0x01;
			out [ i * 4 + 0 ] = ( u8 )(( r << 3 ) | ( r >> 2 ));
			out [ i * 4 + 1 ] = ( u8 )(( g << 3 ) | ( g >> 2 ));
			out [ i * 4 + 2 ] = ( u8 )(( b << 3 ) | ( b >> 2 ));
			out [ i * 4 + 3 ] = a ? 0xff : 0x00;
		}
		return &scratch [ 0 ];
	}

	if (( glFormat == GL_LUMINANCE ) && ( glPixelType == GL_UNSIGNED_BYTE )) {

		scratch.resize ( count * 4 );
		const u8* in = ( const u8* )src;
		u8* out = &scratch [ 0 ];
		for ( size_t i = 0; i < count; ++i ) {
			u8 l = in [ i ];
			out [ i * 4 + 0 ] = l;
			out [ i * 4 + 1 ] = l;
			out [ i * 4 + 2 ] = l;
			out [ i * 4 + 3 ] = 0xff;
		}
		return &scratch [ 0 ];
	}

	if (( glFormat == GL_LUMINANCE_ALPHA ) && ( glPixelType == GL_UNSIGNED_BYTE )) {

		scratch.resize ( count * 4 );
		const u8* in = ( const u8* )src;
		u8* out = &scratch [ 0 ];
		for ( size_t i = 0; i < count; ++i ) {
			u8 l = in [ i * 2 + 0 ];
			u8 a = in [ i * 2 + 1 ];
			out [ i * 4 + 0 ] = l;
			out [ i * 4 + 1 ] = l;
			out [ i * 4 + 2 ] = l;
			out [ i * 4 + 3 ] = a;
		}
		return &scratch [ 0 ];
	}

	// GL_RGBA/GL_BGRA + GL_UNSIGNED_BYTE and GL_ALPHA + GL_UNSIGNED_BYTE:
	// byte layout already matches the Metal storage format
	return src;
}

//----------------------------------------------------------------//
u32 MOAIMetalMipChainCount ( u32 width, u32 height ) {

	u32 dim = width > height ? width : height;
	u32 count = 1;
	while ( dim > 1 ) {
		dim >>= 1;
		count++;
	}
	return count;
}

//================================================================//
// program creation + uniform reflection
//================================================================//

//----------------------------------------------------------------//
// Build a minimal vertex descriptor compatible with the vertex function's
// declared [[stage_in]] attributes: each attribute laid out tightly packed
// (in attribute-index order) in buffer 30. This descriptor exists only to
// let the reflection PSO build; the real per-draw descriptors come from the
// engine's MOAIVertexFormat.
static MTLVertexDescriptor* _reflectionVertexDescriptor ( id < MTLFunction > vertexFunction ) {

	NSArray < MTLVertexAttribute* >* attrs = [ vertexFunction vertexAttributes ];
	if ( !attrs || ![ attrs count ]) return nil;

	// sort by attribute index for a deterministic packing
	NSArray < MTLVertexAttribute* >* sorted = [ attrs sortedArrayUsingComparator:^NSComparisonResult ( MTLVertexAttribute* a, MTLVertexAttribute* b ) {
		if ( a.attributeIndex < b.attributeIndex ) return NSOrderedAscending;
		if ( a.attributeIndex > b.attributeIndex ) return NSOrderedDescending;
		return NSOrderedSame;
	}];

	MTLVertexDescriptor* desc = [ MTLVertexDescriptor vertexDescriptor ];
	NSUInteger offset = 0;

	for ( MTLVertexAttribute* attr in sorted ) {

		MTLVertexFormat format;
		NSUInteger size;

		switch ( attr.attributeType ) {
			case MTLDataTypeFloat:		format = MTLVertexFormatFloat;		size = 4;	break;
			case MTLDataTypeFloat2:		format = MTLVertexFormatFloat2;		size = 8;	break;
			case MTLDataTypeFloat3:		format = MTLVertexFormatFloat3;		size = 12;	break;
			case MTLDataTypeFloat4:		format = MTLVertexFormatFloat4;		size = 16;	break;
			case MTLDataTypeInt:		format = MTLVertexFormatInt;		size = 4;	break;
			case MTLDataTypeInt2:		format = MTLVertexFormatInt2;		size = 8;	break;
			case MTLDataTypeInt4:		format = MTLVertexFormatInt4;		size = 16;	break;
			case MTLDataTypeUInt:		format = MTLVertexFormatUInt;		size = 4;	break;
			case MTLDataTypeUInt2:		format = MTLVertexFormatUInt2;		size = 8;	break;
			case MTLDataTypeUInt4:		format = MTLVertexFormatUInt4;		size = 16;	break;
			default:					format = MTLVertexFormatFloat4;		size = 16;	break;
		}

		NSUInteger idx = attr.attributeIndex;
		desc.attributes [ idx ].format = format;
		desc.attributes [ idx ].offset = offset;
		desc.attributes [ idx ].bufferIndex = 30;
		offset += size;
	}

	desc.layouts [ 30 ].stride = offset ? offset : 4;
	desc.layouts [ 30 ].stepFunction = MTLVertexStepFunctionPerVertex;
	desc.layouts [ 30 ].stepRate = 1;

	return desc;
}

//----------------------------------------------------------------//
static void _harvestUniformStruct ( NSArray < MTLArgument* >* args, std::map < std::string, MOAIMetalUniformMember >& members, std::vector < u8 >& block ) {

	for ( MTLArgument* arg in args ) {

		if ( arg.type != MTLArgumentTypeBuffer ) continue;
		if ( arg.index != 0 ) continue;

		MTLStructType* structType = arg.bufferStructType;
		if ( !structType ) continue;

		// CPU shadow block: calloc-equivalent zero fill (GLSL zero-inits
		// uniforms; content relies on it)
		block.assign (( size_t )arg.bufferDataSize, 0 );

		for ( MTLStructMember* member in structType.members ) {
			MOAIMetalUniformMember entry;
			entry.mOffset = ( u32 )member.offset;
			entry.mDataType = member.dataType;
			members [ std::string ([ member.name UTF8String ])] = entry;
		}
	}
}

//----------------------------------------------------------------//
MOAIMetalProgram* MOAIMetalCreateProgram ( id < MTLDevice > device, const char* vshMSL, const char* fshMSL ) {

	if ( !device ) return 0;

	MTLCompileOptions* options = [[ MTLCompileOptions alloc ] init ];

	// IMPORTANT for fidelity: content shaders divide by possibly-zero values
	// in unselected ternary branches; fast math would allow the compiler to
	// break those
	options.fastMathEnabled = NO;

	NSError* error = nil;

	id < MTLLibrary > vshLib = [ device newLibraryWithSource:[ NSString stringWithUTF8String:vshMSL ] options:options error:&error ];
	if ( !vshLib ) {
		USLog::Print ( "MOAIGfxBackendMetal: vertex shader compile failed: %s\n", error ? [[ error localizedDescription ] UTF8String ] : "(unknown)" );
		return 0;
	}

	error = nil;
	id < MTLLibrary > fshLib = [ device newLibraryWithSource:[ NSString stringWithUTF8String:fshMSL ] options:options error:&error ];
	if ( !fshLib ) {
		USLog::Print ( "MOAIGfxBackendMetal: fragment shader compile failed: %s\n", error ? [[ error localizedDescription ] UTF8String ] : "(unknown)" );
		return 0;
	}

	id < MTLFunction > vertexFunction = [ vshLib newFunctionWithName:@"vertexMain" ];
	id < MTLFunction > fragmentFunction = [ fshLib newFunctionWithName:@"fragmentMain" ];

	if ( !vertexFunction || !fragmentFunction ) {
		USLog::Print ( "MOAIGfxBackendMetal: shader is missing a vertexMain/fragmentMain entry point\n" );
		return 0;
	}

	// build a throwaway PSO purely to obtain reflection info for the
	// buffer(0) uniform structs of both stages
	MTLRenderPipelineDescriptor* desc = [[ MTLRenderPipelineDescriptor alloc ] init ];
	desc.vertexFunction = vertexFunction;
	desc.fragmentFunction = fragmentFunction;
	desc.vertexDescriptor = _reflectionVertexDescriptor ( vertexFunction );
	desc.colorAttachments [ 0 ].pixelFormat = MTLPixelFormatRGBA8Unorm;

	MTLRenderPipelineReflection* reflection = nil;
	error = nil;

	id < MTLRenderPipelineState > pso = [ device
		newRenderPipelineStateWithDescriptor:desc
		options:( MTLPipelineOptionArgumentInfo | MTLPipelineOptionBufferTypeInfo )
		reflection:&reflection
		error:&error ];

	if ( !pso || !reflection ) {
		USLog::Print ( "MOAIGfxBackendMetal: shader reflection pipeline failed: %s\n", error ? [[ error localizedDescription ] UTF8String ] : "(unknown)" );
		return 0;
	}

	MOAIMetalProgram* program = new MOAIMetalProgram ();
	program->mVertexFunction = vertexFunction;
	program->mFragmentFunction = fragmentFunction;

	_harvestUniformStruct ( reflection.vertexArguments, program->mVsMembers, program->mVsBlock );
	_harvestUniformStruct ( reflection.fragmentArguments, program->mFsMembers, program->mFsBlock );

	return program;
}

#endif

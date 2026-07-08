// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#include <moaicore/pch.h>

#if defined ( MOAI_OS_OSX ) || defined ( MOAI_OS_IPHONE )

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#include <atomic>

#include <moaicore/MOAIGfxDevice.h>
#include <moaicore/MOAIFrameBuffer.h>
#include <moaicore/MOAIShader.h>
#include <moaicore/MOAIVertexFormat.h>
#include <moaicore/metal/MOAIGfxBackendMetal.h>
#include <moaicore/metal/MOAIMetalPipelineCache.h>
#include <moaicore/metal/MOAIMetalResources.h>
#include <moaicore/metal/MOAIMetalRingBuffer.h>
#include <uslscore/USLog.h>

// CAMetalLayer* stored by AKUMetalSetLayer (defined in AKU.cpp)
extern void* gAKUMetalLayer;

//----------------------------------------------------------------//
#define MOAI_METAL_LOG_ONCE(...)					\
	{												\
		static bool _logged = false;				\
		if ( !_logged ) {							\
			_logged = true;							\
			USLog::Print ( __VA_ARGS__ );			\
		}											\
	}

//================================================================//
// COORDINATE SYSTEM INVARIANT (fidelity-critical)
//================================================================//
//
// Vertices arrive in GL clip space (the engine CPU-transforms all vertices;
// built-in vertex shaders are pass-throughs). Every MSL vertex function ends
// with:
//
//     p.y *= pass.yFlip;
//     p.z = ( p.z + p.w ) * 0.5;    // GL depth range [-w,w] -> Metal [0,w]
//
// DEFAULT CANVAS (SetFrameBuffer ( 0 ), yFlip = +1, "top-down"):
//   GL's default framebuffer has row 0 at the window bottom; glReadPixels
//   returns rows bottom-up, and MOAIGfxBackendGL flips them so the seam
//   contract is TOP-DOWN rows. Rendering GL clip space vertices with Metal's
//   default conventions (NDC +y up, texture row 0 = top) writes the visual
//   TOP of the scene to row 0 - i.e. the canvas texture is already stored
//   top-down. Therefore:
//     - the canvas pass uses yFlip = +1 (no change),
//     - the canvas -> drawable present quad is an identity mapping,
//     - ReadPixelsRGBA8 on the canvas is a straight row copy.
//
// OFFSCREEN TARGETS (MOAIFrameBufferTexture, yFlip = -1, "bottom-up"):
//   GL leaves offscreen renders BOTTOM-UP in texture memory (row 0 = visual
//   bottom) and content UVs compensate. To reproduce that byte layout with
//   Metal (which always writes the NDC top to row 0) the pass flips NDC y
//   (yFlip = -1): the visual bottom then lands on row 0, matching GL.
//     - sampling with content UVs works unchanged,
//     - ReadPixelsRGBA8 flips rows (bottom-up -> top-down contract), which
//       is exactly what MOAIGfxBackendGL::ReadPixelsRGBA8 does after
//       glReadPixels,
//     - the NDC flip mirrors triangle winding, so when culling is enabled
//       the front-face winding is inverted (GL front = CCW; flipped passes
//       use clockwise).
//
// VIEWPORT / SCISSOR (arrive in GL window coords, origin bottom-left, as
// produced by MOAIFrameBuffer::WndRectToDevice):
//   canvas (top-down):     y_mtl = H - ( y_gl + h )
//   offscreen (bottom-up): y_mtl = y_gl   (the NDC flip re-orients content
//                          within the viewport; the rect itself addresses
//                          the same memory rows GL would)
//
// Worked examples:
//   canvas H = 480, GL scissor y = 0, h = 100 (bottom strip of the window)
//     -> y_mtl = 480 - (0 + 100) = 380: the bottom strip of a top-down
//        image. Correct.
//   offscreen H = 256, GL scissor y = 0, h = 50 (memory rows 0..49, which
//   GL fills with the visual bottom)
//     -> y_mtl = 0: rows 0..49; the yFlip = -1 render also places the
//        visual bottom there. Correct.
//================================================================//

//================================================================//
// present shader (canvas -> drawable fullscreen triangle)
//================================================================//
// A blit cannot convert RGBA8 -> BGRA8, so the canvas is drawn onto the
// drawable with a tiny private pipeline. The canvas is stored top-down, so
// the quad is an identity mapping: uv ( 0, 0 ) = NDC ( -1, +1 ) = top-left.
static const char* _presentShaderMSL =
	"#include <metal_stdlib>\n"
	"using namespace metal;\n"
	"struct PresentOut {\n"
	"	float4 position [[ position ]];\n"
	"	float2 uv;\n"
	"};\n"
	"vertex PresentOut vertexMain ( uint vid [[ vertex_id ]] ) {\n"
	"	float2 pos [ 3 ] = { float2 ( -1.0, -1.0 ), float2 ( 3.0, -1.0 ), float2 ( -1.0, 3.0 ) };\n"
	"	PresentOut out;\n"
	"	out.position = float4 ( pos [ vid ], 0.0, 1.0 );\n"
	"	out.uv = float2 (( pos [ vid ].x + 1.0 ) * 0.5, ( 1.0 - pos [ vid ].y ) * 0.5 );\n"
	"	return out;\n"
	"}\n"
	"fragment float4 fragmentMain ( PresentOut in [[ stage_in ]], texture2d < float > tex [[ texture ( 0 ) ]], sampler smp [[ sampler ( 0 ) ]] ) {\n"
	"	return tex.sample ( smp, in.uv );\n"
	"}\n";

//================================================================//
// MOAIMetalContext
//================================================================//

struct MOAIMetalContext {

	static const u32 MAX_UNITS = 16;

	//----------------------------------------------------------------//
	// device / frame lifecycle
	id < MTLDevice >				mDevice;
	id < MTLCommandQueue >			mQueue;
	CAMetalLayer*					mLayer;
	void*							mLayerRaw;			// last seen gAKUMetalLayer value

	dispatch_semaphore_t			mFrameSem;			// two frames in flight
	id < MTLCommandBuffer >			mCmdBuffer;
	id < MTLRenderCommandEncoder >	mEncoder;
	bool							mInFrame;
	u64								mFrameSerial;
	std::atomic < u64 >				mCompletedSerial;	// last completed frame (set by completion handlers)

	MOAIMetalRingBuffer				mRing;
	MOAIMetalResources				mResources;
	MOAIMetalPipelineCache			mPipelines;

	// deferred ObjC releases; handed to the frame's completed handler
	NSMutableArray*					mGraveyard;

	//----------------------------------------------------------------//
	// persistent canvas (the "default framebuffer")
	id < MTLTexture >				mCanvasColor;
	id < MTLTexture >				mCanvasDepthStencil;
	u32								mCanvasWidth;
	u32								mCanvasHeight;

	//----------------------------------------------------------------//
	// pending pass (render target + deferred load actions)
	bool							mPassIsCanvas;
	bool							mPassFlipped;		// true = bottom-up offscreen target (yFlip = -1)
	id < MTLTexture >				mPassColor;
	id < MTLTexture >				mPassDepthStencil;
	u32								mPassWidth;
	u32								mPassHeight;
	MTLLoadAction					mColorLoad;
	MTLLoadAction					mDepthLoad;
	MTLLoadAction					mStencilLoad;
	MTLClearColor					mClearColor;
	bool							mClearPending;		// a recorded Clear () not yet realized by an encoder

	//----------------------------------------------------------------//
	// shadow state (master copy; replayed onto each new encoder)
	bool							mScissorEnabled;
	int								mScissorRect [ 4 ];		// GL window coords
	bool							mViewportSet;
	int								mViewportRect [ 4 ];	// GL window coords
	bool							mBlendEnabled;
	u32								mBlendSrc;
	u32								mBlendDst;
	u32								mDepthFunc;
	bool							mDepthMask;
	u32								mCullMode;
	float							mLineWidth;
	float							mPointSize;

	MOAIGfxResID					mUnitTexture [ MAX_UNITS ];
	MOAIGfxResID					mCurrentProgram;

	//----------------------------------------------------------------//
	// encoder-local applied state
	id < MTLRenderPipelineState >	mEncPipeline;
	id < MTLDepthStencilState >		mEncDepthState;
	MOAIGfxResID					mEncTexture [ MAX_UNITS ];
	id < MTLSamplerState >			mEncSampler [ MAX_UNITS ];
	bool							mEncScissorEmpty;	// GL empty scissor = discard all draws

	//----------------------------------------------------------------//
	// present pipeline
	id < MTLRenderPipelineState >	mPresentPSO;
	MTLPixelFormat					mPresentFormat;
	id < MTLSamplerState >			mPresentSampler;
	id < MTLSamplerState >			mDefaultSampler;

	//----------------------------------------------------------------//
	MOAIMetalContext () :
		mDevice ( nil ),
		mQueue ( nil ),
		mLayer ( nil ),
		mLayerRaw ( 0 ),
		mFrameSem ( 0 ),
		mCmdBuffer ( nil ),
		mEncoder ( nil ),
		mInFrame ( false ),
		mFrameSerial ( 0 ),
		mCompletedSerial ( 0 ),
		mGraveyard ( nil ),
		mCanvasColor ( nil ),
		mCanvasDepthStencil ( nil ),
		mCanvasWidth ( 0 ),
		mCanvasHeight ( 0 ),
		mPassIsCanvas ( true ),
		mPassFlipped ( false ),
		mPassColor ( nil ),
		mPassDepthStencil ( nil ),
		mPassWidth ( 0 ),
		mPassHeight ( 0 ),
		mColorLoad ( MTLLoadActionLoad ),
		mDepthLoad ( MTLLoadActionLoad ),
		mStencilLoad ( MTLLoadActionLoad ),
		mClearPending ( false ),
		mScissorEnabled ( false ),
		mViewportSet ( false ),
		mBlendEnabled ( false ),
		mBlendSrc ( 0 ),
		mBlendDst ( 0 ),
		mDepthFunc ( 0 ),
		mDepthMask ( true ),
		mCullMode ( 0 ),
		mLineWidth ( 1.0f ),
		mPointSize ( 1.0f ),
		mCurrentProgram ( 0 ),
		mEncPipeline ( nil ),
		mEncDepthState ( nil ),
		mEncScissorEmpty ( false ),
		mPresentPSO ( nil ),
		mPresentFormat ( MTLPixelFormatInvalid ),
		mPresentSampler ( nil ),
		mDefaultSampler ( nil ) {

		this->mClearColor = MTLClearColorMake ( 0.0, 0.0, 0.0, 0.0 );

		for ( u32 i = 0; i < MAX_UNITS; ++i ) {
			this->mUnitTexture [ i ] = 0;
			this->mEncTexture [ i ] = ( MOAIGfxResID )-1;
			this->mEncSampler [ i ] = nil;
		}
		for ( u32 i = 0; i < 4; ++i ) {
			this->mScissorRect [ i ] = 0;
			this->mViewportRect [ i ] = 0;
		}
	}

	//----------------------------------------------------------------//
	bool EnsureDevice () {

		// pick up (or refresh) the layer installed via AKUMetalSetLayer
		if ( gAKUMetalLayer != this->mLayerRaw ) {
			this->mLayerRaw = gAKUMetalLayer;
			this->mLayer = ( __bridge CAMetalLayer* )gAKUMetalLayer;
			if ( this->mLayer && this->mDevice && !this->mLayer.device ) {
				this->mLayer.device = this->mDevice;
			}
		}

		if ( this->mDevice ) return true;

		id < MTLDevice > device = this->mLayer ? this->mLayer.device : nil;
		if ( !device ) {
			device = MTLCreateSystemDefaultDevice ();
		}
		if ( !device ) {
			MOAI_METAL_LOG_ONCE ( "MOAIGfxBackendMetal: no Metal device available\n" )
			return false;
		}

		this->mDevice = device;
		this->mQueue = [ device newCommandQueue ];
		this->mRing.SetDevice ( device );
		this->mFrameSem = dispatch_semaphore_create ( 2 );
		this->mGraveyard = [ NSMutableArray array ];

		if ( this->mLayer && !this->mLayer.device ) {
			this->mLayer.device = device;
		}
		return true;
	}

	//----------------------------------------------------------------//
	// (re)create the canvas at the engine's current view size. Lazy: called
	// at SetFrameBuffer ( 0 ) and at deferred encoder creation.
	bool EnsureCanvas () {

		if ( !this->EnsureDevice ()) return false;

		u32 width = 0;
		u32 height = 0;

		MOAIFrameBuffer* defaultBuffer = MOAIGfxDevice::Get ().GetDefaultBuffer ();
		if ( defaultBuffer ) {
			width = defaultBuffer->GetBufferWidth ();
			height = defaultBuffer->GetBufferHeight ();
		}

		if ( !( width && height ) && this->mLayer ) {
			CGSize size = this->mLayer.drawableSize;
			width = ( u32 )size.width;
			height = ( u32 )size.height;
		}

		if ( !( width && height )) return false;

		if ( this->mCanvasColor && ( this->mCanvasWidth == width ) && ( this->mCanvasHeight == height )) {
			return true;
		}

		// graveyard the old canvas (may be referenced by in-flight frames)
		if ( this->mCanvasColor )		[ this->mGraveyard addObject:this->mCanvasColor ];
		if ( this->mCanvasDepthStencil )[ this->mGraveyard addObject:this->mCanvasDepthStencil ];
		this->mCanvasColor = nil;
		this->mCanvasDepthStencil = nil;

		MTLTextureDescriptor* colorDesc = [ MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:width height:height mipmapped:NO ];
		colorDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
		colorDesc.storageMode = MTLStorageModePrivate;
		this->mCanvasColor = [ this->mDevice newTextureWithDescriptor:colorDesc ];

		// GL default framebuffers come with depth (and usually stencil);
		// give the canvas both so depth-tested content works
		MTLTextureDescriptor* dsDesc = [ MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float_Stencil8 width:width height:height mipmapped:NO ];
		dsDesc.usage = MTLTextureUsageRenderTarget;
		dsDesc.storageMode = MTLStorageModePrivate;
		this->mCanvasDepthStencil = [ this->mDevice newTextureWithDescriptor:dsDesc ];

		this->mCanvasWidth = width;
		this->mCanvasHeight = height;

		if ( !this->mCanvasColor ) return false;

		// fresh canvas contents are undefined in GL too, but garbage would
		// differ run to run; clear once on creation
		if ( this->mPassIsCanvas ) {
			this->mPassColor = this->mCanvasColor;
			this->mPassDepthStencil = this->mCanvasDepthStencil;
			this->mPassWidth = width;
			this->mPassHeight = height;
			if ( this->mColorLoad == MTLLoadActionLoad ) {
				this->mColorLoad = MTLLoadActionClear;
				this->mClearColor = MTLClearColorMake ( 0.0, 0.0, 0.0, 0.0 );
				this->mClearPending = true;
			}
		}
		return true;
	}
};

//================================================================//
// MOAIGfxBackendMetal - local helpers
//================================================================//

//================================================================//
// MOAIGfxBackendMetal
//================================================================//

//----------------------------------------------------------------//
MOAIGfxBackendMetal::MOAIGfxBackendMetal () {

	this->mCtx = new MOAIMetalContext ();
}

//----------------------------------------------------------------//
MOAIGfxBackendMetal::~MOAIGfxBackendMetal () {

	MOAIMetalContext& ctx = *this->mCtx;

	if ( ctx.mEncoder ) {
		[ ctx.mEncoder endEncoding ];
		ctx.mEncoder = nil;
	}
	if ( ctx.mCmdBuffer ) {
		[ ctx.mCmdBuffer commit ];
		[ ctx.mCmdBuffer waitUntilCompleted ];
		ctx.mCmdBuffer = nil;
	}

	// drain in-flight frames so their completed handlers (which touch ctx)
	// have run before ctx is freed. If a frame was begun but never ended its
	// slot never signals; the timeout covers that (and process teardown).
	if ( ctx.mFrameSem && ctx.mFrameSerial ) {
		dispatch_semaphore_wait ( ctx.mFrameSem, dispatch_time ( DISPATCH_TIME_NOW, NSEC_PER_SEC ));
		dispatch_semaphore_wait ( ctx.mFrameSem, dispatch_time ( DISPATCH_TIME_NOW, NSEC_PER_SEC ));
	}

	delete this->mCtx;
	this->mCtx = 0;
}

//----------------------------------------------------------------//
MOAIGfxBackend::Backend MOAIGfxBackendMetal::GetBackendID () const {

	return BACKEND_METAL;
}

//----------------------------------------------------------------//
bool MOAIGfxBackendMetal::DetectContext ( MOAIGfxCaps& caps ) {

	MOAIMetalContext& ctx = *this->mCtx;
	bool hasDevice = ctx.EnsureDevice ();

	// report a GL-2.0-equivalent programmable context: MOAIGfxDevice keys
	// mIsProgrammable off major >= 2
	caps.mIsOpenGLES				= false;
	caps.mMajorVersion				= 2;
	caps.mMinorVersion				= 0;
	caps.mIsProgrammable			= true;
	caps.mIsFramebufferSupported	= true;
	caps.mMaxTextureUnits			= MOAIMetalContext::MAX_UNITS;
	caps.mMaxTextureSize			= 8192;

	return hasDevice;
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::BeginFrame () {

	MOAIMetalContext& ctx = *this->mCtx;

	@autoreleasepool {

		if ( !ctx.EnsureDevice ()) return;
		if ( ctx.mInFrame ) return;		// unbalanced BeginFrame; keep the current frame

		// two frames in flight: block until frame N-2 has completed. This
		// also makes it safe for the ring buffer to rewind slot N & 1.
		dispatch_semaphore_wait ( ctx.mFrameSem, DISPATCH_TIME_FOREVER );

		ctx.mFrameSerial++;
		ctx.mRing.BeginFrame (( u32 )( ctx.mFrameSerial & 1 ));

		ctx.mCmdBuffer = [ ctx.mQueue commandBuffer ];
		ctx.mInFrame = true;
		ctx.mEncoder = nil;

		// default target until the engine's first SetFrameBuffer
		ctx.mPassIsCanvas = true;
		ctx.mPassFlipped = false;
		ctx.mPassColor = ctx.mCanvasColor;
		ctx.mPassDepthStencil = ctx.mCanvasDepthStencil;
		ctx.mPassWidth = ctx.mCanvasWidth;
		ctx.mPassHeight = ctx.mCanvasHeight;
		ctx.mColorLoad = MTLLoadActionLoad;
		ctx.mDepthLoad = MTLLoadActionLoad;
		ctx.mStencilLoad = MTLLoadActionLoad;
		ctx.mClearPending = false;
	}
}

//================================================================//
// encoder / pass management
//================================================================//

//----------------------------------------------------------------//
// Convert + apply the shadow viewport onto the open encoder (see the
// coordinate invariant at the top of this file).
static void _applyViewport ( MOAIMetalContext& ctx ) {

	MTLViewport vp;

	if ( ctx.mViewportSet ) {
		double h = ( double )ctx.mViewportRect [ 3 ];
		vp.originX = ( double )ctx.mViewportRect [ 0 ];
		vp.originY = ctx.mPassFlipped ? ( double )ctx.mViewportRect [ 1 ] : ( double )ctx.mPassHeight - (( double )ctx.mViewportRect [ 1 ] + h );
		vp.width = ( double )ctx.mViewportRect [ 2 ];
		vp.height = h;
	}
	else {
		vp.originX = 0.0;
		vp.originY = 0.0;
		vp.width = ( double )ctx.mPassWidth;
		vp.height = ( double )ctx.mPassHeight;
	}
	vp.znear = 0.0;
	vp.zfar = 1.0;

	[ ctx.mEncoder setViewport:vp ];
}

//----------------------------------------------------------------//
// Convert, clamp and apply the shadow scissor. GL silently clamps the
// scissor box to the target; Metal validates hard, so clamp here. An empty
// (fully clipped) scissor discards all draws in GL - model that by skipping
// draws while mEncScissorEmpty is set.
static void _applyScissor ( MOAIMetalContext& ctx ) {

	s64 x, y, w, h;

	if ( ctx.mScissorEnabled ) {
		x = ctx.mScissorRect [ 0 ];
		w = ctx.mScissorRect [ 2 ];
		h = ctx.mScissorRect [ 3 ];
		y = ctx.mPassFlipped ? ( s64 )ctx.mScissorRect [ 1 ] : ( s64 )ctx.mPassHeight - (( s64 )ctx.mScissorRect [ 1 ] + h );
	}
	else {
		x = 0;
		y = 0;
		w = ( s64 )ctx.mPassWidth;
		h = ( s64 )ctx.mPassHeight;
	}

	s64 x0 = x < 0 ? 0 : x;
	s64 y0 = y < 0 ? 0 : y;
	s64 x1 = x + w;
	s64 y1 = y + h;
	if ( x1 > ( s64 )ctx.mPassWidth )	x1 = ( s64 )ctx.mPassWidth;
	if ( y1 > ( s64 )ctx.mPassHeight )	y1 = ( s64 )ctx.mPassHeight;

	if (( x1 <= x0 ) || ( y1 <= y0 )) {
		// empty scissor: GL discards everything; park a 1x1 scissor and
		// skip draws instead (Metal dislikes zero-sized rects)
		ctx.mEncScissorEmpty = true;
		MTLScissorRect rect = { 0, 0, 1, 1 };
		[ ctx.mEncoder setScissorRect:rect ];
		return;
	}

	ctx.mEncScissorEmpty = false;
	MTLScissorRect rect = {( NSUInteger )x0, ( NSUInteger )y0, ( NSUInteger )( x1 - x0 ), ( NSUInteger )( y1 - y0 )};
	[ ctx.mEncoder setScissorRect:rect ];
}

//----------------------------------------------------------------//
static void _applyDepth ( MOAIMetalContext& ctx ) {

	// GL semantics: without a depth attachment the depth test always passes
	// and the depth buffer is never written
	bool hasDepth = ( ctx.mPassDepthStencil != nil );
	u32 func = hasDepth ? ctx.mDepthFunc : 0;
	bool mask = hasDepth ? ctx.mDepthMask : false;

	id < MTLDepthStencilState > state = ctx.mPipelines.GetDepthStencil ( ctx.mDevice, func, mask );
	if ( state && ( state != ctx.mEncDepthState )) {
		[ ctx.mEncoder setDepthStencilState:state ];
		ctx.mEncDepthState = state;
	}
}

//----------------------------------------------------------------//
static void _applyCull ( MOAIMetalContext& ctx ) {

	// GL default front face is CCW; the NDC y-flip on offscreen passes
	// mirrors winding, so flipped passes invert the front face
	[ ctx.mEncoder setFrontFacingWinding:( ctx.mPassFlipped ? MTLWindingClockwise : MTLWindingCounterClockwise )];

	MTLCullMode mode = MTLCullModeNone;
	switch ( ctx.mCullMode ) {
		case 0:					mode = MTLCullModeNone;		break;
		case GL_FRONT:			mode = MTLCullModeFront;	break;
		case GL_BACK:			mode = MTLCullModeBack;		break;
		case GL_FRONT_AND_BACK:
			// GL_FRONT_AND_BACK culls ALL triangles; Metal has no equivalent
			MOAI_METAL_LOG_ONCE ( "MOAIGfxBackendMetal: GL_FRONT_AND_BACK culling not supported; using GL_BACK\n" )
			mode = MTLCullModeBack;
			break;
		default:				mode = MTLCullModeNone;		break;
	}
	[ ctx.mEncoder setCullMode:mode ];
}

//----------------------------------------------------------------//
// Deferred encoder creation: build the encoder from the pending pass
// descriptor, then immediately replay the shadow state onto it.
static bool _ensureEncoder ( MOAIMetalContext& ctx ) {

	if ( ctx.mEncoder ) return true;
	if ( !ctx.mCmdBuffer ) return false;	// outside BeginFrame/EndFrame

	if ( !ctx.mPassColor ) {
		if ( !( ctx.mPassIsCanvas && ctx.EnsureCanvas ())) return false;
		ctx.mPassColor = ctx.mCanvasColor;
		ctx.mPassDepthStencil = ctx.mCanvasDepthStencil;
		ctx.mPassWidth = ctx.mCanvasWidth;
		ctx.mPassHeight = ctx.mCanvasHeight;
	}

	@autoreleasepool {

		MTLRenderPassDescriptor* desc = [[ MTLRenderPassDescriptor alloc ] init ];

		desc.colorAttachments [ 0 ].texture = ctx.mPassColor;
		desc.colorAttachments [ 0 ].loadAction = ctx.mColorLoad;
		desc.colorAttachments [ 0 ].storeAction = MTLStoreActionStore;
		desc.colorAttachments [ 0 ].clearColor = ctx.mClearColor;

		if ( ctx.mPassDepthStencil ) {

			MTLPixelFormat dsFormat = ctx.mPassDepthStencil.pixelFormat;
			bool hasDepth = ( dsFormat == MTLPixelFormatDepth32Float ) || ( dsFormat == MTLPixelFormatDepth32Float_Stencil8 );
			bool hasStencil = ( dsFormat == MTLPixelFormatStencil8 ) || ( dsFormat == MTLPixelFormatDepth32Float_Stencil8 );

			if ( hasDepth ) {
				desc.depthAttachment.texture = ctx.mPassDepthStencil;
				desc.depthAttachment.loadAction = ctx.mDepthLoad;
				desc.depthAttachment.storeAction = MTLStoreActionStore;
				desc.depthAttachment.clearDepth = 1.0;		// glClearDepth default
			}
			if ( hasStencil ) {
				desc.stencilAttachment.texture = ctx.mPassDepthStencil;
				desc.stencilAttachment.loadAction = ctx.mStencilLoad;
				desc.stencilAttachment.storeAction = MTLStoreActionStore;
				desc.stencilAttachment.clearStencil = 0;	// glClearStencil default
			}
		}

		ctx.mEncoder = [ ctx.mCmdBuffer renderCommandEncoderWithDescriptor:desc ];
	}

	if ( !ctx.mEncoder ) return false;

	// the pending clears are consumed; later encoders on this target load
	ctx.mColorLoad = MTLLoadActionLoad;
	ctx.mDepthLoad = MTLLoadActionLoad;
	ctx.mStencilLoad = MTLLoadActionLoad;
	ctx.mClearPending = false;

	// reset encoder-local applied state
	ctx.mEncPipeline = nil;
	ctx.mEncDepthState = nil;
	ctx.mEncScissorEmpty = false;
	for ( u32 i = 0; i < MOAIMetalContext::MAX_UNITS; ++i ) {
		ctx.mEncTexture [ i ] = ( MOAIGfxResID )-1;
		ctx.mEncSampler [ i ] = nil;
	}

	// replay shadow state
	_applyViewport ( ctx );
	_applyScissor ( ctx );
	_applyDepth ( ctx );
	_applyCull ( ctx );

	// pass uniforms: yFlip (see coordinate invariant)
	float yFlip = ctx.mPassFlipped ? -1.0f : 1.0f;
	[ ctx.mEncoder setVertexBytes:&yFlip length:sizeof ( yFlip ) atIndex:1 ];
	[ ctx.mEncoder setFragmentBytes:&yFlip length:sizeof ( yFlip ) atIndex:1 ];

	return true;
}

//----------------------------------------------------------------//
static void _endEncoder ( MOAIMetalContext& ctx ) {

	if ( ctx.mEncoder ) {
		[ ctx.mEncoder endEncoding ];
		ctx.mEncoder = nil;
	}
}

//----------------------------------------------------------------//
// End the current pass; if a Clear () was recorded but no draw ever opened
// an encoder, open + close an empty one so the clear still takes effect.
static void _finishPendingPass ( MOAIMetalContext& ctx ) {

	if ( ctx.mEncoder ) {
		_endEncoder ( ctx );
		return;
	}
	if ( ctx.mClearPending && ctx.mCmdBuffer ) {
		if ( _ensureEncoder ( ctx )) {
			_endEncoder ( ctx );
		}
	}
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::EndFrame () {

	MOAIMetalContext& ctx = *this->mCtx;
	if ( !ctx.mCmdBuffer ) return;

	@autoreleasepool {

		_finishPendingPass ( ctx );

		// present the canvas: acquire the drawable LATE and skip the whole
		// present if it is unavailable (the canvas retains the frame; the
		// next present shows it)
		ctx.EnsureDevice ();

		if ( ctx.mLayer && ctx.mCanvasColor ) {

			id < CAMetalDrawable > drawable = [ ctx.mLayer nextDrawable ];
			if ( drawable ) {

				MTLPixelFormat drawableFormat = drawable.texture.pixelFormat;

				if ( !ctx.mPresentPSO || ( ctx.mPresentFormat != drawableFormat )) {

					ctx.mPresentPSO = nil;
					MOAIMetalProgram* presentProg = MOAIMetalCreateProgram ( ctx.mDevice, _presentShaderMSL, _presentShaderMSL );
					if ( presentProg ) {
						MTLRenderPipelineDescriptor* desc = [[ MTLRenderPipelineDescriptor alloc ] init ];
						desc.vertexFunction = presentProg->mVertexFunction;
						desc.fragmentFunction = presentProg->mFragmentFunction;
						desc.colorAttachments [ 0 ].pixelFormat = drawableFormat;
						NSError* error = nil;
						ctx.mPresentPSO = [ ctx.mDevice newRenderPipelineStateWithDescriptor:desc error:&error ];
						if ( !ctx.mPresentPSO ) {
							MOAI_METAL_LOG_ONCE ( "MOAIGfxBackendMetal: present pipeline failed: %s\n", error ? [[ error localizedDescription ] UTF8String ] : "(unknown)" )
						}
						ctx.mPresentFormat = drawableFormat;
						delete presentProg;
					}
					if ( !ctx.mPresentSampler ) {
						ctx.mPresentSampler = ctx.mPipelines.GetSampler ( ctx.mDevice, GL_LINEAR, GL_LINEAR, GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE );
					}
				}

				if ( ctx.mPresentPSO ) {

					MTLRenderPassDescriptor* passDesc = [[ MTLRenderPassDescriptor alloc ] init ];
					passDesc.colorAttachments [ 0 ].texture = drawable.texture;
					passDesc.colorAttachments [ 0 ].loadAction = MTLLoadActionDontCare;	// fullscreen triangle covers everything
					passDesc.colorAttachments [ 0 ].storeAction = MTLStoreActionStore;

					id < MTLRenderCommandEncoder > present = [ ctx.mCmdBuffer renderCommandEncoderWithDescriptor:passDesc ];
					[ present setRenderPipelineState:ctx.mPresentPSO ];
					[ present setFragmentTexture:ctx.mCanvasColor atIndex:0 ];
					[ present setFragmentSamplerState:ctx.mPresentSampler atIndex:0 ];
					[ present drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3 ];
					[ present endEncoding ];

					[ ctx.mCmdBuffer presentDrawable:drawable ];
				}
			}
		}

		// hand the graveyard to the completed handler: command buffers on
		// one queue complete in order, so once THIS frame's buffer has
		// completed, no earlier buffer can still reference the resources
		NSMutableArray* batch = nil;
		if ([ ctx.mGraveyard count ]) {
			batch = ctx.mGraveyard;
			ctx.mGraveyard = [ NSMutableArray array ];
		}

		u64 serial = ctx.mFrameSerial;
		std::atomic < u64 >* completed = &ctx.mCompletedSerial;
		dispatch_semaphore_t sem = ctx.mFrameSem;

		[ ctx.mCmdBuffer addCompletedHandler:^( id < MTLCommandBuffer > cb ) {
			UNUSED ( cb );
			if ( batch ) {
				// releasing on the completion queue is fine
				[ batch removeAllObjects ];
			}
			completed->store ( serial, std::memory_order_release );
			dispatch_semaphore_signal ( sem );
		}];

		[ ctx.mCmdBuffer commit ];
		ctx.mCmdBuffer = nil;
		ctx.mInFrame = false;
	}
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::SetFrameBuffer ( MOAIGfxResID resID ) {

	MOAIMetalContext& ctx = *this->mCtx;

	_finishPendingPass ( ctx );

	if ( resID == 0 ) {

		ctx.mPassIsCanvas = true;
		ctx.mPassFlipped = false;
		ctx.EnsureCanvas ();
		ctx.mPassColor = ctx.mCanvasColor;
		ctx.mPassDepthStencil = ctx.mCanvasDepthStencil;
		ctx.mPassWidth = ctx.mCanvasWidth;
		ctx.mPassHeight = ctx.mCanvasHeight;

		// EnsureCanvas may have primed a first-use clear; otherwise load
		if ( !ctx.mClearPending ) {
			ctx.mColorLoad = MTLLoadActionLoad;
			ctx.mDepthLoad = MTLLoadActionLoad;
			ctx.mStencilLoad = MTLLoadActionLoad;
		}
		return;
	}

	MOAIMetalRenderTarget* target = ctx.mResources.GetTarget ( resID );
	if ( !target ) {
		MOAI_METAL_LOG_ONCE ( "MOAIGfxBackendMetal: SetFrameBuffer with unknown handle; using default canvas\n" )
		this->SetFrameBuffer ( 0 );
		return;
	}

	ctx.mPassIsCanvas = false;
	ctx.mPassFlipped = true;		// offscreen targets keep GL's bottom-up layout
	ctx.mPassColor = target->mColor;
	ctx.mPassDepthStencil = target->mDepthStencil;
	ctx.mPassWidth = target->mWidth;
	ctx.mPassHeight = target->mHeight;
	ctx.mColorLoad = MTLLoadActionLoad;
	ctx.mDepthLoad = MTLLoadActionLoad;
	ctx.mStencilLoad = MTLLoadActionLoad;
	ctx.mClearPending = false;
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::Clear ( u32 glMask, float r, float g, float b, float a ) {

	MOAIMetalContext& ctx = *this->mCtx;
	if ( !glMask ) return;		// GL: no glClear call at all

	// clears normally arrive at pass start (right after SetFrameBuffer with
	// the scissor disabled), before any encoder exists. If one is open,
	// fall back to breaking the pass so the clear becomes a load action.
	if ( ctx.mEncoder ) {
		MOAI_METAL_LOG_ONCE ( "MOAIGfxBackendMetal: mid-pass Clear; splitting render pass\n" )
		_endEncoder ( ctx );
	}

	if ( glMask & GL_COLOR_BUFFER_BIT ) {
		ctx.mColorLoad = MTLLoadActionClear;
		ctx.mClearColor = MTLClearColorMake ( r, g, b, a );
		ctx.mClearPending = true;
	}
	if ( glMask & GL_DEPTH_BUFFER_BIT ) {
		ctx.mDepthLoad = MTLLoadActionClear;
		ctx.mClearPending = true;
	}
	if ( glMask & GL_STENCIL_BUFFER_BIT ) {
		ctx.mStencilLoad = MTLLoadActionClear;
		ctx.mClearPending = true;
	}
}

//----------------------------------------------------------------//
// Read back the current target as RGBA8 in TOP-DOWN row order. The canvas
// is stored top-down (straight copy); offscreen targets are stored
// bottom-up in GL layout and get their rows flipped - mirroring the flip
// MOAIGfxBackendGL::ReadPixelsRGBA8 performs after glReadPixels.
void MOAIGfxBackendMetal::ReadPixelsRGBA8 ( u32 width, u32 height, void* buffer ) {

	MOAIMetalContext& ctx = *this->mCtx;

	memset ( buffer, 0, ( size_t )width * ( size_t )height * 4 );
	if ( !ctx.EnsureDevice ()) return;

	@autoreleasepool {

		// realize a pending clear so the readback sees it
		if ( !ctx.mEncoder && ctx.mClearPending && ctx.mCmdBuffer ) {
			if ( _ensureEncoder ( ctx )) {
				_endEncoder ( ctx );
			}
		}
		_endEncoder ( ctx );

		if ( !ctx.mPassColor ) {
			if ( !( ctx.mPassIsCanvas && ctx.EnsureCanvas ())) return;
			ctx.mPassColor = ctx.mCanvasColor;
			ctx.mPassDepthStencil = ctx.mCanvasDepthStencil;
			ctx.mPassWidth = ctx.mCanvasWidth;
			ctx.mPassHeight = ctx.mCanvasHeight;
		}

		id < MTLTexture > source = ctx.mPassColor;

		u32 copyWidth = width < ( u32 )source.width ? width : ( u32 )source.width;
		u32 copyHeight = height < ( u32 )source.height ? height : ( u32 )source.height;
		if ( !( copyWidth && copyHeight )) return;

		size_t bytesPerRow = ( size_t )copyWidth * 4;
		id < MTLBuffer > readback = [ ctx.mDevice newBufferWithLength:( bytesPerRow * copyHeight ) options:MTLResourceStorageModeShared ];
		if ( !readback ) return;

		bool midFrame = ( ctx.mCmdBuffer != nil );
		id < MTLCommandBuffer > cmd = midFrame ? ctx.mCmdBuffer : [ ctx.mQueue commandBuffer ];
		if ( !cmd ) return;

		id < MTLBlitCommandEncoder > blit = [ cmd blitCommandEncoder ];
		[ blit copyFromTexture:source
			sourceSlice:0
			sourceLevel:0
			sourceOrigin:MTLOriginMake ( 0, 0, 0 )
			sourceSize:MTLSizeMake ( copyWidth, copyHeight, 1 )
			toBuffer:readback
			destinationOffset:0
			destinationBytesPerRow:bytesPerRow
			destinationBytesPerImage:( bytesPerRow * copyHeight )];
		[ blit endEncoding ];

		// the ONLY waitUntilCompleted in the backend, per the seam contract
		[ cmd commit ];
		[ cmd waitUntilCompleted ];

		if ( midFrame ) {
			// resume the frame with a fresh command buffer; the pending pass
			// re-arms with load actions (content persists in the target)
			ctx.mCmdBuffer = [ ctx.mQueue commandBuffer ];
			ctx.mColorLoad = MTLLoadActionLoad;
			ctx.mDepthLoad = MTLLoadActionLoad;
			ctx.mStencilLoad = MTLLoadActionLoad;
			ctx.mClearPending = false;
		}

		const u8* src = ( const u8* )[ readback contents ];
		u8* dst = ( u8* )buffer;
		size_t dstBytesPerRow = ( size_t )width * 4;

		if ( ctx.mPassFlipped ) {
			// offscreen: stored bottom-up; emit top-down
			for ( u32 y = 0; y < copyHeight; ++y ) {
				memcpy ( dst + ( size_t )( copyHeight - 1 - y ) * dstBytesPerRow, src + ( size_t )y * bytesPerRow, bytesPerRow );
			}
		}
		else {
			// canvas: stored top-down already
			for ( u32 y = 0; y < copyHeight; ++y ) {
				memcpy ( dst + ( size_t )y * dstBytesPerRow, src + ( size_t )y * bytesPerRow, bytesPerRow );
			}
		}
	}
}

//================================================================//
// pipeline state
//================================================================//

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::SetViewport ( int x, int y, int width, int height ) {

	MOAIMetalContext& ctx = *this->mCtx;
	ctx.mViewportRect [ 0 ] = x;
	ctx.mViewportRect [ 1 ] = y;
	ctx.mViewportRect [ 2 ] = width;
	ctx.mViewportRect [ 3 ] = height;
	ctx.mViewportSet = true;

	if ( ctx.mEncoder ) {
		_applyViewport ( ctx );
	}
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::SetScissor ( bool enabled, int x, int y, int width, int height ) {

	MOAIMetalContext& ctx = *this->mCtx;
	ctx.mScissorEnabled = enabled;
	ctx.mScissorRect [ 0 ] = x;
	ctx.mScissorRect [ 1 ] = y;
	ctx.mScissorRect [ 2 ] = width;
	ctx.mScissorRect [ 3 ] = height;

	if ( ctx.mEncoder ) {
		_applyScissor ( ctx );
	}
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::SetBlend ( bool enabled, u32 glSrcFactor, u32 glDstFactor, u32 glEquation ) {
	UNUSED ( glEquation );	// recorded by the interface but MUST behave as GL_FUNC_ADD (GL parity)

	MOAIMetalContext& ctx = *this->mCtx;
	ctx.mBlendEnabled = enabled;
	ctx.mBlendSrc = glSrcFactor;
	ctx.mBlendDst = glDstFactor;
	// consumed by the PSO key at draw time
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::SetDepth ( u32 glDepthFuncOrZero, bool depthMask ) {

	MOAIMetalContext& ctx = *this->mCtx;
	ctx.mDepthFunc = glDepthFuncOrZero;
	ctx.mDepthMask = depthMask;

	if ( ctx.mEncoder ) {
		_applyDepth ( ctx );
	}
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::SetCull ( u32 glCullModeOrZero ) {

	MOAIMetalContext& ctx = *this->mCtx;
	ctx.mCullMode = glCullModeOrZero;

	if ( ctx.mEncoder ) {
		_applyCull ( ctx );
	}
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::SetLineWidth ( float width ) {

	// stored but lines render 1px: this matches the MetalANGLE-backed
	// renderer being replaced (it clamps line width to 1)
	this->mCtx->mLineWidth = width;
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::SetPointSize ( float size ) {

	// stored; point size is fixed at 1 via [[point_size]] in the shaders
	this->mCtx->mPointSize = size;
}

//================================================================//
// drawing
//================================================================//

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::BuildVertexLayout ( const MOAIVertexFormat& format, MOAIMetalVertexLayout& layout ) const {

	u32 total = format.mTotalAttributes;
	if ( total > MOAIMetalVertexLayout::MAX_ATTRIBUTES ) total = MOAIMetalVertexLayout::MAX_ATTRIBUTES;

	memset ( &layout, 0, sizeof ( layout ));

	for ( u32 i = 0; i < total; ++i ) {
		const MOAIVertexAttribute& attr = format.mAttributes [ i ];
		layout.mAttrs [ i ].mIndex = ( u32 )attr.mIndex;
		layout.mAttrs [ i ].mSize = ( u32 )attr.mSize;
		layout.mAttrs [ i ].mType = ( u32 )attr.mType;
		layout.mAttrs [ i ].mNormalized = ( attr.mNormalized != 0 );
		layout.mAttrs [ i ].mOffset = attr.mOffset;
	}
	layout.mCount = total;
	layout.mStride = format.GetVertexSize ();
	layout.ComputeHash ();
}

//----------------------------------------------------------------//
// Full per-draw state resolution: PSO, depth state, textures/samplers and
// the current program's uniform blocks.
static bool _ensureDrawState ( MOAIMetalContext& ctx, const MOAIMetalVertexLayout& layout ) {

	MOAIMetalProgram* program = ctx.mResources.GetProgram ( ctx.mCurrentProgram );
	if ( !program ) {
		MOAI_METAL_LOG_ONCE ( "MOAIGfxBackendMetal: draw with no shader program bound; skipping\n" )
		return false;
	}

	if ( !_ensureEncoder ( ctx )) return false;
	if ( ctx.mEncScissorEmpty ) return false;	// GL empty scissor discards everything

	MTLPixelFormat dsFormat = ctx.mPassDepthStencil ? ctx.mPassDepthStencil.pixelFormat : MTLPixelFormatInvalid;

	id < MTLRenderPipelineState > pso = ctx.mPipelines.GetPipeline (
		ctx.mDevice,
		ctx.mCurrentProgram,
		*program,
		layout,
		ctx.mBlendEnabled,
		ctx.mBlendSrc,
		ctx.mBlendDst,
		ctx.mPassColor.pixelFormat,
		dsFormat
	);
	if ( !pso ) return false;

	if ( pso != ctx.mEncPipeline ) {
		[ ctx.mEncoder setRenderPipelineState:pso ];
		ctx.mEncPipeline = pso;
	}

	// textures + samplers (shadow -> encoder), and reference tracking for
	// UpdateTextureRegion's hazard detection
	for ( u32 i = 0; i < MOAIMetalContext::MAX_UNITS; ++i ) {

		MOAIGfxResID handle = ctx.mUnitTexture [ i ];
		if ( !handle ) continue;

		MOAIMetalTexture* texture = ctx.mResources.GetTexture ( handle );
		if ( !( texture && texture->mTexture )) continue;

		texture->mLastReferencedFrame = ctx.mFrameSerial;

		id < MTLSamplerState > sampler = texture->mSampler;
		if ( !sampler ) {
			// MOAITextureBase defaults: min GL_LINEAR, mag GL_NEAREST, clamp
			if ( !ctx.mDefaultSampler ) {
				ctx.mDefaultSampler = ctx.mPipelines.GetSampler ( ctx.mDevice, GL_LINEAR, GL_NEAREST, GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE );
			}
			sampler = ctx.mDefaultSampler;
		}

		if ( ctx.mEncTexture [ i ] != handle ) {
			[ ctx.mEncoder setFragmentTexture:texture->mTexture atIndex:i ];
			ctx.mEncTexture [ i ] = handle;
		}
		if ( ctx.mEncSampler [ i ] != sampler ) {
			[ ctx.mEncoder setFragmentSamplerState:sampler atIndex:i ];
			ctx.mEncSampler [ i ] = sampler;
		}
	}

	// uniform blocks are tiny (< 4KB); upload on every draw via set*Bytes
	if ( program->mVsBlock.size ()) {
		[ ctx.mEncoder setVertexBytes:&program->mVsBlock [ 0 ] length:program->mVsBlock.size () atIndex:0 ];
	}
	if ( program->mFsBlock.size ()) {
		[ ctx.mEncoder setFragmentBytes:&program->mFsBlock [ 0 ] length:program->mFsBlock.size () atIndex:0 ];
	}

	return true;
}

//----------------------------------------------------------------//
static bool _uploadVertices ( MOAIMetalContext& ctx, const void* buffer, size_t sizeInBytes ) {

	MOAIMetalRingBuffer::Allocation alloc;
	if ( !ctx.mRing.Allocate ( sizeInBytes, alloc )) return false;

	memcpy ( alloc.mPtr, buffer, sizeInBytes );
	[ ctx.mEncoder setVertexBuffer:alloc.mBuffer offset:alloc.mOffset atIndex:MOAI_METAL_VERTEX_BUFFER_INDEX ];
	return true;
}

//----------------------------------------------------------------//
static bool _primType ( u32 glPrimType, MTLPrimitiveType& out ) {

	switch ( glPrimType ) {
		case GL_TRIANGLES:		out = MTLPrimitiveTypeTriangle;			return true;
		case GL_TRIANGLE_STRIP:	out = MTLPrimitiveTypeTriangleStrip;	return true;
		case GL_LINES:			out = MTLPrimitiveTypeLine;				return true;
		case GL_LINE_STRIP:		out = MTLPrimitiveTypeLineStrip;		return true;
		case GL_POINTS:			out = MTLPrimitiveTypePoint;			return true;
	}
	return false;
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::DrawArrays ( u32 glPrimType, u32 count, const MOAIVertexFormat& format, const void* buffer, size_t sizeInBytes ) {

	MOAIMetalContext& ctx = *this->mCtx;
	if ( !( count && buffer && sizeInBytes )) return;

	MOAIMetalVertexLayout layout;
	this->BuildVertexLayout ( format, layout );

	if ( !_ensureDrawState ( ctx, layout )) return;
	if ( !_uploadVertices ( ctx, buffer, sizeInBytes )) return;

	MTLPrimitiveType prim;
	if ( _primType ( glPrimType, prim )) {
		[ ctx.mEncoder drawPrimitives:prim vertexStart:0 vertexCount:count ];
		return;
	}

	if ( glPrimType == GL_TRIANGLE_FAN ) {

		// no fan primitive in Metal: emit an indexed triangle list
		// ( 0, i, i + 1 ) into the ring
		if ( count < 3 ) return;
		if ( count > 0xffff ) return;

		u32 indexCount = ( count - 2 ) * 3;
		MOAIMetalRingBuffer::Allocation alloc;
		if ( !ctx.mRing.Allocate (( size_t )indexCount * sizeof ( u16 ), alloc )) return;

		u16* idx = ( u16* )alloc.mPtr;
		for ( u32 i = 1; i + 1 < count; ++i ) {
			*idx++ = 0;
			*idx++ = ( u16 )i;
			*idx++ = ( u16 )( i + 1 );
		}

		[ ctx.mEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:indexCount indexType:MTLIndexTypeUInt16 indexBuffer:alloc.mBuffer indexBufferOffset:alloc.mOffset ];
		return;
	}

	if ( glPrimType == GL_LINE_LOOP ) {

		// no loop primitive in Metal: line strip 0..n-1,0
		if ( count < 2 ) return;
		if ( count > 0xffff ) return;

		u32 indexCount = count + 1;
		MOAIMetalRingBuffer::Allocation alloc;
		if ( !ctx.mRing.Allocate (( size_t )indexCount * sizeof ( u16 ), alloc )) return;

		u16* idx = ( u16* )alloc.mPtr;
		for ( u32 i = 0; i < count; ++i ) {
			idx [ i ] = ( u16 )i;
		}
		idx [ count ] = 0;

		[ ctx.mEncoder drawIndexedPrimitives:MTLPrimitiveTypeLineStrip indexCount:indexCount indexType:MTLIndexTypeUInt16 indexBuffer:alloc.mBuffer indexBufferOffset:alloc.mOffset ];
		return;
	}

	MOAI_METAL_LOG_ONCE ( "MOAIGfxBackendMetal: unsupported primitive type 0x%04x\n", glPrimType )
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::DrawIndexed ( u32 glPrimType, u32 indexCount, MOAIGfxResID indexBuffer, const MOAIVertexFormat& format, const void* buffer, size_t sizeInBytes ) {

	MOAIMetalContext& ctx = *this->mCtx;
	if ( !( indexCount && buffer && sizeInBytes )) return;

	MOAIMetalIndexBuffer* ib = ctx.mResources.GetIndexBuffer ( indexBuffer );
	if ( !( ib && ib->mBuffer )) return;

	if ( indexCount > ib->mCpuCopy.size ()) {
		indexCount = ( u32 )ib->mCpuCopy.size ();
		if ( !indexCount ) return;
	}

	MOAIMetalVertexLayout layout;
	this->BuildVertexLayout ( format, layout );

	if ( !_ensureDrawState ( ctx, layout )) return;
	if ( !_uploadVertices ( ctx, buffer, sizeInBytes )) return;

	MTLPrimitiveType prim;
	if ( _primType ( glPrimType, prim )) {
		[ ctx.mEncoder drawIndexedPrimitives:prim indexCount:indexCount indexType:MTLIndexTypeUInt16 indexBuffer:ib->mBuffer indexBufferOffset:0 ];
		return;
	}

	if ( glPrimType == GL_TRIANGLE_FAN ) {

		if ( indexCount < 3 ) return;

		u32 outCount = ( indexCount - 2 ) * 3;
		MOAIMetalRingBuffer::Allocation alloc;
		if ( !ctx.mRing.Allocate (( size_t )outCount * sizeof ( u16 ), alloc )) return;

		const u16* src = &ib->mCpuCopy [ 0 ];
		u16* idx = ( u16* )alloc.mPtr;
		for ( u32 i = 1; i + 1 < indexCount; ++i ) {
			*idx++ = src [ 0 ];
			*idx++ = src [ i ];
			*idx++ = src [ i + 1 ];
		}

		[ ctx.mEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:outCount indexType:MTLIndexTypeUInt16 indexBuffer:alloc.mBuffer indexBufferOffset:alloc.mOffset ];
		return;
	}

	if ( glPrimType == GL_LINE_LOOP ) {

		if ( indexCount < 2 ) return;

		u32 outCount = indexCount + 1;
		MOAIMetalRingBuffer::Allocation alloc;
		if ( !ctx.mRing.Allocate (( size_t )outCount * sizeof ( u16 ), alloc )) return;

		const u16* src = &ib->mCpuCopy [ 0 ];
		u16* idx = ( u16* )alloc.mPtr;
		for ( u32 i = 0; i < indexCount; ++i ) {
			idx [ i ] = src [ i ];
		}
		idx [ indexCount ] = src [ 0 ];

		[ ctx.mEncoder drawIndexedPrimitives:MTLPrimitiveTypeLineStrip indexCount:outCount indexType:MTLIndexTypeUInt16 indexBuffer:alloc.mBuffer indexBufferOffset:alloc.mOffset ];
		return;
	}

	MOAI_METAL_LOG_ONCE ( "MOAIGfxBackendMetal: unsupported indexed primitive type 0x%04x\n", glPrimType )
}

//================================================================//
// textures
//================================================================//

//----------------------------------------------------------------//
MOAIGfxResID MOAIGfxBackendMetal::CreateTexture ( const MOAIGfxTextureDesc& desc, const void* data, size_t dataSize ) {
	UNUSED ( dataSize );

	MOAIMetalContext& ctx = *this->mCtx;
	if ( !ctx.EnsureDevice ()) return 0;
	if ( !( desc.mWidth && desc.mHeight )) return 0;

	MTLPixelFormat format = MOAIMetalResolvePixelFormat ( desc.mGLInternalFormat, desc.mGLPixelType, desc.mIsCompressed );
	if ( format == MTLPixelFormatInvalid ) {
		USLog::Print ( "MOAIGfxBackendMetal: unsupported texture format 0x%04x / 0x%04x%s\n", desc.mGLInternalFormat, desc.mGLPixelType, desc.mIsCompressed ? " (compressed; PVRTC is iOS-only)" : "" );
		return 0;
	}

	@autoreleasepool {

		MTLTextureDescriptor* texDesc = [ MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format width:desc.mWidth height:desc.mHeight mipmapped:( desc.mHasMipmaps ? YES : NO )];
		if ( desc.mHasMipmaps ) {
			texDesc.mipmapLevelCount = MOAIMetalMipChainCount ( desc.mWidth, desc.mHeight );
		}
		texDesc.usage = MTLTextureUsageShaderRead;

		id < MTLTexture > texture = [ ctx.mDevice newTextureWithDescriptor:texDesc ];
		if ( !texture ) return 0;

		if ( data ) {
			if ( desc.mIsCompressed ) {
				// PVRTC: bytesPerRow/bytesPerImage must be 0
				[ texture replaceRegion:MTLRegionMake2D ( 0, 0, desc.mWidth, desc.mHeight ) mipmapLevel:0 slice:0 withBytes:data bytesPerRow:0 bytesPerImage:0 ];
			}
			else {
				std::vector < u8 > scratch;
				const void* upload = MOAIMetalConvertPixels ( desc.mGLInternalFormat, desc.mGLPixelType, desc.mWidth, desc.mHeight, data, scratch );
				u32 bpp = MOAIMetalStorageBytesPerPixel ( format );
				[ texture replaceRegion:MTLRegionMake2D ( 0, 0, desc.mWidth, desc.mHeight ) mipmapLevel:0 withBytes:upload bytesPerRow:( desc.mWidth * bpp )];
			}
		}

		MOAIMetalTexture* record = new MOAIMetalTexture ();
		record->mTexture = texture;
		record->mGLFormat = desc.mGLInternalFormat;
		record->mGLPixelType = desc.mGLPixelType;

		MOAIGfxResID resID = ctx.mResources.AllocSlot ();
		ctx.mResources.SetTexture ( resID, record );
		return resID;
	}
}

//----------------------------------------------------------------//
bool MOAIGfxBackendMetal::UploadTextureMip ( MOAIGfxResID resID, const MOAIGfxTextureDesc& desc, u32 level, u32 width, u32 height, const void* data, size_t dataSize ) {
	UNUSED ( dataSize );

	MOAIMetalContext& ctx = *this->mCtx;
	MOAIMetalTexture* record = ctx.mResources.GetTexture ( resID );
	if ( !( record && record->mTexture && data )) return false;

	if ( level >= [ record->mTexture mipmapLevelCount ]) {
		MOAI_METAL_LOG_ONCE ( "MOAIGfxBackendMetal: mip level beyond allocated chain ignored\n" )
		return true;
	}

	@autoreleasepool {

		if ( desc.mIsCompressed ) {
			[ record->mTexture replaceRegion:MTLRegionMake2D ( 0, 0, width, height ) mipmapLevel:level slice:0 withBytes:data bytesPerRow:0 bytesPerImage:0 ];
		}
		else {
			std::vector < u8 > scratch;
			const void* upload = MOAIMetalConvertPixels ( desc.mGLInternalFormat, desc.mGLPixelType, width, height, data, scratch );
			u32 bpp = MOAIMetalStorageBytesPerPixel ( record->mTexture.pixelFormat );
			[ record->mTexture replaceRegion:MTLRegionMake2D ( 0, 0, width, height ) mipmapLevel:level withBytes:upload bytesPerRow:( width * bpp )];
		}
	}
	return true;
}

//----------------------------------------------------------------//
// Partial update of mip level 0 (glyph atlases). Data is tightly packed
// width * height pixels in the texture's format. The y coordinate needs no
// conversion: glTexSubImage2D addresses texture memory rows directly, and
// texture memory layout is what the invariant preserves.
//
// Hazard handling: replaceRegion writes the texture immediately on the CPU
// timeline. If any not-yet-completed command buffer references the texture
// (mLastReferencedFrame > mCompletedSerial), route the update through a
// staging buffer + blit instead: blits are GPU-timeline ordered (hazard
// tracking serializes them against earlier reads), which reproduces GL's
// implicit synchronization. The common case - update before first use in a
// frame, texture idle - takes the cheap replaceRegion path.
bool MOAIGfxBackendMetal::UpdateTextureRegion ( MOAIGfxResID resID, const MOAIGfxTextureDesc& desc, int x, int y, u32 width, u32 height, const void* data ) {

	MOAIMetalContext& ctx = *this->mCtx;
	MOAIMetalTexture* record = ctx.mResources.GetTexture ( resID );
	if ( !( record && record->mTexture && data )) return false;
	if ( !( width && height )) return true;

	@autoreleasepool {

		std::vector < u8 > scratch;
		const void* upload = MOAIMetalConvertPixels ( desc.mGLInternalFormat, desc.mGLPixelType, width, height, data, scratch );
		u32 bpp = MOAIMetalStorageBytesPerPixel ( record->mTexture.pixelFormat );
		size_t bytesPerRow = ( size_t )width * bpp;
		size_t totalBytes = bytesPerRow * height;

		bool busy = record->mLastReferencedFrame > ctx.mCompletedSerial.load ( std::memory_order_acquire );

		if ( !busy ) {
			[ record->mTexture replaceRegion:MTLRegionMake2D ( x, y, width, height ) mipmapLevel:0 withBytes:upload bytesPerRow:bytesPerRow ];
			return true;
		}

		// blit path
		id < MTLBuffer > staging = nil;
		size_t stagingOffset = 0;

		id < MTLCommandBuffer > cmd = ctx.mCmdBuffer;
		bool transient = false;

		if ( cmd ) {
			MOAIMetalRingBuffer::Allocation alloc;
			if ( ctx.mRing.Allocate ( totalBytes, alloc )) {
				memcpy ( alloc.mPtr, upload, totalBytes );
				staging = alloc.mBuffer;
				stagingOffset = alloc.mOffset;
			}
		}
		else {
			// outside a frame but a previous frame is still in flight
			cmd = [ ctx.mQueue commandBuffer ];
			transient = true;
		}

		if ( !staging ) {
			staging = [ ctx.mDevice newBufferWithBytes:upload length:totalBytes options:MTLResourceStorageModeShared ];
			stagingOffset = 0;
		}
		if ( !( cmd && staging )) return false;

		// the blit must be ordered after any draws already encoded in the
		// current render encoder; end it (the next draw reopens with
		// loadAction Load + shadow state replay)
		_endEncoder ( ctx );

		id < MTLBlitCommandEncoder > blit = [ cmd blitCommandEncoder ];
		[ blit copyFromBuffer:staging
			sourceOffset:stagingOffset
			sourceBytesPerRow:bytesPerRow
			sourceBytesPerImage:totalBytes
			sourceSize:MTLSizeMake ( width, height, 1 )
			toTexture:record->mTexture
			destinationSlice:0
			destinationLevel:0
			destinationOrigin:MTLOriginMake ( x, y, 0 )];
		[ blit endEncoding ];

		if ( transient ) {
			[ cmd commit ];
		}
	}
	return true;
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::BindTexture ( u32 unit, MOAIGfxResID resID, const MOAIGfxSamplerDesc* sampler ) {

	MOAIMetalContext& ctx = *this->mCtx;
	if ( unit >= MOAIMetalContext::MAX_UNITS ) return;

	if ( !resID ) {
		// GL parity: the legacy programmable path never unbound the texture
		// name on "disable"; keep the shadow binding as-is
		return;
	}

	ctx.mUnitTexture [ unit ] = resID;

	if ( sampler ) {
		// GL semantics: sampler params are texture state and persist on the
		// texture until changed
		MOAIMetalTexture* record = ctx.mResources.GetTexture ( resID );
		if ( record ) {
			if ( ctx.EnsureDevice ()) {
				record->mSampler = ctx.mPipelines.GetSampler ( ctx.mDevice, sampler->mMinFilter, sampler->mMagFilter, sampler->mWrapS, sampler->mWrapT );
			}
		}
	}
	// applied onto the encoder at draw time (_ensureDrawState)
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::SetActiveTexture ( u32 unit ) {
	UNUSED ( unit );

	// Metal has no active-unit concept; the seam exists so GL creation-order
	// semantics are preserved. BindTexture carries the unit explicitly.
}

//================================================================//
// offscreen render targets
//================================================================//

//----------------------------------------------------------------//
MOAIGfxResID MOAIGfxBackendMetal::CreateFrameBuffer ( u32 width, u32 height, u32 glColorFormat, u32 glDepthFormat, u32 glStencilFormat, MOAIGfxResID& outColorTexture, MOAIGfxResID& outColorBuffer, MOAIGfxResID& outDepthBuffer, MOAIGfxResID& outStencilBuffer, bool& outComplete ) {
	UNUSED ( glColorFormat );	// GL_RGBA8 / GL_RGBA4 / GL_RGB5_A1 / GL_RGB565 all map to RGBA8Unorm

	outColorTexture = 0;
	outColorBuffer = 0;		// no GL renderbuffer objects exist on this backend
	outDepthBuffer = 0;
	outStencilBuffer = 0;
	outComplete = false;

	MOAIMetalContext& ctx = *this->mCtx;
	if ( !ctx.EnsureDevice ()) return 0;
	if ( !( width && height )) return 0;

	@autoreleasepool {

		MTLTextureDescriptor* colorDesc = [ MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:width height:height mipmapped:NO ];
		colorDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
		colorDesc.storageMode = MTLStorageModePrivate;

		id < MTLTexture > color = [ ctx.mDevice newTextureWithDescriptor:colorDesc ];
		if ( !color ) return 0;

		id < MTLTexture > depthStencil = nil;
		if ( glDepthFormat || glStencilFormat ) {

			MTLPixelFormat dsFormat;
			if ( glDepthFormat && glStencilFormat ) {
				dsFormat = MTLPixelFormatDepth32Float_Stencil8;
			}
			else if ( glDepthFormat ) {
				dsFormat = MTLPixelFormatDepth32Float;		// GL_DEPTH_COMPONENT16 -> Depth32Float
			}
			else {
				dsFormat = MTLPixelFormatStencil8;			// GL_STENCIL_INDEX8
			}

			MTLTextureDescriptor* dsDesc = [ MTLTextureDescriptor texture2DDescriptorWithPixelFormat:dsFormat width:width height:height mipmapped:NO ];
			dsDesc.usage = MTLTextureUsageRenderTarget;
			dsDesc.storageMode = MTLStorageModePrivate;
			depthStencil = [ ctx.mDevice newTextureWithDescriptor:dsDesc ];
		}

		// the color texture gets its own slot so BindTexture works on it
		// (the engine also deletes it independently via DELETE_TEXTURE)
		MOAIMetalTexture* colorRecord = new MOAIMetalTexture ();
		colorRecord->mTexture = color;
		colorRecord->mGLFormat = GL_RGBA;
		colorRecord->mGLPixelType = GL_UNSIGNED_BYTE;

		MOAIGfxResID colorHandle = ctx.mResources.AllocSlot ();
		ctx.mResources.SetTexture ( colorHandle, colorRecord );

		MOAIMetalRenderTarget* target = new MOAIMetalRenderTarget ();
		target->mColor = color;
		target->mDepthStencil = depthStencil;
		target->mWidth = width;
		target->mHeight = height;
		target->mColorTextureHandle = colorHandle;

		MOAIGfxResID targetHandle = ctx.mResources.AllocSlot ();
		ctx.mResources.SetTarget ( targetHandle, target );

		outColorTexture = colorHandle;
		outComplete = true;
		return targetHandle;
	}
}

//================================================================//
// index buffers
//================================================================//

//----------------------------------------------------------------//
MOAIGfxResID MOAIGfxBackendMetal::CreateIndexBuffer ( const u16* indices, u32 count ) {

	MOAIMetalContext& ctx = *this->mCtx;
	if ( !ctx.EnsureDevice ()) return 0;
	if ( !( indices && count )) return 0;

	@autoreleasepool {

		id < MTLBuffer > buffer = [ ctx.mDevice newBufferWithBytes:indices length:( count * sizeof ( u16 )) options:MTLResourceStorageModeShared ];
		if ( !buffer ) return 0;

		MOAIMetalIndexBuffer* record = new MOAIMetalIndexBuffer ();
		record->mBuffer = buffer;
		record->mCpuCopy.assign ( indices, indices + count );

		MOAIGfxResID resID = ctx.mResources.AllocSlot ();
		ctx.mResources.SetIndexBuffer ( resID, record );
		return resID;
	}
}

//================================================================//
// shaders
//================================================================//

//----------------------------------------------------------------//
MOAIGfxResID MOAIGfxBackendMetal::CreateProgram ( const MOAIGfxShaderProgramDesc& desc ) {

	MOAIMetalContext& ctx = *this->mCtx;
	if ( !ctx.EnsureDevice ()) return 0;

	if ( !( desc.mVertexSourceMSL && desc.mFragmentSourceMSL )) {
		USLog::Print ( "MOAIGfxBackendMetal: shader has no MSL sources (GLSL-only shader on the Metal backend); load () it with MSL vertex/fragment sources as arguments 4 and 5\n" );
		return 0;
	}

	@autoreleasepool {

		MOAIMetalProgram* program = MOAIMetalCreateProgram ( ctx.mDevice, desc.mVertexSourceMSL, desc.mFragmentSourceMSL );
		if ( !program ) return 0;

		MOAIGfxResID resID = ctx.mResources.AllocSlot ();
		ctx.mResources.SetProgram ( resID, program );
		return resID;
	}
}

//----------------------------------------------------------------//
// Resolve a uniform by name against the reflected buffer(0) structs. The
// returned addr is an index into the program's uniform slot table; (u32)-1
// when the name is absent in BOTH stages (matching glGetUniformLocation's
// -1, which MOAIShader passes back into SetUniform where it is skipped).
//
// UNIFORM_SAMPLER: GL did glUniform1i ( addr, unit - 1 ). In Metal the
// texture binding index is fixed by the MSL [[texture(n)]] qualifier, and
// sampler names never appear in the uniform struct, so this naturally
// returns (u32)-1 and SetUniform becomes a safe no-op. Texture binding
// flows through BindTexture's unit indices, which content already sets up
// to match (unit = declareUniformSampler value - 1).
u32 MOAIGfxBackendMetal::ResolveUniform ( MOAIGfxResID program, cc8* name, u32 uniformType ) {
	UNUSED ( uniformType );

	MOAIMetalContext& ctx = *this->mCtx;
	MOAIMetalProgram* record = ctx.mResources.GetProgram ( program );
	if ( !( record && name )) return ( u32 )-1;

	std::string key ( name );

	std::map < std::string, u32 >::iterator existing = record->mSlotsByName.find ( key );
	if ( existing != record->mSlotsByName.end ()) return existing->second;

	std::map < std::string, MOAIMetalUniformMember >::iterator vs = record->mVsMembers.find ( key );
	std::map < std::string, MOAIMetalUniformMember >::iterator fs = record->mFsMembers.find ( key );

	bool inVs = ( vs != record->mVsMembers.end ());
	bool inFs = ( fs != record->mFsMembers.end ());
	if ( !( inVs || inFs )) return ( u32 )-1;

	MOAIMetalUniformSlot slot;
	slot.mVsOffset = inVs ? ( int )vs->second.mOffset : -1;
	slot.mVsType = inVs ? vs->second.mDataType : MTLDataTypeNone;
	slot.mFsOffset = inFs ? ( int )fs->second.mOffset : -1;
	slot.mFsType = inFs ? fs->second.mDataType : MTLDataTypeNone;

	u32 addr = ( u32 )record->mSlots.size ();
	record->mSlots.push_back ( slot );
	record->mSlotsByName [ key ] = addr;
	return addr;
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::UseProgram ( MOAIGfxResID program ) {

	// shadow only; the PSO is resolved at draw time
	this->mCtx->mCurrentProgram = program;
}

//----------------------------------------------------------------//
static void _writeUniform ( std::vector < u8 >& block, u32 offset, MTLDataType dataType, u32 uniformType, const void* data ) {

	size_t blockSize = block.size ();
	u8* dst = blockSize ? &block [ 0 ] : 0;
	if ( !dst ) return;

	switch ( uniformType ) {

		case MOAIShaderUniform::UNIFORM_INT: {
			if (( size_t )offset + 4 > blockSize ) return;
			int v = *( const int* )data;
			if ( dataType == MTLDataTypeFloat ) {
				float f = ( float )v;
				memcpy ( dst + offset, &f, 4 );
			}
			else {
				memcpy ( dst + offset, &v, 4 );
			}
			break;
		}

		case MOAIShaderUniform::UNIFORM_FLOAT: {
			if (( size_t )offset + 4 > blockSize ) return;
			float f = *( const float* )data;
			if (( dataType == MTLDataTypeInt ) || ( dataType == MTLDataTypeUInt ) || ( dataType == MTLDataTypeBool )) {
				int v = ( int )f;
				memcpy ( dst + offset, &v, 4 );
			}
			else {
				memcpy ( dst + offset, &f, 4 );
			}
			break;
		}

		case MOAIShaderUniform::UNIFORM_COLOR:
		case MOAIShaderUniform::UNIFORM_PEN_COLOR: {
			if (( size_t )offset + 16 > blockSize ) return;
			memcpy ( dst + offset, data, 16 );
			break;
		}

		case MOAIShaderUniform::UNIFORM_NORMAL: {
			// 9 source floats (3 packed columns, as glUniformMatrix3fv
			// received them) -> MSL float3x3: 3 columns of float4 (48 bytes)
			if ( dataType != MTLDataTypeFloat3x3 ) return;
			if (( size_t )offset + 48 > blockSize ) return;
			const float* src = ( const float* )data;
			float* out = ( float* )( dst + offset );
			for ( u32 col = 0; col < 3; ++col ) {
				out [ col * 4 + 0 ] = src [ col * 3 + 0 ];
				out [ col * 4 + 1 ] = src [ col * 3 + 1 ];
				out [ col * 4 + 2 ] = src [ col * 3 + 2 ];
				out [ col * 4 + 3 ] = 0.0f;
			}
			break;
		}

		case MOAIShaderUniform::UNIFORM_VIEW_PROJ:
		case MOAIShaderUniform::UNIFORM_WORLD:
		case MOAIShaderUniform::UNIFORM_WORLD_VIEW_PROJ:
		case MOAIShaderUniform::UNIFORM_TRANSFORM: {
			// 16 floats, byte-identical to the glUniformMatrix4fv upload;
			// float4x4 columns == GLSL mat4 columns. No transpose.
			if ( dataType != MTLDataTypeFloat4x4 ) return;
			if (( size_t )offset + 64 > blockSize ) return;
			memcpy ( dst + offset, data, 64 );
			break;
		}

		default:
			break;
	}
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::SetUniform ( u32 addr, u32 uniformType, const void* data ) {

	MOAIMetalContext& ctx = *this->mCtx;

	if ( addr == ( u32 )-1 ) return;	// unresolved uniform (GL: location -1 is silently ignored)
	if ( !data ) return;

	MOAIMetalProgram* program = ctx.mResources.GetProgram ( ctx.mCurrentProgram );
	if ( !program ) return;
	if ( addr >= program->mSlots.size ()) return;

	const MOAIMetalUniformSlot& slot = program->mSlots [ addr ];

	if ( slot.mVsOffset >= 0 ) {
		_writeUniform ( program->mVsBlock, ( u32 )slot.mVsOffset, slot.mVsType, uniformType, data );
	}
	if ( slot.mFsOffset >= 0 ) {
		_writeUniform ( program->mFsBlock, ( u32 )slot.mFsOffset, slot.mFsType, uniformType, data );
	}
	// blocks are re-uploaded via set*Bytes on every draw, so no explicit
	// dirty flag is needed
}

//================================================================//
// resource deletion / misc
//================================================================//

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::DeleteResource ( u32 type, MOAIGfxResID resID ) {
	UNUSED ( type );	// the handle table knows what the slot holds
						// (NOTE: MOAIShader pushes its program with
						// DELETE_SHADER; harmless here)

	MOAIMetalContext& ctx = *this->mCtx;
	if ( !resID ) return;

	// GL parity: deleting a bound object unbinds it
	for ( u32 i = 0; i < MOAIMetalContext::MAX_UNITS; ++i ) {
		if ( ctx.mUnitTexture [ i ] == resID ) {
			ctx.mUnitTexture [ i ] = 0;
		}
	}
	if ( ctx.mCurrentProgram == resID ) {
		ctx.mCurrentProgram = 0;
	}

	if ( !ctx.mGraveyard ) {
		ctx.mGraveyard = [ NSMutableArray array ];
	}

	// the graveyard rides the NEXT committed frame's completed handler;
	// in-order queue completion guarantees every earlier command buffer
	// has finished by then. Deletions with no frames in flight are released
	// the same way, just later - always correct, occasionally lazy.
	ctx.mResources.DeleteResource ( resID, ctx.mGraveyard );
}

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::FlushHint () {

	// glFlush analog: nothing to do; work is committed every frame
}

//----------------------------------------------------------------//
u32 MOAIGfxBackendMetal::GetError () {

	return 0;	// GL_NO_ERROR: Metal errors surface at creation sites
}

//----------------------------------------------------------------//
cc8* MOAIGfxBackendMetal::GetErrorString ( u32 error ) {
	UNUSED ( error );

	return "";
}

//================================================================//
// GLES1 fixed-function legacy: no-ops (programmable-only backend)
//================================================================//

//----------------------------------------------------------------//
void MOAIGfxBackendMetal::MatrixMode ( u32 glMatrixMode )		{ UNUSED ( glMatrixMode ); }
void MOAIGfxBackendMetal::LoadIdentity ()						{}
void MOAIGfxBackendMetal::LoadMatrix ( const float* m )			{ UNUSED ( m ); }
void MOAIGfxBackendMetal::MultMatrix ( const float* m )			{ UNUSED ( m ); }
void MOAIGfxBackendMetal::Color4f ( float r, float g, float b, float a ) {
	UNUSED ( r ); UNUSED ( g ); UNUSED ( b ); UNUSED ( a );
}

#endif

// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#include "pch.h"
#include <moaicore/MOAIGfxBackend.h>
#include <moaicore/MOAIGfxDevice.h>
#include <moaicore/MOAILogMessages.h>
#include <moaicore/MOAIFrameBufferTexture.h>

//================================================================//
// local
//================================================================//

//----------------------------------------------------------------//
/**	@name	init
	@text	Initializes frame buffer.
	
	@in		MOAIFrameBufferTexture self
	@in		number width
	@in		number height
	@out	nil
*/
int MOAIFrameBufferTexture::_init ( lua_State* L ) {
	MOAI_LUA_SETUP ( MOAIFrameBufferTexture, "UNN" )
	
	u32 width				= state.GetValue < u32 >( 2, 0 );
	u32 height				= state.GetValue < u32 >( 3, 0 );
	
	// TODO: fix me
	#ifdef MOAI_OS_ANDROID
		GLenum colorFormat		= state.GetValue < GLenum >( 4, GL_RGB565 );
	#else
		GLenum colorFormat		= state.GetValue < GLenum >( 4, GL_RGBA8 );
	#endif
	
	GLenum depthFormat		= state.GetValue < GLenum >( 5, 0 );
	GLenum stencilFormat	= state.GetValue < GLenum >( 6, 0 );
	
	self->Init ( width, height, colorFormat, depthFormat, stencilFormat );
	
	return 0;
}



//================================================================//
// MOAIFrameBufferTexture
//================================================================//

//----------------------------------------------------------------//
void MOAIFrameBufferTexture::Init ( u32 width, u32 height, GLenum colorFormat, GLenum depthFormat, GLenum stencilFormat ) {

	this->Clear ();

	if ( MOAIGfxDevice::Get ().IsFramebufferSupported ()) {

		this->mWidth			= width;
		this->mHeight			= height;
		this->mColorFormat		= colorFormat;
		this->mDepthFormat		= depthFormat;
		this->mStencilFormat	= stencilFormat;
		
		this->Load ();
	}
	else {
		MOAILog ( 0, MOAILogMessages::MOAITexture_NoFramebuffer );
	}
}

//----------------------------------------------------------------//
bool MOAIFrameBufferTexture::IsRenewable () {

	return true;
}

//----------------------------------------------------------------//
bool MOAIFrameBufferTexture::IsValid () {

	return ( this->mGLFrameBufferID != 0 );
}

//----------------------------------------------------------------//
MOAIFrameBufferTexture::MOAIFrameBufferTexture () :
	mGLColorBufferID ( 0 ),
	mGLDepthBufferID ( 0 ),
	mGLStencilBufferID ( 0 ),
	mColorFormat ( 0 ),
	mDepthFormat ( 0 ),
	mStencilFormat ( 0 ) {
	
	RTTI_BEGIN
		RTTI_EXTEND ( MOAIFrameBuffer )
		RTTI_EXTEND ( MOAITextureBase )
	RTTI_END
}

//----------------------------------------------------------------//
MOAIFrameBufferTexture::~MOAIFrameBufferTexture () {

	this->Clear ();
}

//----------------------------------------------------------------//
void MOAIFrameBufferTexture::OnCreate () {
	
	if ( !( this->mWidth && this->mHeight && ( this->mColorFormat || this->mDepthFormat || this->mStencilFormat ))) {
		return;
	}
	
	this->mBufferWidth = this->mWidth;
	this->mBufferHeight = this->mHeight;

	MOAIGfxResID colorTexture = 0;
	MOAIGfxResID colorBuffer = 0;
	MOAIGfxResID depthBuffer = 0;
	MOAIGfxResID stencilBuffer = 0;
	bool complete = false;

	MOAIGfxResID frameBuffer = MOAIGfx::Get ().CreateFrameBuffer (
		this->mWidth,
		this->mHeight,
		this->mColorFormat,
		this->mDepthFormat,
		this->mStencilFormat,
		colorTexture,
		colorBuffer,
		depthBuffer,
		stencilBuffer,
		complete
	);

	// bail and retry (no error) if GL cannot generate buffer ID
	if ( !frameBuffer ) return;

	this->mGLFrameBufferID		= ( GLuint )frameBuffer;
	this->mGLColorBufferID		= ( GLuint )colorBuffer;
	this->mGLDepthBufferID		= ( GLuint )depthBuffer;
	this->mGLStencilBufferID	= ( GLuint )stencilBuffer;

	if ( complete ) {

		this->mGLTexID = ( GLuint )colorTexture;

		// refresh tex params on next bind
		this->mIsDirty = true;
	}
	else {
		this->Clear ();
	}
}

//----------------------------------------------------------------//
void MOAIFrameBufferTexture::OnDestroy () {

	if ( this->mGLFrameBufferID ) {
		MOAIGfxDevice::Get ().PushDeleter ( MOAIGfxDeleter::DELETE_FRAMEBUFFER, this->mGLFrameBufferID );
		this->mGLFrameBufferID = 0;
	}
	
	if ( this->mGLColorBufferID ) {
		MOAIGfxDevice::Get ().PushDeleter ( MOAIGfxDeleter::DELETE_RENDERBUFFER, this->mGLColorBufferID );
		this->mGLColorBufferID = 0;
	}
	
	if ( this->mGLDepthBufferID ) {
		MOAIGfxDevice::Get ().PushDeleter ( MOAIGfxDeleter::DELETE_RENDERBUFFER, this->mGLDepthBufferID );
		this->mGLDepthBufferID = 0;
	}
	
	if ( this->mGLStencilBufferID ) {
		MOAIGfxDevice::Get ().PushDeleter ( MOAIGfxDeleter::DELETE_RENDERBUFFER, this->mGLStencilBufferID );
		this->mGLStencilBufferID = 0;
	}
	
	this->MOAITextureBase::OnDestroy ();
}

//----------------------------------------------------------------//
void MOAIFrameBufferTexture::OnInvalidate () {

	this->mGLFrameBufferID = 0;
	this->mGLColorBufferID = 0;
	this->mGLDepthBufferID = 0;
	this->mGLStencilBufferID = 0;

	this->MOAITextureBase::OnInvalidate ();
}

//----------------------------------------------------------------//
void MOAIFrameBufferTexture::OnLoad () {
}

//----------------------------------------------------------------//
void MOAIFrameBufferTexture::RegisterLuaClass ( MOAILuaState& state ) {
	
	MOAIFrameBuffer::RegisterLuaClass ( state );
	MOAITextureBase::RegisterLuaClass ( state );
}

//----------------------------------------------------------------//
void MOAIFrameBufferTexture::RegisterLuaFuncs ( MOAILuaState& state ) {

	MOAIFrameBuffer::RegisterLuaFuncs ( state );
	MOAITextureBase::RegisterLuaFuncs ( state );	

	luaL_Reg regTable [] = {
		{ "init",						_init },
		{ NULL, NULL }
	};

	luaL_register ( state, 0, regTable );
}

//----------------------------------------------------------------//
void MOAIFrameBufferTexture::Render () {

	if ( this->Affirm ()) {
		MOAIFrameBuffer::Render ();
	}
}

//----------------------------------------------------------------//
void MOAIFrameBufferTexture::SerializeIn ( MOAILuaState& state, MOAIDeserializer& serializer ) {
	MOAITextureBase::SerializeIn ( state, serializer );
}

//----------------------------------------------------------------//
void MOAIFrameBufferTexture::SerializeOut ( MOAILuaState& state, MOAISerializer& serializer ) {
	MOAITextureBase::SerializeOut ( state, serializer );
}
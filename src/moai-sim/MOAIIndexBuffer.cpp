// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#include "pch.h"
#include <moai-sim/MOAIIndexBuffer.h>
#include <moai-sim/MOAIGfxResourceMgr.h>

//================================================================//
// local
//================================================================//

//----------------------------------------------------------------//
/**	@lua	release
	@text	Release any memory held by this index buffer.
	
	@in		MOAIIndexBuffer self
	@out	nil
*/
int	MOAIIndexBuffer::_release ( lua_State* L ) {
	MOAI_LUA_SETUP ( MOAIIndexBuffer, "U" )
	
	self->Clear ();
	return 0;
}

//----------------------------------------------------------------//
/**	@lua	reserve
	@text	Set capacity of buffer.
	
	@in		MOAIIndexBuffer self
	@in		number nIndices
	@out	nil
*/
int	MOAIIndexBuffer::_reserve ( lua_State* L ) {
	MOAI_LUA_SETUP ( MOAIIndexBuffer, "UN" )
	
	u32 indexCount = state.GetValue < u32 >( 2, 0 );
	self->ReserveIndices ( indexCount );
	
	return 0;
}

//----------------------------------------------------------------//
/**	@lua	setIndex
	@text	Initialize an index.
	
	@in		MOAIIndexBuffer self
	@in		number idx
	@in		number value
	@out	nil
*/
int	MOAIIndexBuffer::_setIndex ( lua_State* L ) {
	MOAI_LUA_SETUP ( MOAIIndexBuffer, "UNN" )
	
	u32 idx		= state.GetValue < u32 >( 2, 1 ) - 1;
	u32 value	= state.GetValue < u32 >( 3, 1 ) - 1;
	
	self->SetIndex ( idx, value );
	
	return 0;
}

//================================================================//
// MOAIGfxQuadListDeck2D
//================================================================//

//----------------------------------------------------------------//
void MOAIIndexBuffer::Clear () {

	this->mIndices.Clear ();
	this->Destroy ();
}

//----------------------------------------------------------------//
u32 MOAIIndexBuffer::GetLoadingPolicy () {

	return MOAIGfxResource::LOADING_POLICY_CPU_GPU_BIND;
}

//----------------------------------------------------------------//
MOAIIndexBuffer::MOAIIndexBuffer () :
	mGLBufferID ( 0 ),
	mHint ( ZGL_BUFFER_USAGE_STATIC_DRAW ) {
	
	RTTI_SINGLE ( MOAILuaObject )
}

//----------------------------------------------------------------//
MOAIIndexBuffer::~MOAIIndexBuffer () {

	this->Clear ();
}

//----------------------------------------------------------------//
bool MOAIIndexBuffer::OnCPUCreate () {

	return true;
}

//----------------------------------------------------------------//
void MOAIIndexBuffer::OnCPUDestroy () {
}

//----------------------------------------------------------------//
void MOAIIndexBuffer::OnGPUBind () {

	if ( this->mGLBufferID ) {
		zglBindBuffer ( ZGL_BUFFER_TARGET_ELEMENT_ARRAY, this->mGLBufferID );
	}
}

//----------------------------------------------------------------//
bool MOAIIndexBuffer::OnGPUCreate () {

	if ( this->mIndices.Size ()) {
		
		this->mGLBufferID = zglCreateBuffer ();
		if ( this->mGLBufferID ) {
		
			zglBindBuffer ( ZGL_BUFFER_TARGET_ELEMENT_ARRAY, this->mGLBufferID );
			zglBufferData ( ZGL_BUFFER_TARGET_ELEMENT_ARRAY, this->mIndices.BufferSize (), this->mIndices.Data (), this->mHint );
		
			return true;
		}
	}
	return false;
}

//----------------------------------------------------------------//
void MOAIIndexBuffer::OnGPUDestroy () {

	MOAIGfxResourceMgr::Get ().PushDeleter ( MOAIGfxDeleter::DELETE_BUFFER, this->mGLBufferID );
	this->mGLBufferID = 0;
}

//----------------------------------------------------------------//
void MOAIIndexBuffer::OnGPULost () {

	this->mGLBufferID = 0;
}

//----------------------------------------------------------------//
void MOAIIndexBuffer::OnGPUUnbind () {

	zglBindBuffer ( ZGL_BUFFER_TARGET_ELEMENT_ARRAY, 0 );
}

//----------------------------------------------------------------//
void MOAIIndexBuffer::RegisterLuaClass ( MOAILuaState& state ) {
	UNUSED ( state );
}

//----------------------------------------------------------------//
void MOAIIndexBuffer::RegisterLuaFuncs ( MOAILuaState& state ) {

	luaL_Reg regTable [] = {
		{ "release",			_release },
		{ "reserve",			_reserve },
		{ "setIndex",			_setIndex },
		{ NULL, NULL }
	};

	luaL_register ( state, 0, regTable );
}

//----------------------------------------------------------------//
void MOAIIndexBuffer::ReserveIndices ( u32 indexCount ) {

	this->Clear ();
	this->mIndices.Init ( indexCount );
	this->mStream.SetBuffer ( this->mIndices.Data (), this->mIndices.BufferSize ());
	
	this->DoCPUAffirm ();
}

//----------------------------------------------------------------//
void MOAIIndexBuffer::SerializeIn ( MOAILuaState& state, MOAIDeserializer& serializer ) {
	UNUSED ( serializer );

	u32 indexCount		= state.GetField < u32 >( -1, "mTotalIndices", 0 );
	this->mHint			= state.GetField < u32 >( -1, "mHint", 0 );

	this->ReserveIndices ( indexCount );

	state.GetField ( -1, "mIndices" );

	if ( state.IsType ( -1, LUA_TSTRING )) {
		
		STLString zipString = lua_tostring ( state, -1 );
		size_t unzipLen = zipString.zip_inflate ( this->mIndices.Data (), this->mIndices.BufferSize ());
		assert ( unzipLen == this->mIndices.BufferSize ()); // TODO: fail gracefully
	}
	lua_pop ( state, 1 );
}

//----------------------------------------------------------------//
void MOAIIndexBuffer::SerializeOut ( MOAILuaState& state, MOAISerializer& serializer ) {
	UNUSED ( serializer );

	state.SetField ( -1, "mTotalIndices", ( u32 )this->mIndices.Size ()); // TODO: overflow
	state.SetField ( -1, "mHint", this->mHint );
	
	STLString zipString;
	zipString.zip_deflate ( this->mIndices.Data (), this->mIndices.BufferSize ());
	
	lua_pushstring ( state, zipString.str ());
	lua_setfield ( state, -2, "mIndices" );
}

//----------------------------------------------------------------//
void MOAIIndexBuffer::SetIndex ( u32 idx, u32 value ) {

	if ( idx < this->mIndices.Size ()) {
		this->mIndices [ idx ] = value;
	}
}
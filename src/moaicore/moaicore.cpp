// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#include "pch.h"
#include <chipmunk/chipmunk.h>
#include <moaicore/moaicore.h>

extern "C" {
	#include <zlib.h>
	#include <zlcore/ZLZipArchive.h>
}

//----------------------------------------------------------------//
// TODO: this should be part of the unit tests
static void _typeCheck () {

	// make sure our fixed size typedefs are what we think
	// they are on the current platform/compiler
	assert ( sizeof ( cc8 )	== 1 );

	assert ( sizeof ( u8 )	== 1 );
	assert ( sizeof ( u16 )	== 2 );
	assert ( sizeof ( u32 )	== 4 );
	assert ( sizeof ( u64 )	== 8 );
	
	assert ( sizeof ( s8 )	== 1 );
	assert ( sizeof ( s16 )	== 2 );
	assert ( sizeof ( s32 )	== 4 );
	assert ( sizeof ( s64 )	== 8 );
}

//================================================================//
// moaicore
//================================================================//

//----------------------------------------------------------------//
void moaicore::InitGlobals ( MOAIGlobals* globals ) {

	MOAIGlobalsMgr::Set ( globals );

	MOAILuaRuntime::Affirm ();
	MOAILogMgr::Affirm ();
	MOAIGfxDevice::Affirm ();
	
	#if MOAI_OS_NACL
		MOAIUrlMgrNaCl::Affirm ();
	#endif
	
	MOAIMath::Affirm ();
	MOAIXmlParser::Affirm ();
	MOAIActionMgr::Affirm ();
	MOAIInputMgr::Affirm ();
	MOAINodeMgr::Affirm ();
	MOAIVertexFormatMgr::Affirm ();
	MOAIShaderMgr::Affirm ();
	MOAIDraw::Affirm ();
	MOAIDebugLines::Affirm ();
	MOAIPartitionResultMgr::Affirm ();
	MOAISim::Affirm ();
	MOAIRenderMgr::Affirm ();
	
	// Start Lua
	MOAILuaRuntime& luaRuntime = MOAILuaRuntime::Get ();
	luaRuntime.Open ();
	luaRuntime.LoadLibs ( "moai" );
	
	MOAILogMessages::RegisterDefaultLogMessages ();
	
	// MOAI
	REGISTER_LUA_CLASS ( MOAIAction )
	REGISTER_LUA_CLASS ( MOAIActionMgr )
	REGISTER_LUA_CLASS ( MOAIAnim )
	REGISTER_LUA_CLASS ( MOAIAnimCurve )
	REGISTER_LUA_CLASS ( MOAIAnimCurveQuat )
	REGISTER_LUA_CLASS ( MOAIAnimCurveVec )
	REGISTER_LUA_CLASS ( MOAIAnimCurveCustom )
	REGISTER_LUA_CLASS ( MOAIBitmapFontReader )
	REGISTER_LUA_CLASS ( MOAIBoundsDeck )
	REGISTER_LUA_CLASS ( MOAIButtonSensor )
	REGISTER_LUA_CLASS ( MOAICamera )
	REGISTER_LUA_CLASS ( MOAICameraAnchor2D )
	REGISTER_LUA_CLASS ( MOAICameraFitter2D )
	REGISTER_LUA_CLASS ( MOAICCParticleSystem )
	REGISTER_LUA_CLASS ( MOAIColor )
	REGISTER_LUA_CLASS ( MOAICompassSensor )
	REGISTER_LUA_CLASS ( MOAICoroutine )
	REGISTER_LUA_CLASS ( MOAIDataBuffer )
	REGISTER_LUA_CLASS ( MOAIDataBufferStream )
	REGISTER_LUA_CLASS ( MOAIDataIOTask )
	REGISTER_LUA_CLASS ( MOAIDebugLines )
	REGISTER_LUA_CLASS ( MOAIDeckRemapper )
	REGISTER_LUA_CLASS ( MOAIDeserializer )
	REGISTER_LUA_CLASS ( MOAIDraw )
	REGISTER_LUA_CLASS ( MOAIGlyphCache )
	REGISTER_LUA_CLASS ( MOAIEnvironment )
	REGISTER_LUA_CLASS ( MOAIEase )
	REGISTER_LUA_CLASS ( MOAIEaseLinear )
	REGISTER_LUA_CLASS ( MOAIEaseSineIn )
	REGISTER_LUA_CLASS ( MOAIEaseSineOut )
	REGISTER_LUA_CLASS ( MOAIEaseSineInOut )
	REGISTER_LUA_CLASS ( MOAIEaseExponentialIn )
	REGISTER_LUA_CLASS ( MOAIEaseExponentialOut )
	REGISTER_LUA_CLASS ( MOAIEaseExponentialInOut )
	REGISTER_LUA_CLASS ( MOAIEaseSimpleIn )
	REGISTER_LUA_CLASS ( MOAIEaseSimpleOut )
	REGISTER_LUA_CLASS ( MOAIEaseSimpleInOut )
	REGISTER_LUA_CLASS ( MOAIEaseBackIn )
	REGISTER_LUA_CLASS ( MOAIEaseBackOut )
	REGISTER_LUA_CLASS ( MOAIEaseBackInOut )
	REGISTER_LUA_CLASS ( MOAIEaseElasticIn )
	REGISTER_LUA_CLASS ( MOAIEaseElasticOut )
	REGISTER_LUA_CLASS ( MOAIEaseElasticInOut )
	REGISTER_LUA_CLASS ( MOAIEaseCustom )
	REGISTER_LUA_CLASS ( MOAIEaseDriver )
	REGISTER_LUA_CLASS ( MOAIEaseType )
	REGISTER_LUA_CLASS ( MOAIFileStream )
	REGISTER_LUA_CLASS ( MOAIFileSystem )
	REGISTER_LUA_CLASS ( MOAIFoo )
	REGISTER_LUA_CLASS ( MOAIFooMgr )
	REGISTER_LUA_CLASS ( MOAIFont )
	REGISTER_LUA_CLASS ( MOAIFrameBuffer )
	REGISTER_LUA_CLASS ( MOAIFrameBufferTexture )
	REGISTER_LUA_CLASS ( MOAIFreeTypeFont )
	REGISTER_LUA_CLASS ( MOAIGfxDevice )
	REGISTER_LUA_CLASS ( MOAIGfxQuad2D )
	REGISTER_LUA_CLASS ( MOAIGfxQuadDeck2D )
	REGISTER_LUA_CLASS ( MOAIGfxQuadListDeck2D )
	REGISTER_LUA_CLASS ( MOAIGrid )
	REGISTER_LUA_CLASS ( MOAIGridDeck2D )
	REGISTER_LUA_CLASS ( MOAIGridSpace )
	REGISTER_LUA_CLASS ( MOAIGridPathGraph )
	REGISTER_LUA_CLASS ( MOAIHashWriter )
	REGISTER_LUA_CLASS ( MOAIImage )
	REGISTER_LUA_CLASS ( MOAIImageTexture )
	REGISTER_LUA_CLASS ( MOAIIndexBuffer )
	REGISTER_LUA_CLASS ( MOAIInputDevice )
	REGISTER_LUA_CLASS ( MOAIInputMgr )
	REGISTER_LUA_CLASS ( MOAIJoystickSensor )
	REGISTER_LUA_CLASS ( MOAIJsonParser )
	REGISTER_LUA_CLASS ( MOAIKeyboardSensor )
	REGISTER_LUA_CLASS ( MOAILayer )
	REGISTER_LUA_CLASS ( MOAILayerBridge )
	//REGISTER_LUA_CLASS ( MOAILayoutFrame )
	REGISTER_LUA_CLASS ( MOAILocationSensor )
	REGISTER_LUA_CLASS ( MOAILogMgr )
	REGISTER_LUA_CLASS ( MOAIMath )
	REGISTER_LUA_CLASS ( MOAIMemStream )
	REGISTER_LUA_CLASS ( MOAIMesh )
	REGISTER_LUA_CLASS ( MOAIMotionSensor )
	REGISTER_LUA_CLASS ( MOAIMultiTexture )
	REGISTER_LUA_CLASS ( MOAIParser )
	REGISTER_LUA_CLASS ( MOAIPartition )
	REGISTER_LUA_CLASS ( MOAIPathFinder )
	REGISTER_LUA_CLASS ( MOAIPathTerrainDeck )
	REGISTER_LUA_CLASS ( MOAIPointerSensor )
	REGISTER_LUA_CLASS ( MOAIProp )
	REGISTER_LUA_CLASS ( MOAIRenderMgr )
	REGISTER_LUA_CLASS ( MOAIScissorRect )
	REGISTER_LUA_CLASS ( MOAIScriptDeck )
	REGISTER_LUA_CLASS ( MOAIScriptNode )
	REGISTER_LUA_CLASS ( MOAISerializer )
	REGISTER_LUA_CLASS ( MOAIShader )
	REGISTER_LUA_CLASS ( MOAIShaderMgr )
	REGISTER_LUA_CLASS ( MOAISim )
	REGISTER_LUA_CLASS ( MOAIStaticGlyphCache )
	REGISTER_LUA_CLASS ( MOAIStreamReader )
	REGISTER_LUA_CLASS ( MOAIStreamWriter )
	REGISTER_LUA_CLASS ( MOAIStretchPatch2D )
	REGISTER_LUA_CLASS ( MOAISurfaceDeck2D )
	REGISTER_LUA_CLASS ( MOAITaskSubscriber )
	REGISTER_LUA_CLASS ( MOAITaskQueue )
	REGISTER_LUA_CLASS ( MOAITaskThread )
	REGISTER_LUA_CLASS ( MOAITextBundle )
	REGISTER_LUA_CLASS ( MOAITextBox )
	REGISTER_LUA_CLASS ( MOAITextStyle )
	REGISTER_LUA_CLASS ( MOAITextRenderer )
	REGISTER_LUA_CLASS ( MOAITexture )
	REGISTER_LUA_CLASS ( MOAITextureRaw )
	REGISTER_LUA_CLASS ( MOAITileDeck2D )
	REGISTER_LUA_CLASS ( MOAITimer )
	REGISTER_LUA_CLASS ( MOAITouchSensor )
	REGISTER_LUA_CLASS ( MOAITransform )
	REGISTER_LUA_CLASS ( MOAIVertexBuffer )
	REGISTER_LUA_CLASS ( MOAIVertexFormat )
	REGISTER_LUA_CLASS ( MOAIViewport )
	REGISTER_LUA_CLASS ( MOAIWheelSensor )
	REGISTER_LUA_CLASS ( MOAIXmlParser )
	
	#if USE_BOX2D
		REGISTER_LUA_CLASS ( MOAIBox2DArbiter )
		REGISTER_LUA_CLASS ( MOAIBox2DBody )
		REGISTER_LUA_CLASS ( MOAIBox2DDistanceJoint )
		REGISTER_LUA_CLASS ( MOAIBox2DFixture )
		REGISTER_LUA_CLASS ( MOAIBox2DFrictionJoint )
		REGISTER_LUA_CLASS ( MOAIBox2DGearJoint )
		REGISTER_LUA_CLASS ( MOAIBox2DMouseJoint )
		REGISTER_LUA_CLASS ( MOAIBox2DPrismaticJoint )
		REGISTER_LUA_CLASS ( MOAIBox2DPulleyJoint )
		REGISTER_LUA_CLASS ( MOAIBox2DRopeJoint )
		REGISTER_LUA_CLASS ( MOAIBox2DRevoluteJoint )
		REGISTER_LUA_CLASS ( MOAIBox2DWeldJoint )
		REGISTER_LUA_CLASS ( MOAIBox2DWheelJoint )
		REGISTER_LUA_CLASS ( MOAIBox2DWorld )
	#endif
	
	#if USE_CHIPMUNK
	
		MOAICp::Affirm ();
	
		REGISTER_LUA_CLASS ( MOAICp )
		REGISTER_LUA_CLASS ( MOAICpArbiter )
		REGISTER_LUA_CLASS ( MOAICpBody )
		REGISTER_LUA_CLASS ( MOAICpConstraint )
		REGISTER_LUA_CLASS ( MOAICpShape )
		REGISTER_LUA_CLASS ( MOAICpSpace )
	#endif
	
	#if USE_FREETYPE
		REGISTER_LUA_CLASS ( MOAIFreeTypeFontReader )
	#endif

	#if MOAI_OS_NACL
		REGISTER_LUA_CLASS ( MOAIHttpTaskNaCl )
	#endif
	
	MOAIEnvironment::Get ().DetectEnvironment ();
}

//----------------------------------------------------------------//
void moaicore::SystemFinalize () {

	MOAIGlobalsMgr::Finalize ();
	
	zl_cleanup ();
}

//----------------------------------------------------------------//
void moaicore::SystemInit () {

	_typeCheck ();
		
	srand (( u32 )time ( 0 ));
	zl_init ();
	
	#if USE_CHIPMUNK
		cpInitChipmunk ();
	#endif
}

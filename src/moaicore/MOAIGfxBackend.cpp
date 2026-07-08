// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#include "pch.h"

#include <moaicore/MOAIGfxBackend.h>
#include <moaicore/MOAIGfxBackendGL.h>

#if defined ( MOAI_OS_OSX ) || defined ( MOAI_OS_IPHONE )
	#include <moaicore/metal/MOAIGfxBackendMetal.h>
#endif

//================================================================//
// MOAIGfx
//================================================================//

namespace {

	static MOAIGfxBackend* sBackend = 0;
}

namespace MOAIGfx {

	//----------------------------------------------------------------//
	MOAIGfxBackend& Get () {

		// Lazy default: native Metal on Apple platforms (OpenGL rendering,
		// previously provided via MetalANGLE, is no longer supported there);
		// OpenGL everywhere else (Android, desktop GL hosts).
		if ( !sBackend ) {
			#if defined ( MOAI_OS_OSX ) || defined ( MOAI_OS_IPHONE )
				sBackend = new MOAIGfxBackendMetal ();
			#else
				sBackend = new MOAIGfxBackendGL ();
			#endif
		}
		return *sBackend;
	}

	//----------------------------------------------------------------//
	void Set ( MOAIGfxBackend* backend ) {

		if ( sBackend != backend ) {
			delete sBackend;
			sBackend = backend;
		}
	}

	//----------------------------------------------------------------//
	bool IsSet () {

		return ( sBackend != 0 );
	}
}

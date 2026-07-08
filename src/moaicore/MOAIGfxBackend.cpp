// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#include "pch.h"

#include <moaicore/MOAIGfxBackend.h>
#include <moaicore/MOAIGfxBackendGL.h>

//================================================================//
// MOAIGfx
//================================================================//

namespace {

	static MOAIGfxBackend* sBackend = 0;
}

namespace MOAIGfx {

	//----------------------------------------------------------------//
	MOAIGfxBackend& Get () {

		// lazily install the OpenGL backend so all existing hosts keep
		// working with zero changes
		if ( !sBackend ) {
			sBackend = new MOAIGfxBackendGL ();
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

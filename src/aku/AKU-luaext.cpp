// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#include <aku/AKU-luaext.h>
#include <moaicore/moaicore.h>

extern "C" {	
	extern int luaopen_lfs				( lua_State *L );
	extern int luaopen_luasql_sqlite3	( lua_State *L );
	extern int luapreload_fullluasocket ( lua_State *L );
	extern int luaopen_luatrace_c_hook  ( lua_State *L );
}

//================================================================//
// AKU-luaext
//================================================================//

//----------------------------------------------------------------//
void AKUExtLoadLuafilesystem () {

	lua_State* state = AKUGetLuaState ();
	luaopen_lfs ( state );
}

//----------------------------------------------------------------//
void AKUExtLoadLuasocket () {

	lua_State* state = AKUGetLuaState ();
	luapreload_fullluasocket ( state );
}

//----------------------------------------------------------------//
void AKUExtLoadLuasql () {

	lua_State* state = AKUGetLuaState ();
	luaopen_luasql_sqlite3 ( state );
}

//----------------------------------------------------------------//
void AKUExtLoadLuatrace () {

	lua_State* state = AKUGetLuaState ();
	luaopen_luatrace_c_hook ( state );
}

#ifndef USLSCORE_PCH_H
#define	USLSCORE_PCH_H

#ifndef TIXML_USE_STL
	#define TIXML_USE_STL
#endif

// lua
extern "C" {
	#include <lua.h>
	#include <lauxlib.h>
	#include <lualib.h>
}

// vfs
#include <zlcore/pch.h>
#include <zlcore/zlcore.h>

// stl
#include <memory>
#include <limits>
#include <string>
#include <vector>
#include <list>
#include <set>
#include <map>

using namespace std;

// stream
#include <fstream>
#include <iostream>
#include <iomanip>
#include <fstream>
#include <sstream>

//----------------------------------------------------------------//
typedef uint32_t			uint;
typedef size_t				uintptr;
typedef long				sintptr;

typedef const char			cc8;

typedef u_int8_t			u8;
typedef u_int16_t			u16;
typedef u_int32_t			u32;
typedef u_int64_t			u64;

typedef int8_t				s8;
typedef int16_t				s16;
typedef int32_t				s32;
typedef int64_t				s64;

#endif

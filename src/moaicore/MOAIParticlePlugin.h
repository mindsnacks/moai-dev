// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#ifndef	MOAIPARTICLEPLUGIN_H
#define	MOAIPARTICLEPLUGIN_H

#include <moaicore/MOAILua.h>
#include <aku/AKU-particles.h>

//================================================================//
// MOAIParticlePlugin
//================================================================//
/**	@name	MOAIParticlePlugin
	@text	Allows custom particle processing.
*/
class MOAIParticlePlugin :
	public virtual MOAILuaObject {
protected:

	int				mSize;

	//----------------------------------------------------------------//
	static int		_getSize			( lua_State* L );
	static int		_setProperty		( lua_State* L );

	//----------------------------------------------------------------//
	/**	@name	SetProperty
	 @text	Sets a property's value. Subclasses may implement this if they wish.
	        Property values must be fetched from the LUA state.

	 @in	string name		Name of the property to set
	 @in	state			The current LUA state
	 @out	nil
	 */
	virtual void	SetProperty			(__unused cc8* name, __unused MOAILuaState &state) {}
public:
	
	//----------------------------------------------------------------//
					MOAIParticlePlugin			();
					~MOAIParticlePlugin			();	
	virtual void	OnInit						( float* particle, float* registers ) = 0;
	virtual void	OnRender					( float* particle, float* registers, AKUParticleSprite* sprite, float t0, float t1, float term ) = 0;
	void			RegisterLuaClass			( MOAILuaState& state );
	void			RegisterLuaFuncs			( MOAILuaState& state );
};

#endif

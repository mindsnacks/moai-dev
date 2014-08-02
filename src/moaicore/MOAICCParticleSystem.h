//
//  MOAICCParticleSystem.h
//  libmoai
//
//  Created by Isaac Barrett on 7/30/14.
//
//

#ifndef MOAICCPARTICLESYSTEM_H
#define MOAICCPARTICLESYSTEM_H

#include <moaicore/MOAIProp.h>

#include <moaicore/MOAICCParticle.h>

#include <tinyxml.h>

class MOAICCParticleSystem : public virtual MOAIProp {
private:
	
	enum EmitterType{
		EMITTER_GRAVITY,
		EMITTER_RADIAL,
	};
	
	
	// Array of particles.
	MOAICCParticle *mParticles;
	u32 mParticleCount;
	u32 mAllocatedParticles;
	
	// Maximum particles.
	u32 mTotalParticles;
	
	
	EmitterType mEmitterType;
	
	float mLifespan;
	float mLifespanVariance;
	float mLifespanTerm[2];
	
	float mAngle;
	float mAngleVariance;
	
	float mStartColor[4];
	float mStartColorVariance[4];
	
	float mFinishColor[4];
	float mFinishColorVariance[4];
	
	float mStartSize;
	float mStartSizeVariance;
	
	float mFinishSize;
	float mFinishSizeVariance;
	
	float mGravity[2];
	float mGravityVariance[2];
	
	float mMaxRadius;
	float mMaxRadiusVariance;
	
	float mMinRadius;
	float mMinRadiusVariance;
	
	float mRadialAcceleration;
	float mRadialAccelVariance;
	
	float mTangentialAcceleration;
	float mTangentialAccelVariance;
	
	float mRotStart;
	float mRotStartVariance;
	
	float mRotEnd;
	float mRotEndVariance;
	
	float mSpeed;
	float mSpeedVariance;
	
	float mRotPerSecond;
	float mRotPerSecondVariance;
	
	// Rotational acceleration
	float mRotationalAcceleration;
	float mRotationalAccelVariance;
	
	float mSourcePos[2];
	float mSourcePosVariance[2];
	
	float mDuration;
	
	u32 mBlendFuncSrc;
	u32	mBlendFuncDst;
	
	STLString mTextureName;
	STLString mParticlePath;
	
	// Emission information.
	float mEmitCounter;
	float mEmissionRate;
	
	// time since start of system in seconds.
	float mElapsed;
	
	// true if the particle system is active
	bool mActive;
	
	// TODO: add methods for accessing properties
	
	static int		_initializeProperties				( lua_State* L );
	static int		_load								( lua_State* L );
	static int		_start								( lua_State* L );
	static int		_stop       						( lua_State* L );
	static int		_reset								( lua_State* L );
	
	
	bool			AddParticle							();
	void			InitParticle						( MOAICCParticle *particle );
	bool			IsFull								();
	void			OnDepNodeUpdate						();
	void			OnUpdate							( float step );
	void			ParseXML							( cc8* filename, TiXmlNode* node );
	
public:
	DECL_LUA_FACTORY ( MOAICCParticleSystem )
	
	
	void			Draw					( int subPrimID );
					MOAICCParticleSystem	();
					~MOAICCParticleSystem	();
	
	void			RegisterLuaClass		( MOAILuaState& state );
	void			RegisterLuaFuncs		( MOAILuaState& state );
	
	void			SetVisible				( bool visible );
	void			ResetSystem				();
	void			StartSystem				();
	void			StopSystem				();
	
};


#endif /* defined(MOAICCPARTICLESYSTEM_H) */
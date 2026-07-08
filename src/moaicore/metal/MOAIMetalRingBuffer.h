// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#ifndef MOAIMETALRINGBUFFER_H
#define MOAIMETALRINGBUFFER_H

// ObjC++ header: include only from .mm files, after <moaicore/pch.h>.
#if ( defined ( MOAI_OS_OSX ) || defined ( MOAI_OS_IPHONE )) && defined ( __OBJC__ )

#import <Metal/Metal.h>
#include <vector>

//================================================================//
// MOAIMetalRingBuffer
//================================================================//
// Transient per-frame GPU allocations (streamed vertex data, generated index
// lists, staging uploads). Two slots, indexed by frame parity; each slot owns
// a list of storageModeShared MTLBuffer slabs that grow on demand and are
// reused forever.
//
// SAFETY MODEL: MOAIGfxBackendMetal keeps at most two frames in flight
// (dispatch semaphore, count 2). BeginFrame ( N ) blocks until frame N-2 has
// completed on the GPU, and frame N reuses slot N & 1 == ( N-2 ) & 1, so by
// the time a slot's cursor is reset every command buffer that referenced its
// slabs has finished. No locking is required: all allocation happens on the
// single render thread, and completed-handler recycling is unnecessary.
class MOAIMetalRingBuffer {
public:

	struct Allocation {
		id < MTLBuffer >	mBuffer;
		size_t				mOffset;
		void*				mPtr;
	};

private:

	static const size_t SLAB_SIZE = 1024 * 1024;	// initial/minimum slab size
	static const size_t ALIGNMENT = 16;

	struct Slab {
		id < MTLBuffer >	mBuffer;
		size_t				mCapacity;
	};

	struct Slot {
		std::vector < Slab >	mSlabs;
		size_t					mSlabIdx;
		size_t					mOffset;

		Slot () : mSlabIdx ( 0 ), mOffset ( 0 ) {}
	};

	id < MTLDevice >	mDevice;
	Slot				mSlots [ 2 ];
	u32					mCurrent;

public:

	//----------------------------------------------------------------//
	MOAIMetalRingBuffer () :
		mDevice ( nil ),
		mCurrent ( 0 ) {
	}

	//----------------------------------------------------------------//
	void SetDevice ( id < MTLDevice > device ) {
		this->mDevice = device;
	}

	//----------------------------------------------------------------//
	// Rewind the slot for a new frame. Only call after the previous command
	// buffer that used this slot has completed (see safety model above).
	void BeginFrame ( u32 frameParity ) {

		this->mCurrent = frameParity & 1;
		Slot& slot = this->mSlots [ this->mCurrent ];
		slot.mSlabIdx = 0;
		slot.mOffset = 0;
	}

	//----------------------------------------------------------------//
	// Suballocate size bytes (16-byte aligned) from the current slot.
	bool Allocate ( size_t size, Allocation& out ) {

		if ( !this->mDevice ) return false;

		Slot& slot = this->mSlots [ this->mCurrent ];

		for ( ;; ) {

			if ( slot.mSlabIdx < slot.mSlabs.size ()) {

				Slab& slab = slot.mSlabs [ slot.mSlabIdx ];
				size_t offset = ( slot.mOffset + ( ALIGNMENT - 1 )) & ~( ALIGNMENT - 1 );

				if (( offset + size ) <= slab.mCapacity ) {

					out.mBuffer = slab.mBuffer;
					out.mOffset = offset;
					out.mPtr = ( void* )(( uint8_t* )[ slab.mBuffer contents ] + offset );
					slot.mOffset = offset + size;
					return true;
				}

				// current slab full; move to the next
				slot.mSlabIdx++;
				slot.mOffset = 0;
				continue;
			}

			// need a new slab
			size_t capacity = size > SLAB_SIZE ? size : SLAB_SIZE;
			id < MTLBuffer > buffer = [ this->mDevice newBufferWithLength:capacity options:MTLResourceStorageModeShared ];
			if ( !buffer ) return false;

			Slab slab;
			slab.mBuffer = buffer;
			slab.mCapacity = capacity;
			slot.mSlabs.push_back ( slab );
			slot.mSlabIdx = slot.mSlabs.size () - 1;
			slot.mOffset = 0;
		}
	}
};

#endif
#endif

// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#ifndef MOAIPVRHEADER_H
#define MOAIPVRHEADER_H

#include <string.h>

//================================================================//
// MOAIPvrHeader
//================================================================//
class MOAIPvrHeader {
public:
	struct Info {
		u32 mWidth;
		u32 mHeight;
		u32 mMipLevels;		// including the base level, so 1 means no mipmaps
		u32 mPFFlags;
		u32 mBitCount;
		u32 mAlphaBitMask;
		size_t mDataOffset;
		bool mIsPVR3;
	};

	struct PVR3Header {
		u32 mVersion;
		u32 mFlags;
		unsigned long long mPixelFormat;
		u32 mColorSpace;
		u32 mChannelType;
		u32 mHeight;
		u32 mWidth;
		u32 mDepth;
		u32 mNumSurfs;
		u32 mNumFaces;
		u32 mMipMapCount;
		u32 mMetaDataSize;
	};

	
	static const u32 HEADER_SIZE		= 52;
	static const u32 PVR_FILE_MAGIC		= 0x21525650; // 'P' 'V' 'R' '!'
	static const u32 PVR3_FILE_MAGIC		= 0x03525650;
	static const u32 PF_MASK			= 0xff;
	
	enum {
		OGL_RGBA_4444		= 0x10,
		OGL_RGBA_5551,
		OGL_RGBA_8888,
		OGL_RGB_565,
		OGL_RGB_555,
		OGL_RGB_888,
		OGL_I_8,
		OGL_AI_88,
		OGL_PVRTC2,
		OGL_PVRTC4,
		OGL_BGRA_8888,
		OGL_A_8,
	};
	
	u32 mHeaderSize;	// size of the structure
	u32 mHeight;		// height of surface to be created
	u32 mWidth;			// width of input surface
	u32 mMipMapCount;	// number of MIP-map levels requested
	u32 mPFFlags;		// pixel format flags
	u32 mDataSize;		// Size of the compress data
	u32 mBitCount;		// number of bits per pixel
	u32 mRBitMask;		// mask for red bit
	u32 mGBitMask;		// mask for green bits
	u32 mBBitMask;		// mask for blue bits
	u32 mAlphaBitMask;	// mask for alpha channel
	u32 mPVR;			// should be 'P' 'V' 'R' '!'
	u32 mNumSurfs;

	////----------------------------------------------------------------//
	static void* GetFileData ( void* data, size_t size ) {
	
		if ( data && ( size >= HEADER_SIZE )) {
			return ( void* )(( size_t )data + HEADER_SIZE );
		}
		return 0;
	}

	//----------------------------------------------------------------//
	size_t GetTotalSize () {
	
		return HEADER_SIZE + this->mDataSize;
	}

	//----------------------------------------------------------------//
	bool IsValid () {
		return this->mPVR == PVR_FILE_MAGIC;
	}

	//----------------------------------------------------------------//
	void Load ( USStream& stream ) {
		
		assert ( HEADER_SIZE <= sizeof ( MOAIPvrHeader ));
		
		this->mPVR = 0;
		stream.PeekBytes ( this, HEADER_SIZE );
	}

	//----------------------------------------------------------------//
	static MOAIPvrHeader* GetHeader ( const void* data, size_t size ) {
	
		if ( data && ( size >= HEADER_SIZE )) {
			MOAIPvrHeader* header = ( MOAIPvrHeader* )data;
			if ( header->mPVR == PVR_FILE_MAGIC ) {
				return header;
			}
		}
		return 0;
	}
	
	//----------------------------------------------------------------//
	static bool GetInfo ( const void* data, size_t size, Info& info ) {
		if ( !data || size < HEADER_SIZE ) return false;

		MOAIPvrHeader* pvr2 = GetHeader ( data, size );
		if ( pvr2 ) {
			if ( pvr2->mDataSize > size - HEADER_SIZE ) return false;
			info.mWidth = pvr2->mWidth;
			info.mHeight = pvr2->mHeight;
			info.mMipLevels = pvr2->mMipMapCount + 1;
			info.mPFFlags = pvr2->mPFFlags;
			info.mBitCount = pvr2->mBitCount;
			info.mAlphaBitMask = pvr2->mAlphaBitMask;
			info.mDataOffset = HEADER_SIZE;
			info.mIsPVR3 = false;
			return true;
		}

		PVR3Header pvr3;
		memcpy ( &pvr3, data, HEADER_SIZE );
		if ( pvr3.mVersion != PVR3_FILE_MAGIC ||
			pvr3.mPixelFormat != 0x0808080861626772ULL ||
			pvr3.mColorSpace > 1 || pvr3.mChannelType != 0 ||
			pvr3.mDepth != 1 || pvr3.mNumSurfs != 1 || pvr3.mNumFaces != 1 ||
			pvr3.mMipMapCount != 1 || !pvr3.mWidth || !pvr3.mHeight ||
			pvr3.mMetaDataSize > size - HEADER_SIZE ) return false;

		size_t dataOffset = HEADER_SIZE + pvr3.mMetaDataSize;
		if ( pvr3.mWidth > ( size - dataOffset ) / 4 / pvr3.mHeight ) return false;

		info.mWidth = pvr3.mWidth;
		info.mHeight = pvr3.mHeight;
		info.mMipLevels = pvr3.mMipMapCount;
		info.mPFFlags = 0;
		info.mBitCount = 32;
		info.mAlphaBitMask = 0xff000000;
		info.mDataOffset = dataOffset;
		info.mIsPVR3 = true;
		return true;
	}

	MOAIPvrHeader () {
		this->mPVR = 0;
	}
};

#endif

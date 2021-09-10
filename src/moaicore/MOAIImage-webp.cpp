// Copyright (c) 2010-2017 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#include "pch.h"
#include <moaicore/MOAILogMessages.h>
#include <moaicore/MOAIImage.h>

extern "C" {
	#include "webp/decode.h"
	#include "webp/demux.h"
}

void MOAIImage::LoadWebP( USStream& stream, u32 transform ) {
	WebPData data;
	data.size = stream.GetLength ();
	data.bytes = ( uint8_t* )malloc ( data.size );
	if ( !data.bytes ) return;
	stream.ReadBytes ( ( void* )data.bytes, data.size );

	// Create demuxer
	WebPDemuxer* demux = WebPDemux ( &data );

	// Read first frame (ignore any additional frames)
	WebPIterator iter;
	if ( WebPDemuxGetFrame ( demux, 1, &iter ) ) {
		this->LoadWebP ( iter.fragment.bytes, iter.fragment.size, iter.width, iter.height, iter.has_alpha != 0, transform );
	}

	// Clean up
	WebPDemuxReleaseIterator ( &iter );
	WebPDemuxDelete ( demux );
	WebPDataClear ( &data );
}

void MOAIImage::LoadWebP( const u8 *data, size_t dataSize, int width, int height, bool hasAlpha, u32 transform ) {
	bool isPadded = false;
	if ( (transform & MOAIImageTransform::POW_TWO) != 0 ) {
		this->mWidth = this->GetMinPowerOfTwo(width);
		this->mHeight = this->GetMinPowerOfTwo(height);
		isPadded = true;
	} else {
		this->mWidth = width;
		this->mHeight = height;
	}
	
	this->mPixelFormat = USPixel::TRUECOLOR;
	bool quantize = (transform & MOAIImageTransform::QUANTIZE) != 0;
	if ( hasAlpha ) {
		if ( quantize ) {
			this->mColorFormat = USColor::RGBA_4444;
		} else {
			this->mColorFormat = USColor::RGBA_8888;
		}
	} else {
		if ( quantize ) {
			this->mColorFormat = USColor::RGB_565;
		} else {
			this->mColorFormat = USColor::RGB_888;
		}
	}
	
	
	this->Alloc ();
	if ( isPadded ) {
		this->ClearBitmap ();
	}
	
	WebPDecoderConfig config;
	if ( !WebPInitDecoderConfig ( &config ) ) return;
	bool premultiply = (transform & MOAIImageTransform::PREMULTIPLY_ALPHA) != 0;
	switch ( this->mColorFormat ) {
		case USColor::RGBA_8888:
			if ( premultiply ) {
				config.output.colorspace = MODE_rgbA;
			} else {
				config.output.colorspace = MODE_RGBA;
			}
			break;
		case USColor::RGBA_4444:
			if ( premultiply ) {
				config.output.colorspace = MODE_rgbA_4444;
			} else {
				config.output.colorspace = MODE_RGBA_4444;
			}
			break;
		case USColor::RGB_888:
			config.output.colorspace = MODE_RGB;
			break;
		case USColor::RGB_565:
			config.output.colorspace = MODE_RGB_565;
			break;
		default:
			break;
	}
	config.output.u.RGBA.rgba = (u8 *) this->mBitmap;
	config.output.u.RGBA.stride = this->GetRowSize();
	config.output.u.RGBA.size = this->GetBitmapSize();
	config.output.is_external_memory = true;
	
	WebPDecode ( data, dataSize, &config );
	
	WebPFreeDecBuffer ( &config.output );
	
}

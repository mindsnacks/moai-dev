#================================================================#
# Copyright (c) 2010-2011 Zipline Games, Inc.
# All Rights Reserved.
# http://getmoai.com
#================================================================#

	include $(CLEAR_VARS)

	LOCAL_MODULE 		:= webp
	LOCAL_ARM_MODE 		:= $(MY_ARM_MODE)
	LOCAL_CFLAGS		:= -include $(MY_MOAI_ROOT)/src/zlcore/zl_replace.h

	LOCAL_C_INCLUDES 	:= $(MY_HEADER_SEARCH_PATHS)
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dec/alpha_dec.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dec/buffer_dec.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dec/frame_dec.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dec/idec_dec.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dec/io_dec.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dec/quant_dec.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dec/tree_dec.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dec/vp8_dec.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dec/vp8l_dec.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dec/webp_dec.c

	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/demux/anim_decode.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/demux/demux.c

	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/alpha_processing.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/alpha_processing_mips_dsp_r2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/alpha_processing_neon.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/alpha_processing_sse2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/alpha_processing_sse41.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/cpu.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/dec.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/dec_clip_tables.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/dec_mips32.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/dec_mips_dsp_r2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/dec_msa.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/dec_neon.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/dec_sse2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/dec_sse41.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/filters.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/filters_mips_dsp_r2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/filters_msa.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/filters_neon.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/filters_sse2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/lossless.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/lossless_mips_dsp_r2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/lossless_msa.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/lossless_neon.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/lossless_sse2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/lossless_sse41.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/rescaler.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/rescaler_mips32.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/rescaler_mips_dsp_r2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/rescaler_msa.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/rescaler_neon.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/rescaler_sse2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/upsampling.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/upsampling_mips_dsp_r2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/upsampling_msa.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/upsampling_neon.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/upsampling_sse2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/upsampling_sse41.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/yuv.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/yuv_mips32.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/yuv_mips_dsp_r2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/yuv_neon.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/yuv_sse2.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/dsp/yuv_sse41.c

	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/utils/bit_reader_utils.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/utils/color_cache_utils.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/utils/filters_utils.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/utils/huffman_utils.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/utils/quant_levels_dec_utils.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/utils/random_utils.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/utils/rescaler_utils.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/utils/thread_utils.c
	LOCAL_SRC_FILES 	+= $(MY_MOAI_ROOT)/3rdparty/libwebp/src/utils/utils.c

	include $(BUILD_STATIC_LIBRARY)

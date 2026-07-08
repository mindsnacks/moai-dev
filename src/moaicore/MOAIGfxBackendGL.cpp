// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#include "pch.h"

#include <moaicore/MOAIGfxBackendGL.h>
#include <moaicore/MOAIGfxDevice.h>
#include <moaicore/MOAILogMessages.h>
#include <moaicore/MOAIShader.h>
#include <moaicore/MOAIVertexFormat.h>

// from MOAIGfxDevice.cpp
#define REMAP_EXTENSION_PTR(target, ext) target = target ? target : ext;

// from MOAIShader.h (GL-specific shader source preamble)
#define		OPENGL_PREPROC		"#define LOWP\n #define MEDP\n #define HIGHP\n"
#define		OPENGL_ES_PREPROC	"#define LOWP lowp\n #define MEDP mediump\n #define HIGHP highp\n"

//================================================================//
// MOAIGfxBackendGL
//================================================================//

//----------------------------------------------------------------//
MOAIGfxBackendGL::MOAIGfxBackendGL () {
}

//----------------------------------------------------------------//
MOAIGfxBackendGL::~MOAIGfxBackendGL () {
}

//----------------------------------------------------------------//
MOAIGfxBackend::Backend MOAIGfxBackendGL::GetBackendID () const {

	return BACKEND_OPENGL;
}

//----------------------------------------------------------------//
void MOAIGfxBackendGL::BeginFrame () {
}

//----------------------------------------------------------------//
void MOAIGfxBackendGL::EndFrame () {
}

//----------------------------------------------------------------//
// from MOAIVertexFormat::Bind
void MOAIGfxBackendGL::BindVertexFormat ( const MOAIVertexFormat& format, void* buffer ) {

	if ( buffer ) {
		if ( MOAIGfxDevice::Get ().IsProgrammable ()) {
			this->BindVertexFormatProgrammable ( format, buffer );
		}
		else {
			this->BindVertexFormatFixed ( format, buffer );
		}
	}
}

//----------------------------------------------------------------//
// from MOAIVertexFormat::BindFixed
void MOAIGfxBackendGL::BindVertexFormatFixed ( const MOAIVertexFormat& format, void* buffer ) {

#if USE_OPENGLES1
	for ( u32 i = 0; i < MOAIVertexFormat::TOTAL_ARRAY_TYPES; ++i ) {

		const MOAIVertexAttributeUse& attrUse = format.mAttributeUseTable [ i ];

		if ( attrUse.mAttrID == MOAIVertexFormat::NULL_INDEX ) {
			glDisableClientState ( attrUse.mUse );
		}
		else {

			MOAIVertexAttribute& attr = format.mAttributes [ attrUse.mAttrID ];

			void* addr = ( void* )(( size_t )buffer + attr.mOffset );

			switch ( attrUse.mUse ) {
				case GL_COLOR_ARRAY:
					glColorPointer ( attr.mSize, attr.mType, format.mVertexSize, addr );
					break;
				case GL_NORMAL_ARRAY:
					glNormalPointer ( attr.mType, format.mVertexSize, addr );
					break;
				case GL_TEXTURE_COORD_ARRAY:
					glTexCoordPointer ( attr.mSize, attr.mType, format.mVertexSize, addr );
					break;
				case GL_VERTEX_ARRAY:
					glVertexPointer ( attr.mSize, attr.mType, format.mVertexSize, addr );
					break;
				default:
					break;
			}
			glEnableClientState ( attrUse.mUse );
		}
	}
#else
	UNUSED ( format );
	UNUSED ( buffer );
#endif
}

//----------------------------------------------------------------//
// from MOAIVertexFormat::BindProgrammable
void MOAIGfxBackendGL::BindVertexFormatProgrammable ( const MOAIVertexFormat& format, void* buffer ) {

	for ( u32 i = 0; i < format.mTotalAttributes; ++i ) {

		MOAIVertexAttribute& attr = format.mAttributes [ i ];

		void* addr = ( void* )(( size_t )buffer + attr.mOffset );
		glVertexAttribPointer (	attr.mIndex, attr.mSize, attr.mType, attr.mNormalized, format.mVertexSize, addr );
		glEnableVertexAttribArray ( attr.mIndex );
	}
}

//----------------------------------------------------------------//
// from MOAITextureBase::OnBind (glBindTexture + sampler params) and
// MOAIGfxDevice::DisableTextureUnits (unbind/disable path)
void MOAIGfxBackendGL::BindTexture ( u32 unit, MOAIGfxResID id, const MOAIGfxSamplerDesc* sampler ) {

	if ( !id ) {

		// disable path: the legacy GL code never unbound the texture name on
		// programmable pipelines; it only disabled GL_TEXTURE_2D under GLES1
		#if USE_OPENGLES1
			if ( !MOAIGfxDevice::Get ().IsProgrammable ()) {
				glActiveTexture ( GL_TEXTURE0 + unit );
				glDisable ( GL_TEXTURE_2D );
			}
		#else
			UNUSED ( unit );
		#endif
		return;
	}

	glActiveTexture ( GL_TEXTURE0 + unit );
	glBindTexture ( GL_TEXTURE_2D, ( GLuint )id );

	if ( sampler ) {

		#if USE_OPENGLES1
			if ( !MOAIGfxDevice::Get ().IsProgrammable ()) {
				glTexEnvf ( GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE );
			}
		#endif

		glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, sampler->mWrapS );
		glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, sampler->mWrapT );

		glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, sampler->mMinFilter );
		glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, sampler->mMagFilter );
	}
}

//----------------------------------------------------------------//
// from MOAIClearableView::ClearSurface / MOAIGfxDevice::ClearColorBuffer
void MOAIGfxBackendGL::Clear ( u32 glMask, float r, float g, float b, float a ) {

	if ( glMask & GL_COLOR_BUFFER_BIT ) {
		glClearColor ( r, g, b, a );
	}

	if ( glMask ) {
		glClear ( glMask );
	}
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::ResetState / USColorVec::LoadGfxState
void MOAIGfxBackendGL::Color4f ( float r, float g, float b, float a ) {

	#if USE_OPENGLES1
		glColor4f ( r, g, b, a );
	#else
		UNUSED ( r );
		UNUSED ( g );
		UNUSED ( b );
		UNUSED ( a );
	#endif
}

//----------------------------------------------------------------//
// from MOAIShader::CompileShader
GLuint MOAIGfxBackendGL::CompileShader ( GLuint type, cc8* source ) {

	MOAIGfxDevice& gfxDevice = MOAIGfxDevice::Get ();

	GLuint shader = glCreateShader ( type );
	cc8* sources [ 2 ];

	sources [ 0 ] = gfxDevice.IsOpenGLES () ? OPENGL_ES_PREPROC : OPENGL_PREPROC;
	sources [ 1 ] = source;

	glShaderSource ( shader, 2, sources, NULL );
	glCompileShader ( shader );

	this->PrintShaderLog ( shader );

	GLint status;
	glGetShaderiv ( shader, GL_COMPILE_STATUS, &status );

	if ( status == 0 ) {
		this->PrintShaderLog ( shader );
		glDeleteShader ( shader );
		return 0;
	}

	return shader;
}

//----------------------------------------------------------------//
// from MOAIFrameBufferTexture::OnCreate
MOAIGfxResID MOAIGfxBackendGL::CreateFrameBuffer ( u32 width, u32 height, u32 glColorFormat, u32 glDepthFormat, u32 glStencilFormat, MOAIGfxResID& outColorTexture, MOAIGfxResID& outColorBuffer, MOAIGfxResID& outDepthBuffer, MOAIGfxResID& outStencilBuffer, bool& outComplete ) {

	outColorTexture = 0;
	outColorBuffer = 0;
	outDepthBuffer = 0;
	outStencilBuffer = 0;
	outComplete = false;

	GLuint frameBufferID = 0;
	GLuint colorBufferID = 0;
	GLuint depthBufferID = 0;
	GLuint stencilBufferID = 0;

	// bail and retry (no error) if GL cannot generate buffer ID
	glGenFramebuffers ( 1, &frameBufferID );
	if ( !frameBufferID ) return 0;

	if ( glColorFormat ) {
		glGenRenderbuffers( 1, &colorBufferID );
		glBindRenderbuffer ( GL_RENDERBUFFER, colorBufferID );
		glRenderbufferStorage ( GL_RENDERBUFFER, glColorFormat, width, height );
	}

	if ( glDepthFormat ) {
		glGenRenderbuffers ( 1, &depthBufferID );
		glBindRenderbuffer ( GL_RENDERBUFFER, depthBufferID );
		glRenderbufferStorage ( GL_RENDERBUFFER, glDepthFormat, width, height );
	}

	if ( glStencilFormat ) {
		glGenRenderbuffers ( 1, &stencilBufferID );
		glBindRenderbuffer ( GL_RENDERBUFFER, stencilBufferID );
		glRenderbufferStorage ( GL_RENDERBUFFER, glStencilFormat, width, height );
	}

	glBindFramebuffer ( GL_FRAMEBUFFER, frameBufferID );

	if ( colorBufferID ) {
		glFramebufferRenderbuffer ( GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorBufferID );
	}

	if ( depthBufferID ) {
		glFramebufferRenderbuffer ( GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthBufferID );
	}

	if ( stencilBufferID ) {
		glFramebufferRenderbuffer ( GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, stencilBufferID );
	}

	// TODO: handle error; clear
	GLenum status = glCheckFramebufferStatus ( GL_FRAMEBUFFER );

	GLuint texID = 0;
	if ( status == GL_FRAMEBUFFER_COMPLETE ) {

		glGenTextures ( 1, &texID );
		glBindTexture ( GL_TEXTURE_2D, texID );
		glTexImage2D ( GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0 );
		glFramebufferTexture2D ( GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texID, 0 );

		outComplete = true;
	}

	outColorTexture = texID;
	outColorBuffer = colorBufferID;
	outDepthBuffer = depthBufferID;
	outStencilBuffer = stencilBufferID;

	return frameBufferID;
}

//----------------------------------------------------------------//
// from MOAIIndexBuffer::OnCreate
MOAIGfxResID MOAIGfxBackendGL::CreateIndexBuffer ( const u16* indices, u32 count ) {

	GLuint bufferID = 0;

	glGenBuffers ( 1, &bufferID );
	if ( bufferID ) {

		glBindBuffer ( GL_ELEMENT_ARRAY_BUFFER, bufferID );
		glBufferData ( GL_ELEMENT_ARRAY_BUFFER, count * sizeof ( u16 ), indices, GL_STATIC_DRAW );
	}
	return bufferID;
}

//----------------------------------------------------------------//
// from MOAIShader::OnCreate
MOAIGfxResID MOAIGfxBackendGL::CreateProgram ( const MOAIGfxShaderProgramDesc& desc ) {

	GLuint vertexShader = this->CompileShader ( GL_VERTEX_SHADER, desc.mVertexSource );
	GLuint fragmentShader = this->CompileShader ( GL_FRAGMENT_SHADER, desc.mFragmentSource );
	GLuint program = glCreateProgram ();

	if ( !( vertexShader && fragmentShader && program )) {
		if ( vertexShader ) {
			glDeleteShader ( vertexShader );
		}
		if ( fragmentShader ) {
			glDeleteShader ( fragmentShader );
		}
		if ( program ) {
			glDeleteProgram ( program );
		}
		return 0;
	}

	glAttachShader ( program, vertexShader );
	glAttachShader ( program, fragmentShader );

	// bind attribute locations.
	// this needs to be done prior to linking.
	for ( u32 i = 0; i < desc.mAttributeCount; ++i ) {
		glBindAttribLocation ( program, desc.mAttributeIndices [ i ], desc.mAttributeNames [ i ]);
	}

    // link program.
	glLinkProgram ( program );

	this->PrintProgramLog ( program );

	GLint status;
	glGetProgramiv ( program, GL_LINK_STATUS, &status );

	if ( status == 0 ) {
		glDeleteShader ( vertexShader );
		glDeleteShader ( fragmentShader );
		glDeleteProgram ( program );
		return 0;
	}

	glDeleteShader ( vertexShader );
	glDeleteShader ( fragmentShader );

	return program;
}

//----------------------------------------------------------------//
// from MOAITextureBase::CreateTextureFromImage / CreateTextureFromPVR
// (glGenTextures/glBindTexture plus the mip level 0 upload)
MOAIGfxResID MOAIGfxBackendGL::CreateTexture ( const MOAIGfxTextureDesc& desc, const void* data, size_t dataSize ) {

	GLuint texID = 0;

	glGenTextures ( 1, &texID );
	if ( !texID ) return 0;

	glBindTexture ( GL_TEXTURE_2D, texID );

	if ( desc.mIsCompressed ) {
		glCompressedTexImage2D ( GL_TEXTURE_2D, 0, desc.mGLInternalFormat, desc.mWidth, desc.mHeight, 0, ( GLsizei )dataSize, data );
	}
	else {
		glTexImage2D (
			GL_TEXTURE_2D,
			0,
			desc.mGLInternalFormat,
			desc.mWidth,
			desc.mHeight,
			0,
			desc.mGLInternalFormat,
			desc.mGLPixelType,
			data
		);
	}

	return texID;
}

//----------------------------------------------------------------//
// from MOAIGfxDeleter::Delete
void MOAIGfxBackendGL::DeleteResource ( u32 type, MOAIGfxResID id ) {

	GLuint resourceID = ( GLuint )id;

	switch ( type ) {

		case MOAIGfxDeleter::DELETE_BUFFER:
			glDeleteBuffers ( 1, &resourceID );
			break;

		case MOAIGfxDeleter::DELETE_FRAMEBUFFER:
			glDeleteFramebuffers ( 1, &resourceID );
			break;

		case MOAIGfxDeleter::DELETE_PROGRAM:
			glDeleteProgram ( resourceID );
			break;

		case MOAIGfxDeleter::DELETE_SHADER:
			glDeleteShader ( resourceID );
			break;

		case MOAIGfxDeleter::DELETE_TEXTURE:
			glDeleteTextures ( 1, &resourceID );
			break;

		case MOAIGfxDeleter::DELETE_RENDERBUFFER:
			glDeleteRenderbuffers ( 1, &resourceID );
			break;
	}
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::DetectContext
bool MOAIGfxBackendGL::DetectContext ( MOAIGfxCaps& caps ) {

	#ifdef __GLEW_H__
		static bool initGlew = true;
		if ( initGlew ) {
			glewInit ();
			initGlew = false;
		}
	#endif

	const GLubyte* driverVersion = glGetString ( GL_VERSION );

	STLString version = ( cc8* )driverVersion;
	version.to_lower ();

	STLString gles = "opengl es";

	if ( version.find ( gles ) != version.npos ) {
		caps.mIsOpenGLES = true;
		version = version.substr ( gles.length ());

		size_t space = version.find ( ' ' );
		if ( space != version.npos ) {
			version = version.substr ( space + 1 );
		}
	}
	else {
		caps.mIsOpenGLES = false;
	}

	version = version.substr ( 0, 3 );

	caps.mMajorVersion = version.at ( 0 ) - '0';
	caps.mMinorVersion = version.at ( 2 ) - '0';

	caps.mIsProgrammable = ( caps.mMajorVersion >= 2 );
	caps.mIsFramebufferSupported = true;

	#if defined ( __GLEW_H__ )

		// if framebuffer object is not in code, check to see if it's available as
		// an extension and remap to core function pointers if so
		if (( caps.mIsOpenGLES == false ) && ( caps.mMajorVersion < 3 )) {

			if ( glewIsSupported ( "GL_EXT_framebuffer_object" )) {

				REMAP_EXTENSION_PTR ( glBindFramebuffer,						glBindFramebufferEXT )
				REMAP_EXTENSION_PTR ( glCheckFramebufferStatus,					glCheckFramebufferStatusEXT )
				REMAP_EXTENSION_PTR ( glDeleteFramebuffers,						glDeleteFramebuffersEXT )
				REMAP_EXTENSION_PTR ( glDeleteRenderbuffers,					glDeleteRenderbuffersEXT )
				REMAP_EXTENSION_PTR ( glFramebufferRenderbuffer,				glFramebufferRenderbufferEXT )
				REMAP_EXTENSION_PTR ( glFramebufferTexture1D,					glFramebufferTexture1DEXT )
				REMAP_EXTENSION_PTR ( glFramebufferTexture2D,					glFramebufferTexture2DEXT )
				REMAP_EXTENSION_PTR ( glFramebufferTexture3D,					glFramebufferTexture3DEXT )
				REMAP_EXTENSION_PTR ( glGenFramebuffers,						glGenFramebuffersEXT )
				REMAP_EXTENSION_PTR ( glGenRenderbuffers,						glGenRenderbuffersEXT )
				REMAP_EXTENSION_PTR ( glGenerateMipmap,							glGenerateMipmapEXT )
				REMAP_EXTENSION_PTR ( glGetFramebufferAttachmentParameteriv,	glGetFramebufferAttachmentParameterivEXT )
				REMAP_EXTENSION_PTR ( glGetRenderbufferParameteriv,				glGetRenderbufferParameterivEXT )
				REMAP_EXTENSION_PTR ( glIsFramebuffer,							glIsFramebufferEXT )
				REMAP_EXTENSION_PTR ( glIsRenderbuffer,							glIsRenderbufferEXT )
				REMAP_EXTENSION_PTR ( glRenderbufferStorage,					glRenderbufferStorageEXT )
			}
			else {
				// looks like frame buffer isn't supported
				caps.mIsFramebufferSupported = false;
			}
		}
	#endif

	int maxTextureUnits = 0;
	if ( caps.mMajorVersion == 1 ) {
		#if USE_OPENGLES1
			glGetIntegerv ( GL_MAX_TEXTURE_UNITS, &maxTextureUnits );
		#endif
	}
	else {
		glGetIntegerv ( GL_MAX_TEXTURE_IMAGE_UNITS, &maxTextureUnits );
	}
	caps.mMaxTextureUnits = maxTextureUnits;

	int maxTextureSize;
	glGetIntegerv ( GL_MAX_TEXTURE_SIZE, &maxTextureSize );
	caps.mMaxTextureSize = maxTextureSize;

	return true;
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::DrawPrims / MOAIMesh::DrawIndex (glDrawArrays)
void MOAIGfxBackendGL::DrawArrays ( u32 glPrimType, u32 count, const MOAIVertexFormat& format, const void* buffer, size_t sizeInBytes ) {
	UNUSED ( sizeInBytes );

	this->BindVertexFormat ( format, ( void* )buffer );

	glDrawArrays ( glPrimType, 0, count );

	this->UnbindVertexFormat ( format );
}

//----------------------------------------------------------------//
// from MOAIMesh::DrawIndex (glDrawElements) + MOAIIndexBuffer::OnBind
void MOAIGfxBackendGL::DrawIndexed ( u32 glPrimType, u32 indexCount, MOAIGfxResID indexBuffer, const MOAIVertexFormat& format, const void* buffer, size_t sizeInBytes ) {
	UNUSED ( sizeInBytes );

	this->BindVertexFormat ( format, ( void* )buffer );

	if ( indexBuffer ) {
		glBindBuffer ( GL_ELEMENT_ARRAY_BUFFER, ( GLuint )indexBuffer );
	}
	glDrawElements ( glPrimType, indexCount, GL_UNSIGNED_SHORT, 0 );

	this->UnbindVertexFormat ( format );
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::SoftReleaseResources
void MOAIGfxBackendGL::FlushHint () {

	glFlush ();
}

//----------------------------------------------------------------//
u32 MOAIGfxBackendGL::GetError () {

	return ( u32 )glGetError ();
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::GetErrorString
cc8* MOAIGfxBackendGL::GetErrorString ( u32 error ) {

	switch ( error ) {
		case GL_INVALID_ENUM:		return "GL_INVALID_ENUM";
		case GL_INVALID_VALUE:		return "GL_INVALID_VALUE";
		case GL_INVALID_OPERATION:	return "GL_INVALID_OPERATION";

		#if USE_OPENGLES1
			case GL_STACK_OVERFLOW:		return "GL_STACK_OVERFLOW";
			case GL_STACK_UNDERFLOW:	return "GL_STACK_UNDERFLOW";
		#endif

		case GL_OUT_OF_MEMORY:		return "GL_OUT_OF_MEMORY";
	}
	return "";
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::ResetState / UpdateGpuVertexMtx (glLoadIdentity)
void MOAIGfxBackendGL::LoadIdentity () {

	#if USE_OPENGLES1
		glLoadIdentity ();
	#endif
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::GpuLoadMatrix
void MOAIGfxBackendGL::LoadMatrix ( const float* m ) {

	#if USE_OPENGLES1
		glLoadMatrixf ( m );
	#else
		UNUSED ( m );
	#endif
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::UpdateGpuVertexMtx / UpdateUVMtx / ResetState
void MOAIGfxBackendGL::MatrixMode ( u32 glMatrixMode ) {

	#if USE_OPENGLES1
		::glMatrixMode ( glMatrixMode );
	#else
		UNUSED ( glMatrixMode );
	#endif
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::GpuMultMatrix
void MOAIGfxBackendGL::MultMatrix ( const float* m ) {

	#if USE_OPENGLES1
		glMultMatrixf ( m );
	#else
		UNUSED ( m );
	#endif
}

//----------------------------------------------------------------//
void MOAIGfxBackendGL::PrintProgramLog ( GLuint program ) {

	int logLength;
	glGetProgramiv ( program, GL_INFO_LOG_LENGTH, &logLength );

	if ( logLength > 1 ) {
		char* log = ( char* )malloc ( logLength );
		glGetProgramInfoLog ( program, logLength, &logLength, log );
		MOAILog ( 0, MOAILogMessages::MOAIShader_ShaderInfoLog_S, log );
		free ( log );
	}
}

//----------------------------------------------------------------//
void MOAIGfxBackendGL::PrintShaderLog ( GLuint shader ) {

	int logLength;
	glGetShaderiv ( shader, GL_INFO_LOG_LENGTH, &logLength );

	if ( logLength > 1 ) {
		char* log = ( char* )malloc ( logLength );
		glGetShaderInfoLog ( shader, logLength, &logLength, log );
		MOAILog ( 0, MOAILogMessages::MOAIShader_ShaderInfoLog_S, log );
		free ( log );
	}
}

//----------------------------------------------------------------//
// from MOAIFrameBuffer::GrabImage; the bottom-up flip moves in here so the
// seam contract is top-down rows
void MOAIGfxBackendGL::ReadPixelsRGBA8 ( u32 width, u32 height, void* pixels ) {

	unsigned char* buffer = ( unsigned char* )pixels;

	glReadPixels ( 0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, buffer );

	//image is flipped vertically, flip it back
	int index,indexInvert;
	for ( u32 y = 0; y < ( height / 2 ); ++y ) {
		for ( u32 x = 0; x < width; ++x ) {
			for ( u32 i = 0; i < 4; ++i ) {

				index = i + ( x * 4 ) + ( y * width * 4 );
				indexInvert = i + ( x * 4 ) + (( height - 1 - y ) * width * 4 );

				unsigned char temp = buffer [ indexInvert ];
				buffer [ indexInvert ] = buffer [ index ];
				buffer [ index ] = temp;
			}
		}
	}
}

//----------------------------------------------------------------//
// from MOAIShader::OnCreate (glGetUniformLocation)
u32 MOAIGfxBackendGL::ResolveUniform ( MOAIGfxResID program, cc8* name, u32 uniformType ) {
	UNUSED ( uniformType );

	return ( u32 )glGetUniformLocation (( GLuint )program, name );
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::SetTexture (glActiveTexture before the resource state
// machine runs; includes the GLES1 fixed-function texture enable)
void MOAIGfxBackendGL::SetActiveTexture ( u32 unit ) {

	glActiveTexture ( GL_TEXTURE0 + unit );

	#if USE_OPENGLES1
		if ( !MOAIGfxDevice::Get ().IsProgrammable ()) {
			glEnable ( GL_TEXTURE_2D );
		}
	#endif
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::SetBlendMode. glEquation is recorded by the interface
// but never applied: the legacy GL path never called glBlendEquation
// (MOAIBlendMode::Bind was dead code).
void MOAIGfxBackendGL::SetBlend ( bool enabled, u32 glSrcFactor, u32 glDstFactor, u32 glEquation ) {
	UNUSED ( glEquation );

	if ( enabled ) {
		glEnable ( GL_BLEND );
		glBlendFunc ( glSrcFactor, glDstFactor );
	}
	else {
		glDisable ( GL_BLEND );
	}
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::SetCullFunc
void MOAIGfxBackendGL::SetCull ( u32 glCullModeOrZero ) {

	if ( glCullModeOrZero ) {
		glEnable ( GL_CULL_FACE );
		glCullFace ( glCullModeOrZero );
	}
	else {
		glDisable ( GL_CULL_FACE );
	}
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::SetDepthFunc / SetDepthMask
void MOAIGfxBackendGL::SetDepth ( u32 glDepthFuncOrZero, bool depthMask ) {

	if ( glDepthFuncOrZero ) {
		glEnable ( GL_DEPTH_TEST );
		glDepthFunc ( glDepthFuncOrZero );
	}
	else {
		glDisable ( GL_DEPTH_TEST );
	}
	glDepthMask ( depthMask );
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::SetFrameBuffer
void MOAIGfxBackendGL::SetFrameBuffer ( MOAIGfxResID id ) {

	glBindFramebuffer ( GL_FRAMEBUFFER, ( GLuint )id );
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::SetPenWidth
void MOAIGfxBackendGL::SetLineWidth ( float width ) {

	glLineWidth (( GLfloat )width );
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::SetPointSize / ResetState
void MOAIGfxBackendGL::SetPointSize ( float size ) {

	#if USE_OPENGLES1
		glPointSize (( GLfloat )size );
	#else
		UNUSED ( size );
	#endif
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::SetScissorRect / ResetState
void MOAIGfxBackendGL::SetScissor ( bool enabled, int x, int y, int width, int height ) {

	glScissor ( x, y, width, height );

	if ( enabled ) {
		glEnable ( GL_SCISSOR_TEST );
	}
	else {
		glDisable ( GL_SCISSOR_TEST );
	}
}

//----------------------------------------------------------------//
// from MOAIShaderUniform::Bind
void MOAIGfxBackendGL::SetUniform ( u32 addr, u32 uniformType, const void* data ) {

	switch ( uniformType ) {

		case MOAIShaderUniform::UNIFORM_INT:
			glUniform1i ( addr, *( const int* )data );
			break;

		case MOAIShaderUniform::UNIFORM_FLOAT:
			glUniform1f ( addr, *( const float* )data );
			break;

		case MOAIShaderUniform::UNIFORM_SAMPLER:
			glUniform1i ( addr, *( const int* )data - 1 );
			break;

		case MOAIShaderUniform::UNIFORM_COLOR:
		case MOAIShaderUniform::UNIFORM_PEN_COLOR:
			glUniform4fv ( addr, 1, ( const float* )data );
			break;

		case MOAIShaderUniform::UNIFORM_NORMAL:
			glUniformMatrix3fv ( addr, 1, false, ( const float* )data );
			break;

		case MOAIShaderUniform::UNIFORM_VIEW_PROJ:
		case MOAIShaderUniform::UNIFORM_WORLD:
		case MOAIShaderUniform::UNIFORM_WORLD_VIEW_PROJ:
		case MOAIShaderUniform::UNIFORM_TRANSFORM:
			glUniformMatrix4fv ( addr, 1, false, ( const float* )data );
			break;
	}
}

//----------------------------------------------------------------//
// from MOAIGfxDevice::SetViewRect
void MOAIGfxBackendGL::SetViewport ( int x, int y, int width, int height ) {

	glViewport ( x, y, width, height );
}

//----------------------------------------------------------------//
// from MOAIVertexFormat::Unbind
void MOAIGfxBackendGL::UnbindVertexFormat ( const MOAIVertexFormat& format ) {

	if ( MOAIGfxDevice::Get ().IsProgrammable ()) {
		this->UnbindVertexFormatProgrammable ( format );
	}
	else {
		this->UnbindVertexFormatFixed ( format );
	}
}

//----------------------------------------------------------------//
// from MOAIVertexFormat::UnbindFixed
void MOAIGfxBackendGL::UnbindVertexFormatFixed ( const MOAIVertexFormat& format ) {

	#if USE_OPENGLES1
		for ( u32 i = 0; i < MOAIVertexFormat::TOTAL_ARRAY_TYPES; ++i ) {
			glDisableClientState ( format.mAttributeUseTable [ i ].mUse );
		}
	#else
		UNUSED ( format );
	#endif
}

//----------------------------------------------------------------//
// from MOAIVertexFormat::UnbindProgrammable
void MOAIGfxBackendGL::UnbindVertexFormatProgrammable ( const MOAIVertexFormat& format ) {

	for ( u32 i = 0; i < format.mTotalAttributes; ++i ) {

		MOAIVertexAttribute& attr = format.mAttributes [ i ];
		glDisableVertexAttribArray ( attr.mIndex );
	}
}

//----------------------------------------------------------------//
// from MOAITextureBase::UpdateTextureFromImage
bool MOAIGfxBackendGL::UpdateTextureRegion ( MOAIGfxResID id, const MOAIGfxTextureDesc& desc, int x, int y, u32 width, u32 height, const void* data ) {

	glBindTexture ( GL_TEXTURE_2D, ( GLuint )id );

	glTexSubImage2D (
		GL_TEXTURE_2D,
		0,
		x,
		y,
		width,
		height,
		desc.mGLInternalFormat,
		desc.mGLPixelType,
		data
	);
	return true;
}

//----------------------------------------------------------------//
// from MOAITextureBase::CreateTextureFromImage / CreateTextureFromPVR
// (mip levels beyond 0)
bool MOAIGfxBackendGL::UploadTextureMip ( MOAIGfxResID id, const MOAIGfxTextureDesc& desc, u32 level, u32 width, u32 height, const void* data, size_t dataSize ) {

	glBindTexture ( GL_TEXTURE_2D, ( GLuint )id );

	if ( desc.mIsCompressed ) {
		glCompressedTexImage2D ( GL_TEXTURE_2D, level, desc.mGLInternalFormat, width, height, 0, ( GLsizei )dataSize, data );
	}
	else {
		glTexImage2D (
			GL_TEXTURE_2D,
			level,
			desc.mGLInternalFormat,
			width,
			height,
			0,
			desc.mGLInternalFormat,
			desc.mGLPixelType,
			data
		);
	}
	return true;
}

//----------------------------------------------------------------//
// from MOAIShader::OnBind
void MOAIGfxBackendGL::UseProgram ( MOAIGfxResID program ) {

	glUseProgram (( GLuint )program );
}

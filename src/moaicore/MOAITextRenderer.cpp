//
//  MOAITextRenderer.cpp
//  libmoai
//
//  Created by Isaac Barrett on 11/5/13.
//
//

#include "pch.h"
#include <moaicore/MOAITextRenderer.h>
#include <moaicore/MOAIFreeTypeFont.h>
#include <moaicore/MOAITexture.h>
#include <moaicore/MOAIGlyph.h>
#include <moaicore/MOAITextBox.h>

//================================================================//
// local
//================================================================//
//----------------------------------------------------------------//
/** @name	processOptimalSize
	@text	Does one iteration of the binary search for the optimal size.  Returns the result
			when finished, otherwise returns nil. Each iteration sets adjusts the minimum and 
			maximum size parameters closer to the optimal size.
 
	@in		MOAITextRenderer	self
	@in		string				text
	@out	number				optimalSize		Returns nil before processing is complete.
 
 */

int	MOAITextRenderer::_processOptimalSize( lua_State *L ){
	MOAI_LUA_SETUP( MOAITextRenderer, "US" );
	if (!self->mFont) {
		return 0;
	}
	
	cc8* text = state.GetValue < cc8* > (2, "");
	
	float optimalSize = self->ProcessOptimalSize(text);
	// if the method returns a valid number
	if (optimalSize != (float)PROCESSING_IN_PROGRESS) {
		state.Push(optimalSize);
		return 1;
	}
	
	return 0;
}

//----------------------------------------------------------------//
/** @name	render
	@text	Renders the string with all current settings and returns the texture.
 
	@in		MOAITextRenderer	self
	@in		string				text
	@out	MOAITexture			texture
	@out	table				glyphTable
 
 */
int	MOAITextRenderer::_render ( lua_State *L ){
	MOAI_LUA_SETUP ( MOAITextRenderer, "US" );
	
	if (!self->mFont) {
		return 0;
	}
	
	cc8* text = state.GetValue < cc8* > (2, "");
	MOAITexture *texture = self->mFont->RenderTexture(text, self->mFontSize, self->mWidth,
													  self->mHeight, self->mHorizontalAlignment,
													  self->mVerticalAlignment, self->mWordBreak,
													  false, self->mReturnGlyphBounds, state);
	
	state.Push( texture );
	if (self->mReturnGlyphBounds) {
		state.MoveToTop(-2);
		return 2;
	}
	
	return 1;
}

//----------------------------------------------------------------//
/** @name	renderSingleLine
	@text	Renders the string with the current font and font size on a single line and returns the texture.
 
	@in		MOAITextRenderer	self
	@in		string				text
	@out	MOAITexture			texture
	@out	number				width
	@out	number				height
	@out	table				glyphTable
 */
int MOAITextRenderer::_renderSingleLine ( lua_State *L ){
	MOAI_LUA_SETUP ( MOAITextRenderer, "US" );
	
	if (!self->mFont) {
		return 0;
	}
	
	cc8* text = state.GetValue < cc8* > (2, "");
	
	USRect rect;
	MOAITexture *texture = self->mFont->RenderTextureSingleLine(text, self->mFontSize, &rect, self->mReturnGlyphBounds, state);
	state.Push(texture);
	state.Push(rect.Width());
	state.Push(rect.Height());
	if (self->mReturnGlyphBounds) {
		// return the glyph bound table after the height information
		state.MoveToTop(-4);
		return 4;
	}
	return 3;
}

//----------------------------------------------------------------//
/** @name	resetProcess
	@text   Reset the state of optimal size processing to make it work like it has been run the first time.
 
	@in		MOAITextRenderer	self
	@out	nil
 */
 
int MOAITextRenderer::_resetProcess( lua_State *L ){
	MOAI_LUA_SETUP ( MOAITextRenderer, "U" );
	self->mFirstProcessRun = true;
	return 0;
}

//----------------------------------------------------------------//
/** @name	setAlignment
	@text	Set the horizontal and vertical alignment of the text to render.
 
	@in		MOAITextRenderer	self
	@opt	number	horizontalAlignment		default to MOAITextBox.LEFT_JUSTIFY
	@opt	number	verticalAlignment		default to MOAITextBox.LEFT_JUSTIFY
	@out	nil
 
 */
int MOAITextRenderer::_setAlignment ( lua_State *L ){
	MOAI_LUA_SETUP ( MOAITextRenderer, "U" );
	
	int horizontalAlignment = state.GetValue < int > ( 2, MOAITextBox::LEFT_JUSTIFY );
	int verticalAlignment = state.GetValue <int > ( 3, MOAITextBox::LEFT_JUSTIFY );
	
	self->mHorizontalAlignment = horizontalAlignment;
	self->mVerticalAlignment = verticalAlignment;
	
	return 0;
}

//----------------------------------------------------------------//
/** @name	setDimensions
	@text	Set the dimensions of the text box to render.
 
 	@in		MOAITextRenderer	self
	@in		number	width
	@in		number	height
	@out	nil
	
 */
int MOAITextRenderer::_setDimensions( lua_State *L ){
	
	MOAI_LUA_SETUP ( MOAITextRenderer, "UNN" );
	
	float width = state.GetValue < float > ( 2, 0.0f );
	float height = state.GetValue < float > ( 3, 0.0f );
	
	self->mWidth = width;
	self->mHeight = height;
	
	return 0;
}

//----------------------------------------------------------------//
/** @name	setFont
	@text	Set the font to use when rendering.
 
	@in		MOAITextRenderer self
	@in		MOAIFreeTypeFont font
	@out	nil
 
 */
int MOAITextRenderer::_setFont ( lua_State *L ){
	MOAI_LUA_SETUP ( MOAITextRenderer, "U" );
	self->mFont.Set( *self, state.GetLuaObject < MOAIFreeTypeFont >( 2, true ));
	return 0;
}

//----------------------------------------------------------------//
/** @name	setFontSize
	@text	Set the size of the font to use when rendering.
 
	@in		MOAITextRenderer self
	@in		number fontSize
	@out	nil
 */
int MOAITextRenderer::_setFontSize ( lua_State *L ){
	MOAI_LUA_SETUP ( MOAITextRenderer, "UN" );
	self->mFontSize = state.GetValue < float > ( 2, 0.0f );
	return 0;
}

//----------------------------------------------------------------//
/** @name	setForceSingleLine
	@text   Set the boolean parameter to force the optimal size algorithm to put the string
			on a single line when processing.
 
	@in		MOAITextRenderer	self
	@opt	bool				forceSingleLine		Defualt is true.
	@out	nil
 
 */
int MOAITextRenderer::_setForceSingleLine( lua_State *L ){
	MOAI_LUA_SETUP ( MOAITextRenderer, "U" );
	self->mForceSingleLine = state.GetValue < bool > (2, true);
	return 0;
}

//----------------------------------------------------------------//
/** @name	setGranularity
	@text	Set the threshold for the difference between maximum and minumum font size
			parameters for determining when the optimal size processing is complete.
	
	@in		MOAITextRenderer	self
	@in		number				granularity
	@out	nil
 
 */
int MOAITextRenderer::_setGranularity(lua_State *L){
	MOAI_LUA_SETUP ( MOAITextRenderer, "UN" );
	self->mGranularity = state.GetValue < float > (2, 1.0f);
	return 0;
}

//----------------------------------------------------------------//
/** @name	setMaxFontSize
	@text	Set the maximum font size parameter for optimal size processing.
 
	@in		MOAITextRenderer	self
	@in		number				maxFontSize
	@out	nil
 
 */
int MOAITextRenderer::_setMaxFontSize(lua_State *L){
	MOAI_LUA_SETUP ( MOAITextRenderer, "UN" );
	self->mMaxFontSize = state.GetValue < float > (2, 0.0f);
	return 0;
}

//----------------------------------------------------------------//
/** @name	setMinFontSize
	@text	Set the minimum font size parameter for optimal size processing.
 
	@in		MOAITextRenderer	self
	@in		number				minFontSize
	@out	nil
 
 */
int MOAITextRenderer::_setMinFontSize(lua_State *L){
	MOAI_LUA_SETUP ( MOAITextRenderer, "UN" );
	self->mMinFontSize = state.GetValue < float > (2, 1.0f);
	return 0;
}

//----------------------------------------------------------------//
/**	@name	setHeight
	@text	Set the height of the text box to render.
 
	@in		MOAITextRenderer self
	@in		number height
	@out	nil
 
 */

int MOAITextRenderer::_setHeight ( lua_State *L ){
	MOAI_LUA_SETUP ( MOAITextRenderer, "UN" );
	self->mHeight = state.GetValue < float > ( 2, 0.0f );
	return 0;
}

//----------------------------------------------------------------//
/**	@name	setReturnGlyphBounds
	@text	Set the flag to return an additional table containing 
			information about each glyph.
 
	@in		MOAITextRenderer self
	@opt	bool returnGlyphBounds	default true
	@out	nil
 
 */
int MOAITextRenderer::_setReturnGlyphBounds ( lua_State *L ){
	MOAI_LUA_SETUP ( MOAITextRenderer, "U" );
	self->mReturnGlyphBounds = state.GetValue < bool > ( 2, true );
	return 0;
}

//----------------------------------------------------------------//
/**	@name	setRoundToInteger
	@text	Set the boolean parameter that controls whether the result of optimal size processing is rounded to the nearest integer less than or equal to the return value.
 
	@in		MOAITextRenderer self
	@opt	bool returnGlyphBounds	default true
	@out	nil
 
 */
int MOAITextRenderer::_setRoundToInteger(lua_State *L){
	MOAI_LUA_SETUP ( MOAITextRenderer, "U" );
	self->mRoundToInteger = state.GetValue < bool > ( 2, true );
	return 0;
}

//----------------------------------------------------------------//
/**	@name	setWidth
	@text	Set the width of the text box to render.
 
	@in		MOAITextRenderer self
	@in		number width
	@out	nil
 
 */
int MOAITextRenderer::_setWidth ( lua_State *L ){
	MOAI_LUA_SETUP ( MOAITextRenderer, "UN" );
	self->mWidth = state.GetValue < float > ( 2, 0.0f );
	return 0;
}

//----------------------------------------------------------------//
/**	@name	setWordBreak
	@text	Set the word break mode of the text to render.
 
	@in		MOAITextRenderer self
	@in		number height
	@out	nil
 
 */
int MOAITextRenderer::_setWordBreak ( lua_State *L ){
	MOAI_LUA_SETUP ( MOAITextRenderer, "U" );
	self->mWordBreak = state.GetValue < int > ( 2, MOAITextBox::WORD_BREAK_NONE );
	return 0;
}

//----------------------------------------------------------------//
float MOAITextRenderer::ProcessOptimalSize(cc8 *text){
	
	
	if (! (this->mFont->IsFreeTypeInitialized()) ) {
		FT_Library library;
		FT_Init_FreeType( &library );
		this->mFont->LoadFreeTypeFace(&library);
	}
	
	
	
	
	float lowerBoundSize = this->mMinFontSize;
	float upperBoundSize = this->mMaxFontSize;
	if (this->mFirstProcessRun) {
		upperBoundSize += 1.0f;
		this->mFirstProcessRun = false;
	}
	
	
	this->mFont->SetCharacterSize(this->mMaxFontSize);
	
	float estimatedMaxSize = this->mFont->EstimatedMaxFontSize(this->mHeight, this->mMaxFontSize);
	
	if (estimatedMaxSize < this->mMaxFontSize) {
		//this->mMaxFontSize = ceilf(estimatedMaxSize);
		upperBoundSize = ceilf(estimatedMaxSize) + 1.0f;
	}
	
	FT_Int imageWidth = (FT_Int)this->mWidth;
	
	int numLines = 0;
	
	float testSize = (upperBoundSize + lowerBoundSize) / 2.0f;
	
	// set character size to test size
	this->mFont->SetCharacterSize(testSize);
	
	// compute maximum number of lines allowed at font size.
	// forceSingleLine sets this value to one if true.
	FT_Int lineHeight = this->mFont->GetLineHeight();
	int maxLines = (this->mHeight / lineHeight);
	if (this->mForceSingleLine && maxLines > 1) {
		maxLines = 1;
	}
	
	numLines = this->mFont->NumberOfLinesToDisplayText(text, imageWidth, this->mWordBreak, false);
	
	if (numLines > maxLines || numLines < 0) {
		upperBoundSize = this->mMaxFontSize = testSize;
	}
	else{
		 lowerBoundSize = this->mMinFontSize = testSize;
	}
	
	if (this->mMaxFontSize - this->mMinFontSize >= this->mGranularity) {
		return (float)PROCESSING_IN_PROGRESS;
	}
	
	if (this->mRoundToInteger) {
		testSize = floorf(lowerBoundSize);
	}
	else{
		testSize = lowerBoundSize;
	}
	
	
	return testSize;
}

//----------------------------------------------------------------//

MOAITextRenderer::MOAITextRenderer ( ):
	mFontSize(0.0f),
	mWidth(0.0f),
	mHeight(0.0f),
	mHorizontalAlignment(MOAITextBox::LEFT_JUSTIFY),
	mVerticalAlignment(MOAITextBox::LEFT_JUSTIFY),
	mWordBreak(MOAITextBox::WORD_BREAK_NONE),
	mReturnGlyphBounds(false),
	mMaxFontSize(0.0f),
	mMinFontSize(1.0f),
	mForceSingleLine(false),
	mGranularity(1.0f),
	mRoundToInteger(true),
	mFirstProcessRun(true)
{
	RTTI_BEGIN
		RTTI_EXTEND ( MOAILuaObject )
	RTTI_END
	
}

//----------------------------------------------------------------//
MOAITextRenderer::~MOAITextRenderer () {
	this->mFont.Set( *this, 0 );
}

//----------------------------------------------------------------//
void MOAITextRenderer::RegisterLuaClass ( MOAILuaState &state ) {
	UNUSED( state );
}

//----------------------------------------------------------------//
void MOAITextRenderer::RegisterLuaFuncs ( MOAILuaState &state ) {
	luaL_Reg regTable [] = {
		{ "processOptimalSize",		_processOptimalSize },
		{ "render",					_render },
		{ "renderSingleLine",		_renderSingleLine },
		{ "resetProcess",			_resetProcess },
		{ "setAlignment",			_setAlignment },
		{ "setDimensions",			_setDimensions },
		{ "setFont",				_setFont },
		{ "setFontSize",			_setFontSize },
		{ "setForceSingleLine",		_setForceSingleLine },
		{ "setGranularity",			_setGranularity },
		{ "setHeight",				_setHeight },
		{ "setMaxFontSize",			_setMaxFontSize },
		{ "setMinFontSize",			_setMinFontSize },
		{ "setReturnGlyphBounds",	_setReturnGlyphBounds },
		{ "setRoundToInteger",		_setRoundToInteger },
		{ "setWidth",				_setWidth },
		{ "setWordBreak",			_setWordBreak },
		{ NULL, NULL }
	};
	
	luaL_register ( state, 0, regTable );
}


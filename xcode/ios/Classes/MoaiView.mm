//----------------------------------------------------------------//
// Copyright (c) 2010-2011 Zipline Games, Inc. 
// All Rights Reserved. 
// http://getmoai.com
//----------------------------------------------------------------//

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>



#import <aku/AKU-iphone.h>
#import <aku/AKU-luaext.h>
#import <aku/AKU-audiosampler.h>
#import <lua-headers/moai_lua.h>

extern "C" {
	#include <lua.h>
	#include <lauxlib.h>
	#include <lualib.h>
}

#ifdef USE_UNTZ
#import <aku/AKU-untz.h>
#endif

#ifdef USE_FMOD_EX
#include <aku/AKU-fmod-ex.h>
#endif

#ifdef USE_MOAI_TEST
#include <aku/AKU-test.h>
#endif

#import "LocationObserver.h"
#import "MoaiView.h"

#import "MoaiVC.h"


//================================================================//
// MoaiView ()
//================================================================//
@interface MoaiView ()

	//----------------------------------------------------------------//
	-( void )	drawView;
	-( void )	handleTouches		:( NSSet* )touches :( BOOL )down;
- (void)handlePresses:(NSSet *)presses down:(BOOL)down;
	-( void )	onUpdateAnim;
//	-( void )	onUpdateHeading		:( LocationObserver* )observer;
//	-( void )	onUpdateLocation	:( LocationObserver* )observer;
	-( void )	startAnimation;
	-( void )	stopAnimation;
    -( void )   dummyFunc;

@end

//================================================================//
// MoaiView
//================================================================//
@implementation MoaiView
    SYNTHESIZE	( GLint, width, Width );
    SYNTHESIZE	( GLint, height, Height );

	//----------------------------------------------------------------//
//	-( void ) accelerometer:( UIAccelerometer* )acel didAccelerate:( UIAcceleration* )acceleration {
//		( void )acel;
//		
//		AKUEnqueueLevelEvent (
//			MoaiInputDeviceID::DEVICE,
//			MoaiInputDeviceSensorID::LEVEL,
//			( float )acceleration.x,
//			( float )acceleration.y,
//			( float )acceleration.z
//		);
//	}

    //----------------------------------------------------------------//
    -( AKUContextID ) akuInitialized {

        return mAku;
    }

	//----------------------------------------------------------------//
	-( void ) dealloc {
	
		AKUDeleteContext ( mContext );
		
		[ super dealloc ];
	}

	//----------------------------------------------------------------//
	-( void ) drawView {
		
		[ self beginDrawing ];
		
		AKUSetContext ( mAku );
		AKURender ();

		[ self endDrawing ];
	}
	
    //----------------------------------------------------------------//
    -( void ) dummyFunc {
        //dummy to fix weird input bug
    }

	//----------------------------------------------------------------//
	-( void ) handleTouches :( NSSet* )touches :( BOOL )down {
        
		for ( UITouch* touch in touches ) {
            
			CGPoint p = [ touch locationInView:nil ];
            
            CGSize frameSize = self.frame.size;
            
            float x = (p.x / frameSize.width) - 0.5f;
            float y = -((p.y / frameSize.height) - 0.5f);
			
            AKUEnqueueTouchEvent(
                                 MoaiInputDeviceId::MoaiInputDeviceIdTvRemote,
                                 MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdTouch,
                                 (int)(unsigned long)touch, // use the address of the touch as a unique id
                                 down,
                                 x,
                                 y
                                 );
		}
	}


	//----------------------------------------------------------------//
	-( id )init {
		
        mAku = 0;
		self = [ super init ];
		if ( self ) {
		}
		return self;
	}

	//----------------------------------------------------------------//
	-( id ) initWithCoder:( NSCoder* )encoder {

        mAku = 0;
		self = [ super initWithCoder:encoder ];
		if ( self ) {
		}
		return self;
	}
	
	//----------------------------------------------------------------//
	-( id ) initWithFrame :( CGRect )frame {

        mAku = 0;
		self = [ super initWithFrame:frame ];
		if ( self ) {
		}
		return self;
	}
	
	//----------------------------------------------------------------//
	-( void ) moaiInit :( UIApplication* )application {
	
		mAku = AKUCreateContext ();
		AKUSetUserdata ( self );
		
		AKUExtLoadLuasql ();
		AKUExtLoadLuasocket ();
		
		#ifdef USE_UNTZ
			AKUUntzInit ();
		#endif
        
		#ifdef USE_FMOD_EX
			AKUFmodExInit ();
		#endif
        
        #ifdef USE_MOAI_TEST
            AKUTestInit ();
        #endif
        
		AKUAudioSamplerInit ();
        
        ///
//        self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
//        self.tapGestureRecognizer.allowedPressTypes = @[@(UIPressTypeLeftArrow), @(UIPressTypeRightArrow)];
//        self.tapGestureRecognizer.cancelsTouchesInView = NO;
//        [self addGestureRecognizer:self.tapGestureRecognizer];
        ///
        
		AKUSetInputConfigurationName ( "iPhone" );

//		AKUReserveInputDevices			( MoaiInputDeviceID::TOTAL );
//		AKUSetInputDevice				( MoaiInputDeviceID::DEVICE, "device" );
//		
//		AKUReserveInputDeviceSensors	( MoaiInputDeviceID::DEVICE, MoaiInputDeviceSensorID::TOTAL );
//		AKUSetInputDeviceCompass		( MoaiInputDeviceID::DEVICE, MoaiInputDeviceSensorID::COMPASS,		"compass" );
//		AKUSetInputDeviceLevel			( MoaiInputDeviceID::DEVICE, MoaiInputDeviceSensorID::LEVEL,		"level" );
//		AKUSetInputDeviceLocation		( MoaiInputDeviceID::DEVICE, MoaiInputDeviceSensorID::LOCATION,		"location" );
//		AKUSetInputDeviceTouch			( MoaiInputDeviceID::DEVICE, MoaiInputDeviceSensorID::TOUCH,		"touch" );
        
        AKUReserveInputDevices(MoaiInputDeviceId::MoaiInputDeviceIdTotal);
        AKUSetInputDevice(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, "tv_remote");
        
        AKUReserveInputDeviceSensors(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdTotal);
        AKUSetInputDeviceTouch(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdTouch, "touch");
        
        AKUSetInputDeviceButton(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdSelectButton, "select_button");
        AKUSetInputDeviceButton(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdMenuButton, "menu_button");
        AKUSetInputDeviceButton(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdPlayPauseButton, "play_pause_button");
        
        AKUSetInputDeviceButton(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdSwipeLeft, "swipe_left");
        AKUSetInputDeviceButton(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdSwipeRight, "swipe_right");
        AKUSetInputDeviceButton(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdSwipeUp, "swipe_up");
        AKUSetInputDeviceButton(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdSwipeDown, "swipe_down");
        
		AKUSetInputDeviceButton(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdLeftArrow, "left_arrow");
        AKUSetInputDeviceButton(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdRightArrow, "right_arrow");
        AKUSetInputDeviceButton(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdUpArrow, "up_arrow");
        AKUSetInputDeviceButton(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdDownArrow, "down_arrow");
        
        
		CGRect screenRect = [[ UIScreen mainScreen ] bounds ];
		CGFloat scale = [[ UIScreen mainScreen ] scale ];
		CGFloat screenWidth = screenRect.size.width * scale;
		CGFloat screenHeight = screenRect.size.height * scale;
		
		AKUSetScreenSize ( screenWidth, screenHeight );
		AKUSetScreenDpi([ self guessScreenDpi ]);
		AKUSetViewSize ( mWidth, mHeight );
		
        AKUSetFrameBuffer ( mFramebuffer );
		AKUDetectGfxContext ();
		
		mAnimInterval = 1; // 1 for 60fps, 2 for 30fps
		
		mLocationObserver = [[[ LocationObserver alloc ] init ] autorelease ];
		
		[ mLocationObserver setHeadingDelegate:self :@selector ( onUpdateHeading: )];
		[ mLocationObserver setLocationDelegate:self :@selector ( onUpdateLocation: )];
		
//		UIAccelerometer* accel = [ UIAccelerometer sharedAccelerometer ];
//		accel.delegate = self;
//		accel.updateInterval = mAnimInterval / 60;
		
		// init aku
		AKUIphoneInit ( application );
        
//        [self addBuzzerManager];
        
        AKURunString( moai_lua_code );
	}
	
	//----------------------------------------------------------------//
	-( int ) guessScreenDpi {
		float dpi;
		float scale = 1;
		if ([[ UIScreen mainScreen ] respondsToSelector:@selector(scale) ]) {
			scale = [[ UIScreen mainScreen ] scale];
		}
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
			//Not working for iPad Mini, but appropriate solution doesn't exist yet
			dpi = 132 * scale;
		}else{
			dpi = 163 * scale;
		}
		return dpi;
	}

    //----------------------------------------------------------------//
	-( void ) onUpdateAnim {
		
		[ self openContext ];
		AKUSetContext ( mAku );
		AKUUpdate ();
		#ifdef USE_FMOD_EX
			AKUFmodExUpdate ();
		#endif
		[ self drawView ];
        
        //sometimes the input handler will get 'locked out' by the render, this will allow it to run
        [ self performSelector: @selector(dummyFunc) withObject:self afterDelay: 0 ];
	}
	
	//----------------------------------------------------------------//
//	-( void ) onUpdateHeading :( LocationObserver* )observer {
//	
//		AKUEnqueueCompassEvent (
//			MoaiInputDeviceID::DEVICE,
//			MoaiInputDeviceSensorID::COMPASS,
//			( float )[ observer heading ]
//		);
//	}

	//----------------------------------------------------------------//
//	-( void ) onUpdateLocation :( LocationObserver* )observer {
//	
//		AKUEnqueueLocationEvent (
//			MoaiInputDeviceID::DEVICE,
//			MoaiInputDeviceSensorID::LOCATION,
//			[ observer longitude ],
//			[ observer latitude ],
//			[ observer altitude ],
//			( float )[ observer hAccuracy ],
//			( float )[ observer vAccuracy ],
//			( float )[ observer speed ]
//		);
//	}

	//----------------------------------------------------------------//
	-( void ) pause :( BOOL )paused {
	
		if ( paused ) {
			AKUPause ( YES );
			[ self stopAnimation ];
		}
		else {
			[ self startAnimation ];
			AKUPause ( NO );
		}
	}
	
	//----------------------------------------------------------------//
	-( void ) run :( NSString* )filename {
	
		AKUSetContext ( mAku );
		AKURunScript ([ filename UTF8String ]);
	}
	
	//----------------------------------------------------------------//
	-( void ) startAnimation {
		
		if ( !mDisplayLink ) {
			CADisplayLink* aDisplayLink = [[ UIScreen mainScreen ] displayLinkWithTarget:self selector:@selector( onUpdateAnim )];
			[ aDisplayLink setFrameInterval:mAnimInterval ];
			[ aDisplayLink addToRunLoop:[ NSRunLoop currentRunLoop ] forMode:NSDefaultRunLoopMode ];
			mDisplayLink = aDisplayLink;
		}
	}

	//----------------------------------------------------------------//
	-( void ) stopAnimation {
		
        [ mDisplayLink invalidate ];
        mDisplayLink = nil;
	}
	
	//----------------------------------------------------------------//
	-( void )touchesBegan:( NSSet* )touches withEvent:( UIEvent* )event {
		( void )event;
        
		[ self handleTouches :touches :YES ];
	}
	
	//----------------------------------------------------------------//
	-( void )touchesCancelled:( NSSet* )touches withEvent:( UIEvent* )event {
		( void )touches;
		( void )event;
		
        AKUEnqueueTouchEventCancel(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdTouch);
//		AKUEnqueueTouchEventCancel ( MoaiInputDeviceID::DEVICE, MoaiInputDeviceSensorID::TOUCH );
	}
	
	//----------------------------------------------------------------//
	-( void )touchesEnded:( NSSet* )touches withEvent:( UIEvent* )event {
		( void )event;
		
		[ self handleTouches :touches :NO ];
	}

	//----------------------------------------------------------------//
	-( void )touchesMoved:( NSSet* )touches withEvent:( UIEvent* )event {
		( void )event;
		
		[ self handleTouches :touches :YES ];
	}

+ (MoaiInputDeviceSensorId)sensorIdForPressType:(UIPressType)pressType {
    if (pressType == UIPressTypeSelect) {
        return MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdSelectButton;
    } else if (pressType == UIPressTypeMenu) {
        return MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdMenuButton;
    } else if (pressType == UIPressTypePlayPause) {
        return MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdPlayPauseButton;
    } else if (pressType == UIPressTypeLeftArrow) {
        return MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdLeftArrow;
    } else if (pressType == UIPressTypeRightArrow) {
        return MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdRightArrow;
    } else if (pressType == UIPressTypeUpArrow) {
        return MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdUpArrow;
    } else if (pressType == UIPressTypeDownArrow) {
        return MoaiInputDeviceSensorId::MoaiInputDeviceSensorIdDownArrow;
    } else {
        NSAssert(NO, @"Unhandled press type");
    }
}

- (void)handlePresses:(NSSet *)presses down:(BOOL)down {
    for (UIPress *press in presses) {
        MoaiInputDeviceSensorId sensorId = [MoaiView sensorIdForPressType:press.type];
        AKUEnqueueButtonEvent(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, sensorId, down);
    }
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self handlePresses:presses down:YES];
}

- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self handlePresses:presses down:NO]; // Should probably handle this more like when touches are canceled.
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self handlePresses:presses down:NO];
}

	
@end
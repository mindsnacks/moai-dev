//----------------------------------------------------------------//
// Copyright (c) 2010-2011 Zipline Games, Inc. 
// All Rights Reserved. 
// http://getmoai.com
//----------------------------------------------------------------//

#import <aku/AKU.h>
#import "MoaiVC.h"
#import "MoaiView.h"

//================================================================//
// MoaiVC ()
//================================================================//
@interface MoaiVC ()
{
    UISwipeGestureRecognizer *_leftSwipeGestureRecognizer;
    UISwipeGestureRecognizer *_rightSwipeGestureRecognizer;
    UISwipeGestureRecognizer *_upSwipeGestureRecognizer;
    UISwipeGestureRecognizer *_downSwipeGestureRecognizer;
}

	//----------------------------------------------------------------//
	-( void ) updateOrientation :( UIInterfaceOrientation )orientation;

@end

//================================================================//
// MoaiVC
//================================================================//
@implementation MoaiVC

	//----------------------------------------------------------------//
	-( void ) willRotateToInterfaceOrientation :( UIInterfaceOrientation )toInterfaceOrientation duration:( NSTimeInterval )duration {
		
		[ self updateOrientation:toInterfaceOrientation ];
	}

	//----------------------------------------------------------------//
	- ( id ) init {
	
		self = [ super init ];
		if ( self ) {
            
		}
		return self;
	}

	//----------------------------------------------------------------//
	- ( BOOL ) shouldAutorotateToInterfaceOrientation :( UIInterfaceOrientation )interfaceOrientation {
		
        /*
            The following block of code is used to lock the sample into a Portrait orientation, skipping the landscape views as you rotate your device.
            To complete this feature, you must specify the correct Portraits as the only supported orientations in your plist under the setting,
                "Supported Device Orientations"
         */
        
        if (( interfaceOrientation == UIInterfaceOrientationPortrait ) || ( interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown )) {
            return true;
        }
        
        return false;
        
        /*
            The following is used to support all view orientations.
         */
        
        //return true;
	}
	
	//----------------------------------------------------------------//
	-( void ) updateOrientation :( UIInterfaceOrientation )orientation {
		
//		MoaiView* view = ( MoaiView* )self.view;        
//		
//		if (( orientation == UIInterfaceOrientationPortrait ) || ( orientation == UIInterfaceOrientationPortraitUpsideDown )) {
//            
//            if ([ view akuInitialized ] != 0 ) {
//                AKUSetOrientation ( AKU_ORIENTATION_PORTRAIT );
//                AKUSetViewSize (( int )view.width, ( int )view.height );
//            }
//		}
//		else if (( orientation == UIInterfaceOrientationLandscapeLeft ) || ( orientation == UIInterfaceOrientationLandscapeRight )) {
//            if ([ view akuInitialized ] != 0 ) {
//                AKUSetOrientation ( AKU_ORIENTATION_LANDSCAPE );
//                AKUSetViewSize (( int )view.height, ( int )view.width);
//            }
//		}
	}

- (void)addSwipeGestureRecognizer {
    _leftSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleLeftSwipeFrom:)];
    [_leftSwipeGestureRecognizer setDirection:(UISwipeGestureRecognizerDirectionLeft)];
    [self.view addGestureRecognizer:_leftSwipeGestureRecognizer];
    
    _rightSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleRightSwipeFrom:)];
    [_rightSwipeGestureRecognizer setDirection:(UISwipeGestureRecognizerDirectionRight)];
    [self.view addGestureRecognizer:_rightSwipeGestureRecognizer];
    
    _upSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleUpSwipeFrom:)];
    [_upSwipeGestureRecognizer setDirection:(UISwipeGestureRecognizerDirectionUp)];
    [self.view addGestureRecognizer:_upSwipeGestureRecognizer];
    
    _downSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleDownSwipeFrom:)];
    [_downSwipeGestureRecognizer setDirection:(UISwipeGestureRecognizerDirectionDown)];
    [self.view addGestureRecognizer:_downSwipeGestureRecognizer];
}

- (void)sendSwipeSignalWithSensorId:(MoaiInputDeviceSensorId)sensorId {
    bool buttonPressed = true;
    AKUEnqueueButtonEvent(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, sensorId, buttonPressed);
    buttonPressed = false;
    AKUEnqueueButtonEvent(MoaiInputDeviceId::MoaiInputDeviceIdTvRemote, sensorId, buttonPressed);
}

- (void)handleLeftSwipeFrom:(UISwipeGestureRecognizer *)recognizer {
    [self sendSwipeSignalWithSensorId:MoaiInputDeviceSensorIdSwipeLeft];
}

- (void)handleRightSwipeFrom:(UISwipeGestureRecognizer *)recognizer {
    [self sendSwipeSignalWithSensorId:MoaiInputDeviceSensorIdSwipeRight];
}

- (void)handleUpSwipeFrom:(UISwipeGestureRecognizer *)recognizer {
    [self sendSwipeSignalWithSensorId:MoaiInputDeviceSensorIdSwipeUp];
}

- (void)handleDownSwipeFrom:(UISwipeGestureRecognizer *)recognizer {
    [self sendSwipeSignalWithSensorId:MoaiInputDeviceSensorIdSwipeDown];
}

	
@end
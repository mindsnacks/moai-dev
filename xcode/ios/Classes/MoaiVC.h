//----------------------------------------------------------------//
// Copyright (c) 2010-2011 Zipline Games, Inc. 
// All Rights Reserved. 
// http://getmoai.com
//----------------------------------------------------------------//

#import <UIKit/UIKit.h>

typedef enum MoaiInputDeviceSensorId {
    MoaiInputDeviceSensorIdTouch,
    MoaiInputDeviceSensorIdSelectButton,
    MoaiInputDeviceSensorIdMenuButton,
    MoaiInputDeviceSensorIdPlayPauseButton,
    MoaiInputDeviceSensorIdSwipeLeft,
    MoaiInputDeviceSensorIdSwipeRight,
    MoaiInputDeviceSensorIdSwipeUp,
    MoaiInputDeviceSensorIdSwipeDown,
    MoaiInputDeviceSensorIdLeftArrow,
    MoaiInputDeviceSensorIdRightArrow,
    MoaiInputDeviceSensorIdUpArrow,
    MoaiInputDeviceSensorIdDownArrow,
    MoaiInputDeviceSensorIdTotal
} MoaiInputDeviceSensorIds;

typedef enum MoaiInputDeviceId {
    MoaiInputDeviceIdTvRemote,
    MoaiInputDeviceIdTotal
} MoaiInputDeviceIds;

//================================================================//
// MoaiVC
//================================================================//
@interface MoaiVC : UIViewController {
}

- (void)addSwipeGestureRecognizer;

@end

//----------------------------------------------------------------//
// Copyright (c) 2010-2011 Zipline Games, Inc. 
// All Rights Reserved. 
// http://getmoai.com
//----------------------------------------------------------------//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

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
@interface MoaiVC : UIViewController <CBCentralManagerDelegate, CBPeripheralDelegate> {
}

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;
@property (strong, nonatomic) NSMutableData *data;

- (void)addSwipeGestureRecognizer;
- (void)addBluetoothStuff;

@end

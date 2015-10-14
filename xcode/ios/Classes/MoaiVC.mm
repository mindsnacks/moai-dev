//----------------------------------------------------------------//
// Copyright (c) 2010-2011 Zipline Games, Inc. 
// All Rights Reserved. 
// http://getmoai.com
//----------------------------------------------------------------//

#import <aku/AKU.h>
#import "MoaiVC.h"
#import "MoaiView.h"

#define TRANSFER_SERVICE_UUID @"F457370D-61BC-47A5-8272-99A5584FC554"
#define TRANSFER_CHARACTERISTIC_UUID @"38224EC1-942E-419D-8068-985ED77392D2"

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

#pragma mark - Swipe Gestures

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

#pragma mark - Bluetooth

- (void)addBluetoothStuff {
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    _data = [[NSMutableData alloc] init];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state != CBCentralManagerStatePoweredOn) {
        return;
    }
    
    //Scan for devices
    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
    NSLog(@"Scanning started...");
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    if (_discoveredPeripheral != peripheral) {
        //Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it.
        _discoveredPeripheral = peripheral;
        
        //Add connect
        NSLog(@"Connecting to peripheral %@", peripheral);
        [_centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Failed to conenct.");
    [self cleanupBluetooth];
}

- (void)cleanupBluetooth {
    // See if we are subscribed to a characteristic on the peripheral
    if (_discoveredPeripheral.services != nil) {
        for (CBService *service in _discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            [_discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            return;
                        }
                    }
                }
            }
        }
    }
    
    [_centralManager cancelPeripheralConnection:_discoveredPeripheral];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected");
    
    [_centralManager stopScan];
    NSLog(@"Scanning stopped");
    
    [_data setLength:0];
    
    peripheral.delegate = self;
    
    [peripheral discoverServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        [self cleanupBluetooth];
        return;
    }
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]] forService:service];
    }
    
    // Discover other characteristics
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self cleanupBluetooth];
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error");
        return;
    }
    
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    
    // Have we got everything we need?
    if ([stringFromData isEqualToString:@"EOM"]) {
        // HERE IS WHERE WE DO SOMETHING WITH THE TEXT
        NSLog(@"%@", [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding]);
        
        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
        
        [_centralManager cancelPeripheralConnection:peripheral];
    }
    
    [_data appendData:characteristic.value];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
        return;
    }
    
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);
    } else {
        //Notification has stopped
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(nonnull CBPeripheral *)peripheral error:(nullable NSError *)error {
    _discoveredPeripheral = nil;
    
    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
}

// We also nee to tell the centralManager to stop scanning when the view disappears...
// But Moai's view controller seems to be set up in an outdated/nonstandard way, so I'm not
// bothering with it for now.  Hummm.
//- (void)viewDidDisappear:(BOOL)animated {
//    [_centralManager stopScan];
//    
//    [super viewDidDisappear:animated];
//}


	
@end
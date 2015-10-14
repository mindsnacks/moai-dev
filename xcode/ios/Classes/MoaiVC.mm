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

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;
@property (strong, nonatomic) NSMutableData *data;

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

#pragma mark - Newer Bluetooth

- (void)addBluetoothStuff {
    // Start up the CBCentralManager
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    // And somewhere to store the incoming data
    _data = [[NSMutableData alloc] init];
}

//We *should* stop scanning when the view disappears... but Moai.
//- (void)viewWillDisappear:(BOOL)animated {
//    // Don't keep it going while we're not showing.
//    [self.centralManager stopScan];
//    NSLog(@"Scanning stopped");
//    
//    [super viewWillDisappear:animated];
//}

/** centralManagerDidUpdateState is a required protocol method.
 *  Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc.
 *  In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates
 *  the Central is ready to be used.
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state != CBCentralManagerStatePoweredOn) {
        // In a real app, you'd deal with all the states correctly
        return;
    }
    
    // The state must be CBCentralManagerStatePoweredOn...
    
    // ... so start scanning
    [self scan];
    
}

/** Scan for peripherals - specifically for our service's 128bit CBUUID
 */
- (void)scan
{
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]
                                                options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    
    NSLog(@"Scanning started");
}

/** This callback comes whenever a peripheral that is advertising the TRANSFER_SERVICE_UUID is discovered.
 *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
 *  we start the connection process
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    
    // Reject any where the value is above reasonable range
//    if (RSSI.integerValue > -15) {
//        return;
//    }
    
    // Reject if the signal strength is too low to be close enough (Close is around -22dB)
    //    if (RSSI.integerValue < -35) {
    //        return;
    //    }
    
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    
    // Ok, it's in range - have we already seen it?
    if (self.discoveredPeripheral != peripheral) {
        
        // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
        self.discoveredPeripheral = peripheral;
        
        // And connect
        NSLog(@"Connecting to peripheral %@", peripheral);
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

/** If the connection fails for whatever reason, we need to deal with it.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
    [self cleanup];
}

/** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral Connected");
    
    // Stop scanning
    [self.centralManager stopScan];
    NSLog(@"Scanning stopped");
    
    // Clear the data that we may already have
    [self.data setLength:0];
    
    // Make sure we get the discovery callbacks
    peripheral.delegate = self;
    
    // Search only for services that match our UUID
    [peripheral discoverServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]];
}

/** The Transfer Service was discovered
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }
    
    // Discover the characteristic we want...
    
    // Loop through the newly filled peripheral.services array, just in case there's more than one.
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]] forService:service];
    }
}

/** The Transfer characteristic was discovered.
 *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    // Deal with errors (if any)
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }
    
    // Again, we loop through the array, just in case.
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        // And check if it's the right one
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
            
            // If it is, subscribe to it
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
    
    // Once this is complete, we just need to wait for the data to come in.
}

/** This callback lets us know more data has arrived via notification on the characteristic
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }
    
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    
    // Have we got everything we need?
    if ([stringFromData isEqualToString:@"EOM"]) {
        
        // We have, so show the data,
//        [self.textview setText:[[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding]];
        NSLog(@"TEE HEE. %@", [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding]);
        
        // Cancel our subscription to the characteristic
        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
        
        // and disconnect from the peripehral
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
    
    // Otherwise, just add the data on to what we already have
    [self.data appendData:characteristic.value];
    
    // Log it
    NSLog(@"Received: %@", stringFromData);
}

/** The peripheral letting us know whether our subscribe/unsubscribe happened or not
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
    }
    
    // Exit if it's not the transfer characteristic
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
        return;
    }
    
    // Notification has started
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);
    }
    
    // Notification has stopped
    else {
        // so disconnect from the peripheral
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

/** Once the disconnection happens, we need to clean up our local copy of the peripheral
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Peripheral Disconnected");
    self.discoveredPeripheral = nil;
    
    // We're disconnected, so start scanning again
    [self scan];
}

/** Call this when things either go wrong, or you're done with the connection.
 *  This cancels any subscriptions if there are any, or straight disconnects if not.
 *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
 */
- (void)cleanup
{
    // Don't do anything if we're not connected
    if (self.discoveredPeripheral.state != CBPeripheralStateConnected) {
        return;
    }
    
    // See if we are subscribed to a characteristic on the peripheral
    if (self.discoveredPeripheral.services != nil) {
        for (CBService *service in self.discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            // It is notifying, so unsubscribe
                            [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            
                            // And we're done.
                            return;
                        }
                    }
                }
            }
        }
    }
    
    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}


#pragma mark - Bluetooth

//- (void)addBluetoothStuff {
//    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
//    _data = [[NSMutableData alloc] init];
//}
//
//- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
//    if (central.state != CBCentralManagerStatePoweredOn) {
//        return;
//    }
//    
//    //Scan for devices
//    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
//    NSLog(@"Scanning started...");
//}
//
//- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
//    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
//    if (_discoveredPeripheral != peripheral) {
//        //Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it.
//        _discoveredPeripheral = peripheral;
//        
//        //Add connect
//        NSLog(@"Connecting to peripheral %@", peripheral);
//        [_centralManager connectPeripheral:peripheral options:nil];
//    }
//}
//
//- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
//    NSLog(@"Failed to conenct.");
//    [self cleanupBluetooth];
//}
//
//- (void)cleanupBluetooth {
//    // See if we are subscribed to a characteristic on the peripheral
//    if (_discoveredPeripheral.services != nil) {
//        for (CBService *service in _discoveredPeripheral.services) {
//            if (service.characteristics != nil) {
//                for (CBCharacteristic *characteristic in service.characteristics) {
//                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
//                        if (characteristic.isNotifying) {
//                            [_discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
//                            return;
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    [_centralManager cancelPeripheralConnection:_discoveredPeripheral];
//}
//
//- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
//    NSLog(@"Peripheral Connected");
//    
//    [_centralManager stopScan];
//    NSLog(@"Scanning stopped");
//    
//    [_data setLength:0];
//    
//    peripheral.delegate = self;
//    
//    [peripheral discoverServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]];
//}
//
//- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
//    if (error) {
//        [self cleanupBluetooth];
//        return;
//    }
//    
//    for (CBService *service in peripheral.services) {
//        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]] forService:service];
//    }
//    
//    // Discover other characteristics
//}
//
//- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
//    if (error) {
//        [self cleanupBluetooth];
//        return;
//    }
//    
//    for (CBCharacteristic *characteristic in service.characteristics) {
//        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
//            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
//        }
//    }
//}
//
//- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
//    if (error) {
//        NSLog(@"Error");
//        return;
//    }
//    
//    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
//    
//    // Have we got everything we need?
//    if ([stringFromData isEqualToString:@"EOM"]) {
//        // HERE IS WHERE WE DO SOMETHING WITH THE TEXT
//        NSLog(@"%@", [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding]);
//        
//        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
//        
//        [_centralManager cancelPeripheralConnection:peripheral];
//    }
//    
//    [_data appendData:characteristic.value];
//}
//
//- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
//    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
//        return;
//    }
//    
//    if (characteristic.isNotifying) {
//        NSLog(@"Notification began on %@", characteristic);
//    } else {
//        //Notification has stopped
//        [_centralManager cancelPeripheralConnection:peripheral];
//    }
//}
//
//- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(nonnull CBPeripheral *)peripheral error:(nullable NSError *)error {
//    _discoveredPeripheral = nil;
//    
//    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
//}
//
//// We also nee to tell the centralManager to stop scanning when the view disappears...
//// But Moai's view controller seems to be set up in an outdated/nonstandard way, so I'm not
//// bothering with it for now.  Hummm.
////- (void)viewDidDisappear:(BOOL)animated {
////    [_centralManager stopScan];
////    
////    [super viewDidDisappear:animated];
////}


	
@end
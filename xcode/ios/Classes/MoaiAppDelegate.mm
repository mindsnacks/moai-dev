//----------------------------------------------------------------//
// Copyright (c) 2010-2011 Zipline Games, Inc. 
// All Rights Reserved. 
// http://getmoai.com
//----------------------------------------------------------------//

#import <aku/AKU.h>
#import <aku/AKU-iphone.h>

extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}

#import "MoaiAppDelegate.h"
#import "LocationObserver.h"
#import "MoaiVC.h"
#import "MoaiView.h"

//================================================================//
// AppDelegate
//================================================================//
@implementation MoaiAppDelegate

	@synthesize window = mWindow;
	@synthesize rootViewController = mMoaiVC;

	//----------------------------------------------------------------//
	-( void ) dealloc {

		[ mMoaiVC release ];
		[ mMoaiView release ];
		[ mWindow release ];
		[ super dealloc ];
	}

	//================================================================//
	#pragma mark -
	#pragma mark Protocol UIApplicationDelegate
	//================================================================//	

	//----------------------------------------------------------------//
	-( void ) application:( UIApplication* )application didFailToRegisterForRemoteNotificationsWithError:( NSError* )error {
	
		//AKUNotifyRemoteNotificationRegistrationComplete ( nil );
	}

	//----------------------------------------------------------------//
	-( BOOL ) application:( UIApplication* )application didFinishLaunchingWithOptions:( NSDictionary* )launchOptions {
		
//		[ application setStatusBarHidden:true ];
		
		mMoaiView = [[ MoaiView alloc ] initWithFrame:[ UIScreen mainScreen ].bounds ];
		[ mMoaiView setUserInteractionEnabled:YES ];
//		[ mMoaiView setMultipleTouchEnabled:YES ];
		[ mMoaiView setOpaque:YES ];
		[ mMoaiView setAlpha:1.0f ];

		mMoaiVC = [[ MoaiVC alloc ]	init ];
		[ mMoaiVC setView:mMoaiView ];
        [mMoaiVC addSwipeGestureRecognizer];
        [mMoaiVC addBluetoothStuff];
		
		mWindow = [[ UIWindow alloc ] initWithFrame:[ UIScreen mainScreen ].bounds ];
		[ mWindow setUserInteractionEnabled:YES ];
//		[ mWindow setMultipleTouchEnabled:YES ];
		[ mWindow setOpaque:YES ];
		[ mWindow setAlpha:1.0f ];
		[ mWindow addSubview:mMoaiView ];
		[ mWindow setRootViewController:mMoaiVC ];
		[ mWindow makeKeyAndVisible ];
        
		[ mMoaiView moaiInit:application ];
		
		// select product folder
		NSString *gameSourceDirectory = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"buzz"];
		AKUSetWorkingDirectory([gameSourceDirectory UTF8String]);
        
        NSString *sharedSourceDirectory = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"shared_source"];
        [self addSourcePath:sharedSourceDirectory];
        
        [self setupLuaAssetsTable];
        
        NSString *assetsPath = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"assets"];
        [self addAssetsPath:assetsPath];
        
//        [self addSourcePath:sourcePath];
		
		// run scripts
		[mMoaiView run:@"buzz_main.lua"];
		
        // check to see if the app was lanuched from a remote notification
//        NSDictionary* pushBundle = [ launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey ];
//        if ( pushBundle != NULL ) {
//            
//            AKUNotifyRemoteNotificationReceived ( pushBundle );
//        }
		
		// return
		return true;
	}

- (void)addSourcePath:(NSString *)pathToAppend {
    lua_State *l = AKUGetLuaState();
    lua_getglobal(l, "package");
    lua_getfield(l, -1, "path");
    NSString *originalPath = [NSString stringWithUTF8String:lua_tostring(l, -1)];
    NSString *extendedPath = [NSString stringWithFormat:@"%@;%@/?.lua", originalPath, pathToAppend];
    lua_pop(l, 1);
    lua_pushstring(l, [extendedPath UTF8String]);
    lua_setfield(l, -2, "path");
    lua_pop(l, 1);
}

- (void)setupLuaAssetsTable {
    lua_State *l = AKUGetLuaState();
    lua_newtable(l);
    lua_pushstring(l, "");
    lua_setfield(l, -2, "path");
    lua_setglobal(l, "asset");
}

- (void)addAssetsPath:(NSString *)pathToAppend {
    lua_State *l = AKUGetLuaState();
    lua_getglobal(l, "asset");
    lua_getfield(l, -1, "path");
    NSString *originalPath = [NSString stringWithUTF8String:lua_tostring(l, -1)];
    NSString *extendedPath = [NSString stringWithFormat:@"%@;%@", originalPath, pathToAppend];
    lua_pop(l, 1);
    lua_pushstring(l, [extendedPath UTF8String]);
    lua_setfield(l, -2, "path");
    lua_pop(l, 1);
}


	//----------------------------------------------------------------//
	-( void ) application:( UIApplication* )application didReceiveRemoteNotification:( NSDictionary* )pushBundle {
		
//		AKUNotifyRemoteNotificationReceived ( pushBundle );
	}
	
	//----------------------------------------------------------------//
	-( void ) application:( UIApplication* )application didRegisterForRemoteNotificationsWithDeviceToken:( NSData* )deviceToken {
	
//		AKUNotifyRemoteNotificationRegistrationComplete ( deviceToken );
	}
	
	//----------------------------------------------------------------//
	-( void ) applicationDidBecomeActive:( UIApplication* )application {
	
		// restart moai view
		[ mMoaiView pause:NO ];
	}
	
	//----------------------------------------------------------------//
	-( void ) applicationDidEnterBackground:( UIApplication* )application {
	}
	
	//----------------------------------------------------------------//
	-( void ) applicationWillEnterForeground:( UIApplication* )application {
	}
	
	//----------------------------------------------------------------//
	-( void ) applicationWillResignActive:( UIApplication* )application {
	
		// pause moai view
		[ mMoaiView pause:YES ];
	}
	
	//----------------------------------------------------------------//
	-( void ) applicationWillTerminate :( UIApplication* )application {

		AKUFinalize ();
	}

	//----------------------------------------------------------------//
	#if __IPHONE_OS_VERSION_MIN_REQUIRED > __IPHONE_4_1
		
		//----------------------------------------------------------------//
		// For iOS 4.2+ support
		-( BOOL )application:( UIApplication* )application openURL:( NSURL* )url sourceApplication:( NSString* )sourceApplication annotation:( id )annotation {

			AKUAppOpenFromURL ( url );
			return YES;
		}
	
	#else

		//----------------------------------------------------------------//
		-( BOOL )application :( UIApplication* )application handleOpenURL :( NSURL* )url {

			AKUAppOpenFromURL(url);
			return YES;
		}

	#endif

@end

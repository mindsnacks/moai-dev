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
#import "BuzzGameKitManager.h"

#import <AVFoundation/AVFoundation.h>

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
        [mMoaiVC addSwipeAndTapGestureRecognizers];
//        [mMoaiVC addSwipeGestureRecognizer];
        [mMoaiVC addBluetoothStuff];
        
        [mMoaiVC addGameCenterStuff];
		
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
        
        [self setupHostTable];
        [self setupGameSessionTable];
        [self setupGameCenterManagerTable];
        
		
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

#define PUSH_LUA_CALLBACK_HANDLER(l, callbackName, handler) lua_pushlightuserdata(l, this); lua_pushcclosure(l, handler, 1);

- (void)loadSoundAtPath:(NSString *)path {
    NSError *error = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:path] error:&error];
    
    NSAssert(error == nil, @"There was an error loading a sound.");
    
    self.audioPlayer = player;
    
    [self.audioPlayer prepareToPlay];
    
    return 0;
}

- (int)playSoundAtPath:(NSString *)path volume:(double)volume pitch:(double)pitch pan:(double)pan looping:(BOOL)looping {
    NSError *error = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:path] error:&error];
    
    NSAssert(error == nil, @"There was an error playing a sound.");
    
    self.audioPlayer = player;
    
    [self.audioPlayer prepareToPlay];
    [self.audioPlayer play];
    
    return 0;
}


static std::string _ms_lua_to_string(lua_State *const l, int index) {
    const char * const result = lua_tostring(l, index);
    //    MSCAssert(result, "NULL string");
    
    return result;
}

static int _MSMOAIPlaySoundHandler(lua_State *l) {
    //    MOAIIntegration *integration = getMOAIIntegration(l);
    
    int args = lua_gettop(l);
    
    if (args == 0) lua_error(l);
    
    const std::string &effect = _ms_lua_to_string(l, -args);
    
    float volume = 1.0f;
    float pitch = 1.0f;
    float pan = 0.0f;
    bool looping = false;
    
    if (args > 1) volume  = lua_tonumber(l, -args + 1);
    if (args > 2) pitch   = lua_tonumber(l, -args + 2);
    if (args > 3) pan     = lua_tonumber(l, -args + 3);
    if (args > 4) looping = lua_toboolean(l, -args + 4);
    
    
    //    if (integration->getDelegate() != NULL)
    //    {
    MoaiAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    int audioID = [delegate playSoundAtPath:[NSString stringWithUTF8String:effect.c_str()] volume:volume pitch:pitch pan:pan looping:looping];
    //        long audioID = integration->getDelegate()->moaiIntegrationPlaySoundAtPath(effect, volume, pitch, pan, looping);
    lua_pushinteger(l, audioID);
    return 1;
    //    }
    //    else
    //    {
    //        return 0;
    //    }
}

static int _MSMOAILoadSoundHandler(lua_State *l) {
//    MOAIIntegration *integration = getMOAIIntegration(l);
    
    int args = lua_gettop(l);
    if (args == 0) return 0;
    const std::string &path = _ms_lua_to_string(l, -1);
    
    MoaiAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    [delegate loadSoundAtPath:[NSString stringWithUTF8String:path.c_str()]];
//    if (integration->getDelegate() != NULL)
//    {
//        integration->getDelegate()->moaiIntegrationLoadSoundAtPath(path);
//    }
    
    return 0;
}

- (void)setupGameSessionTable {
    lua_State *l = AKUGetLuaState();
    
    // create GameSession
    lua_newtable(l);
    
    lua_pushstring(l, [@"" UTF8String]);
    lua_setfield(l, -2, "configJSON");
    
    // set GameSession
    lua_setglobal(l, "GameSession");
}


- (void)setupHostTable {
    lua_State *l = AKUGetLuaState();
    
    // create Host
    lua_newtable(l);
    
    lua_pushcfunction(l, _MSMOAIPlaySoundHandler);
    lua_setfield(l, -2, "playSound");
    
    lua_pushcfunction(l, _MSMOAILoadSoundHandler);
    lua_setfield(l, -2, "loadSound");
    
    lua_pushnumber(l, 3.0f);
    lua_setfield(l, -2, "contentScale");
    
    lua_pushstring(l, [@"@3x" UTF8String]);
    lua_setfield(l, -2, "assetSuffix");
    
    lua_pushstring(l, [@".caf" UTF8String]);
    lua_setfield(l, -2, "soundEffectFileExtension");
    
    lua_pushboolean(l, true);
    lua_setfield(l, -2, "environmentIsAppleTv");
    
    // set Host
    lua_setglobal(l, "Host");
}

#pragma mark GameCenter

- (void)setupGameCenterManagerTable {
    lua_State *l = AKUGetLuaState();
    
    // create GameCenterManager table
    lua_newtable(l);
    
    lua_pushcfunction(l, _MSMOAIShowDefaultMatchmakerViewController);
    lua_setfield(l, -2, "showDefaultMatchmakerViewController");
    
    // set Host
    lua_setglobal(l, "GameCenterManager");
}

static int _MSMOAIShowDefaultMatchmakerViewController(lua_State *l) {
    BuzzGameKitManager *buzzGameKitManager = [BuzzGameKitManager sharedBuzzGameKitManager];
    
    MoaiAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    MoaiVC *moaiVC = delegate.moaiVC;
    [buzzGameKitManager findMatchWithMinPlayers:2 maxPlayers:2 viewController:moaiVC];
}

- (MoaiVC *)moaiVC {
    return mMoaiVC;
}

static int _MSMOAINotifyGameCenterMatchStartedWithPlayers(lua_State *l) {
    //    MOAIIntegration *integration = getMOAIIntegration(l);
    
    int args = lua_gettop(l);
    
    if (args == 0) lua_error(l);
    
    const std::string &effect = _ms_lua_to_string(l, -args);
    
    float volume = 1.0f;
    float pitch = 1.0f;
    float pan = 0.0f;
    bool looping = false;
    
    if (args > 1) volume  = lua_tonumber(l, -args + 1);
    if (args > 2) pitch   = lua_tonumber(l, -args + 2);
    if (args > 3) pan     = lua_tonumber(l, -args + 3);
    if (args > 4) looping = lua_toboolean(l, -args + 4);
    
    
    //    if (integration->getDelegate() != NULL)
    //    {
    MoaiAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    int audioID = [delegate playSoundAtPath:[NSString stringWithUTF8String:effect.c_str()] volume:volume pitch:pitch pan:pan looping:looping];
    //        long audioID = integration->getDelegate()->moaiIntegrationPlaySoundAtPath(effect, volume, pitch, pan, looping);
    lua_pushinteger(l, audioID);
    return 1;
}

- (void)onGameCenterMatchStartedWithPlayers:(NSArray *)players {
    lua_State *l = AKUGetLuaState();
    
    // Get the event receiver
    lua_getglobal(l, "GameCenterManager");
    lua_getfield(l, -1, "onMatchStarted");
    
    // Push arguments on the stack
    unsigned int argumentsCount = 1;
    
    int playerIndex = 0;
    
    lua_createtable(l, (int)players.count, 0);
    for (GKPlayer *player in players) {
        
        playerIndex++;
        lua_pushnumber(l, playerIndex);
        
        const int fieldsCountPerDescriptor = 2;
        lua_createtable(l, 0, fieldsCountPerDescriptor);
        
        lua_pushstring(l, player.playerID.UTF8String);
        lua_setfield(l, -2, "playerId");
        
        lua_pushstring(l, player.alias.UTF8String);
        lua_setfield(l, -2, "alias");
        
        lua_settable(l, -3);
        
    }
    
    lua_pcall(l, argumentsCount, 0, 0);
    lua_pop(l, 1);
}

#pragma mark More Leftover Moai Stuff


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

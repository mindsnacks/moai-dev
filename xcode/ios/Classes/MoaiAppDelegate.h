//----------------------------------------------------------------//
// Copyright (c) 2010-2011 Zipline Games, Inc. 
// All Rights Reserved. 
// http://getmoai.com
//----------------------------------------------------------------//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "RefPtr.h"

#import <AVFoundation/AVFoundation.h>

#import <GameKit/GameKit.h>

@class MoaiVC;
@class MoaiView;

//================================================================//
// MoaiAppDelegate
//================================================================//
@interface MoaiAppDelegate : NSObject < UIApplicationDelegate > {
@private

	MoaiView*	mMoaiView;
	UIWindow*	mWindow;	
	MoaiVC*		mMoaiVC;
}

@property ( nonatomic, retain ) UIWindow* window;
@property ( nonatomic, retain ) UIViewController* rootViewController;

@property (strong) AVAudioPlayer *audioPlayer;

@property (readonly) MoaiVC *mMoaiVC;

- (int)playSoundAtPath:(NSString *)path volume:(double)volume pitch:(double)pitch pan:(double)pan looping:(BOOL)looping;
- (void)loadSoundAtPath:(NSString *)path;

- (void)onGameCenterMatchStartedWithPlayers:(NSArray *)players;

- (void)onReceivedDiceRoll:(NSInteger)diceRoll fromPlayer:(GKPlayer *)player;
- (void)onReceivedNounIndex:(NSInteger)nounIndex fromPlayer:(GKPlayer *)player;
- (void)onReceivedAdjectiveIndex:(NSInteger)adjectiveIndex fromPlayer:(GKPlayer *)player;
- (void)onReceivedAnswer:(NSInteger)answer withProportionRemaining:(double)proportionRemaining fromPlayer:(GKPlayer *)player;

@end

//
//  BuzzGameKitManager.h
//  buzz_prototype
//
//  Created by Aaron Barrett on 11/5/15.
//
//

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>

extern NSString *const PresentAuthenticationViewController;
extern NSString *const LocalPlayerIsAuthenticated;

@protocol BuzzGameKitManagerDelegate
- (void)matchStarted;
- (void)matchEnded;
- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromRemotePlayer:(GKPlayer *)player;
//- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromPlayer:(NSString *)playerID;
@end

@interface BuzzGameKitManager : NSObject <GKMatchmakerViewControllerDelegate, GKMatchDelegate>

@property (nonatomic, readonly) UIViewController *authenticationViewController;
@property (nonatomic, readonly) NSError *lastError;
@property (nonatomic, strong) GKMatch *match;
@property (nonatomic, assign) id <BuzzGameKitManagerDelegate> delegate;

+ (instancetype)sharedBuzzGameKitManager;

- (void)authenticateLocalPlayer;

- (void)findMatchWithMinPlayers:(NSUInteger)minPlayersCount
                     maxPlayers:(NSUInteger)maxPlayersCount
                 viewController:(UIViewController *)viewController
                       delegate:(id <BuzzGameKitManagerDelegate>)delegate;

@end

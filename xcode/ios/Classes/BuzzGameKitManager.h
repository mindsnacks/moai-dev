//
//  BuzzGameKitManager.h
//  buzz_prototype
//
//  Created by Aaron Barrett on 11/10/15.
//
//

#import <GameKit/GameKit.h>

NSString *const NOTIFICATION_PRESENT_AUTHENTICATION_VIEW_CONTROLLER = @"NOTIFICATION_PRESENT_AUTHENTICATION_VIEW_CONTROLLER";
NSString *const NOTIFICATION_LOCAL_PLAYER_IS_AUTHENTICATED = @"NOTIFICATION_LOCAL_PLAYER_IS_AUTHENTICATED";

@interface BuzzGameKitManager : NSObject <GKMatchmakerViewControllerDelegate, GKMatchDelegate>

@property (nonatomic, strong) UIViewController *authenticationViewController;

+ (instancetype)sharedBuzzGameKitManager;

- (void)authenticateLocalPlayer;

- (void)findMatchWithMinPlayers:(NSUInteger)minPlayersCount
                     maxPlayers:(NSUInteger)maxPlayersCount
                 viewController:(UIViewController *)viewController;

- (void)sendDiceRollToAllPlayers;
- (void)sendNounIndexToAllPlayers:(NSInteger)nounIndex;
- (void)sendAdjectiveIndexToAllPlayers:(NSInteger)adjectiveIndex;
- (void)sendAnswerToAllPlayers:(NSInteger)answer withProportionRemaining:(double)proportionRemaining;

@end

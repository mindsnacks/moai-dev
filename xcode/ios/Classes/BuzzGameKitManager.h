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

- (void)authenticateLocalPlayer;

@end

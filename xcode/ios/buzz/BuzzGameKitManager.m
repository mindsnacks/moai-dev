//
//  BuzzGameKitManager.m
//  buzz_prototype
//
//  Created by Aaron Barrett on 11/5/15.
//
//

#import "BuzzGameKitManager.h"

NSString *const PresentAuthenticationViewController = @"present_authentication_view_controller";
NSString *const LocalPlayerIsAuthenticated = @"local_player_authenticated";

@implementation BuzzGameKitManager {
    BOOL _enableGameCenter;
    BOOL _matchStarted;
}

+ (instancetype)sharedBuzzGameKitManager {
    static BuzzGameKitManager *sharedGameKitManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedGameKitManager = [[BuzzGameKitManager alloc] init];
    });
    return sharedGameKitManager;
}

- (id)init {
    if (self = [super init]) {
        _enableGameCenter = YES;
    }
    return self;
}

- (void)authenticateLocalPlayer {
    GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
    
    localPlayer.authenticateHandler =
    ^(UIViewController *viewController, NSError *error) {
        self.lastError = error;
        
        if (viewController != nil) {
            self.authenticationViewController = viewController;
        } else if (GKLocalPlayer.localPlayer.isAuthenticated) {
            _enableGameCenter = YES;
        } else {
            _enableGameCenter = NO;
        }
    };
}

- (void)setAuthenticationViewController:(UIViewController *)authenticationViewController {
    if (authenticationViewController != nil) {
        _authenticationViewController = authenticationViewController;
        [[NSNotificationCenter defaultCenter]
         postNotificationName:PresentAuthenticationViewController
         object:self];
    }
}

- (void)setLastError:(NSError *)lastError {
    _lastError = [lastError copy];
    if (_lastError) {
        NSLog(@"BuzzGameKitManager ERROR: %@",
              _lastError.userInfo.description);
    }
}


@end

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
    
    if (localPlayer.isAuthenticated) {
        [[NSNotificationCenter defaultCenter] postNotificationName:LocalPlayerIsAuthenticated object:nil];
        return;
    }
    
    localPlayer.authenticateHandler =
    ^(UIViewController *viewController, NSError *error) {
        self.lastError = error;
        
        if (viewController != nil) {
            self.authenticationViewController = viewController;
        } else if (GKLocalPlayer.localPlayer.isAuthenticated) {
            _enableGameCenter = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:LocalPlayerIsAuthenticated object:nil];
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

- (void)findMatchWithMinPlayers:(NSUInteger)minPlayersCount
                     maxPlayers:(NSUInteger)maxPlayersCount
                 viewController:(UIViewController *)viewController
                       delegate:(id<BuzzGameKitManagerDelegate>)delegate {
    if (!_enableGameCenter) {
        return;
    }
    
    _matchStarted = NO;
    self.match = nil;
    _delegate = delegate;
    [viewController dismissViewControllerAnimated:NO completion:nil];
    
    GKMatchRequest *request = [[GKMatchRequest alloc] init];
    request.minPlayers = minPlayersCount;
    request.maxPlayers = maxPlayersCount;
    
    GKMatchmakerViewController *matchmakerViewController = [[GKMatchmakerViewController alloc] initWithMatchRequest:request];
    matchmakerViewController.matchmakerDelegate = self;
    
    [viewController presentViewController:matchmakerViewController animated:YES completion:nil];
}

- (void)matchmakerViewControllerWasCancelled:(GKMatchmakerViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFailWithError:(NSError *)error {
    [viewController dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"Error finding match: %@", error.localizedDescription);
}

- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFindMatch:(GKMatch *)match {
    [viewController dismissViewControllerAnimated:YES completion:nil];
    self.match = match;
    match.delegate = self;
    if ((!_matchStarted) && (match.expectedPlayerCount == 0)) {
        NSLog(@"Ready to start match!");
    }
}

#pragma mark GKMatchDelegate

- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromRemotePlayer:(GKPlayer *)player {
    if (_match != match) {
        return;
    }
    [_delegate match:match didReceiveData:data fromRemotePlayer:player];
}

- (void)match:(GKMatch *)match player:(GKPlayer *)player didChangeConnectionState:(GKPlayerConnectionState)state {
    if (_match != match) {
        return;
    }
    
    if (state == GKPlayerStateConnected) {
        NSLog(@"Player connected!");
        
        if ((!_matchStarted) && (match.expectedPlayerCount == 0)) {
            NSLog(@"Ready to start match!");
        }
        
    } else if (state == GKPlayerStateDisconnected) {
        NSLog(@"Player disconnected!");
        
        _matchStarted = NO;
        [_delegate matchEnded];
        
    } else {
        NSAssert(NO, @"Unhandled GKPlayerConnectionState");
    }
}

- (void)match:(GKMatch *)match connectionWithPlayerFailed:(NSString *)playerID withError:(NSError *)error {
    if (_match != match) {
        return;
    }
    
    NSLog(@"Failed to connect to player with error: %@", error.localizedDescription);
    _matchStarted = NO;
    [_delegate matchEnded];
}

- (void)match:(GKMatch *)match didFailWithError:(NSError *)error {
    if (_match != match) {
        return;
    }
    
    NSLog(@"Match failed with error: %@", error.localizedDescription);
    _matchStarted = NO;
    [_delegate matchEnded];
}


@end

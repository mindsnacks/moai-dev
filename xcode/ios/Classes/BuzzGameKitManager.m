//
//  BuzzGameKitManager.m
//  buzz_prototype
//
//  Created by Aaron Barrett on 11/10/15.
//
//

#import "BuzzGameKitManager.h"

@class MoaiAppDelegate;


@interface BuzzGameKitManager ()

@property (nonatomic) BOOL gameCenterEnabled;
@property (nonatomic) BOOL matchStarted;
@property (nonatomic, strong) GKMatch *match;

@property (nonatomic, strong) NSMutableDictionary *playersByPlayerId;

@end



@implementation BuzzGameKitManager

+ (instancetype)sharedBuzzGameKitManager {
    static BuzzGameKitManager *buzzGameKitManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        buzzGameKitManager = [[BuzzGameKitManager alloc] init];
    });
    return buzzGameKitManager;
}

- (instancetype)init {
    if (self = [super init]) {
        self.gameCenterEnabled = YES;
        self.playersByPlayerId = nil;
    }
    return self;
}

- (void)authenticateLocalPlayer {
    NSLog(@"Attempting to authenticate local player.");
    
    GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
    
    if (localPlayer.isAuthenticated) {
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_LOCAL_PLAYER_IS_AUTHENTICATED object:nil];
        return;
    }
    
    localPlayer.authenticateHandler = ^(UIViewController *viewController, NSError *error) {
        if (error != nil) {
            NSLog(@"There was an error in localPlayer.authenticateHandler: %@", error.userInfo.description);
        }
        
        if (viewController != nil) {
            self.authenticationViewController = viewController;
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_PRESENT_AUTHENTICATION_VIEW_CONTROLLER object:self];
        } else if ([GKLocalPlayer localPlayer].isAuthenticated) {
            self.gameCenterEnabled = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_LOCAL_PLAYER_IS_AUTHENTICATED object:nil];
        } else {
            NSLog(@"Disabling Game Center.");
            self.gameCenterEnabled = NO;
        }
    };
}

- (void)findMatchWithMinPlayers:(NSUInteger)minPlayersCount maxPlayers:(NSUInteger)maxPlayersCount viewController:(UIViewController *)viewController {
    if (!self.gameCenterEnabled) {
        return;
    }
    
    self.matchStarted = NO;
    self.match = nil;
    
    [viewController dismissViewControllerAnimated:NO completion:nil];
    
    GKMatchRequest *request = [[GKMatchRequest alloc] init];
    request.minPlayers = minPlayersCount;
    request.maxPlayers = maxPlayersCount;
    
    GKMatchmakerViewController *matchmakerViewController = [[GKMatchmakerViewController alloc] initWithMatchRequest:request];
    matchmakerViewController.matchmakerDelegate = self;
    
    [viewController presentViewController:matchmakerViewController animated:YES completion:nil];
}

+ (NSArray *)playerIdsForPlayers:(NSArray *)players {
    NSMutableArray *playerIds = [NSMutableArray array];
    
    for (GKPlayer *player in players) {
        NSString *playerId = player.playerID;
        [playerIds addObject:playerId];
    }
    
    return playerIds;
}

- (void)lookupPlayers {
    NSLog(@"Looking up players.  There is %lu of them.", (unsigned long)self.match.players.count);
    
    NSArray *playerIds = [BuzzGameKitManager playerIdsForPlayers:self.match.players];
    [GKPlayer loadPlayersForIdentifiers:playerIds withCompletionHandler:^(NSArray *players, NSError *error) {
        if (error != nil) {
            NSLog(@"Error retrieving player info: %@", error.localizedDescription);
            self.matchStarted = NO;
            //[_delegate matchEnded];
        } else {
            self.playersByPlayerId = [NSMutableDictionary dictionaryWithCapacity:players.count];
            
            for (GKPlayer *player in players) {
                NSLog(@"Found player: %@ alias: %@", player.playerID, player.alias);
                self.playersByPlayerId[player.playerID] = player;
            }
            
            GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
            self.playersByPlayerId[localPlayer.playerID] = localPlayer;
            
            NSLog(@"The match is starting.");
            self.matchStarted = YES;
            
            MoaiAppDelegate *delegate = (MoaiAppDelegate *)[[UIApplication sharedApplication] delegate];
            [delegate onGameCenterMatchStartedWithPlayers:players];
        }
    }];
}

#pragma mark GKMatchmakerViewControllerDelegate

- (void)matchmakerViewControllerWasCancelled:(GKMatchmakerViewController *)viewController {
    NSLog(@"Matchmaker view controller was cancelled.");
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFailWithError:(NSError *)error {
    NSLog(@"Matchmaker view controller failed with error: %@", error.localizedDescription);
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFindMatch:(GKMatch *)match {
    NSLog(@"Matchmaker view controller did find match!");
    [viewController dismissViewControllerAnimated:YES completion:nil];
    
    self.match = match;
    match.delegate = self;
    
    if (!self.matchStarted && match.expectedPlayerCount == 0) {
        NSLog(@"Match not yet started and expectedPlayerCount == 0, so starting match!");
        [self lookupPlayers];
    }
    
}

#pragma mark GKMatchDelegate

- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromRemotePlayer:(GKPlayer *)player {
    NSLog(@"The match received data.");
}

- (void)match:(GKMatch *)match player:(GKPlayer *)player didChangeConnectionState:(GKPlayerConnectionState)state {
    NSLog(@"The match changed connection states.");
}

- (void)match:(GKMatch *)match didFailWithError:(NSError *)error {
    NSLog(@"The match failed with error: %@", error.localizedDescription);
}

@end

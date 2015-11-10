//
//  MultiplayerNetworking.h
//  buzz_prototype
//
//  Created by Aaron Barrett on 11/9/15.
//
//

#import <Foundation/Foundation.h>
#import "BuzzGameKitManager.h"

@protocol MultiplayerNetworkingProtocol <NSObject>
- (void)matchEnded;
- (void)setCurrentPlayerIndex:(NSUInteger)index;
- (void)movePlayerAtIndex:(NSUInteger)index;
- (void)gameOver:(BOOL)player1Won;
- (void)setPlayerAliases:(NSArray*)playerAliases;
@end


@interface MultiplayerNetworking : NSObject <BuzzGameKitManagerDelegate>

@property (nonatomic, assign) id<MultiplayerNetworkingProtocol> delegate;
- (void)sendMove;
- (void)sendGameEnd:(BOOL)player1Won;

@end

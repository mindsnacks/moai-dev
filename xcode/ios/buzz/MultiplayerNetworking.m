//
//  MultiplayerNetworking.m
//  buzz_prototype
//
//  Created by Aaron Barrett on 11/9/15.
//
//

#import "MultiplayerNetworking.h"

#define playerIdKey @"PlayerId"
#define randomNumberKey @"randomNumber"

typedef NS_ENUM(NSUInteger, GameState) {
    kGameStateWaitingForMatch = 0,
    kGameStateWaitingForRandomNumber,
    kGameStateWaitingForStart,
    kGameStateActive,
    kGameStateDone
};

typedef NS_ENUM(NSUInteger, MessageType) {
    kMessageTypeRandomNumber = 0,
    kMessageTypeGameBegin,
    kMessageTypeMove,
    kMessageTypeGameOver
};

typedef struct {
    MessageType messageType;
} Message;

typedef struct {
    Message message;
    uint32_t randomNumber;
} MessageRandomNumber;

typedef struct {
    Message message;
} MessageGameBegin;

typedef struct {
    Message message;
} MessageMove;

typedef struct {
    Message message;
    BOOL player1Won;
} MessageGameOver;

@implementation MultiplayerNetworking {
    uint32_t _ourRandomNumber;
    GameState _gameState;
    BOOL _isPlayer1;
    BOOL _receivedAllRandomNumbers;
    
    NSMutableArray *_orderOfPlayers;
}


- (id)init {
    if (self = [super init]) {
        _ourRandomNumber = arc4random();
        _gameState = kGameStateWaitingForMatch;
        _orderOfPlayers = [NSMutableArray array];
        [_orderOfPlayers addObject:@{playerIdKey : GKLocalPlayer.localPlayer.playerID,
                                     randomNumberKey : @(_ourRandomNumber)}];
    }
    return self;
}

- (void)matchStarted {
    NSLog(@"Match has started successfully.");
    if (_receivedAllRandomNumbers) {
        _gameState = kGameStateWaitingForStart;
    } else {
        _gameState = kGameStateWaitingForRandomNumber;
    }
    
    [self sendRandomNumber];
    [self tryStartGame];
}

- (void)sendData:(NSData *)data {
    NSError *error;
    BuzzGameKitManager *buzzGameKitManager = [BuzzGameKitManager sharedBuzzGameKitManager];
    
    BOOL success = [buzzGameKitManager.match sendDataToAllPlayers:data
                                                     withDataMode:GKMatchSendDataReliable
                                                            error:&error];
    
    if (!success) {
        NSLog(@"Error sending data:%@", error.localizedDescription);
        [self matchEnded];
    }
}

- (void)sendRandomNumber {
    MessageRandomNumber message;
    message.message.messageType = kMessageTypeRandomNumber;
    message.randomNumber = _ourRandomNumber;
    NSData *data = [NSData dataWithBytes:&message length:sizeof(MessageRandomNumber)];
    [self sendData:data];
}

- (void)sendGameBegin {
    MessageGameBegin message;
    message.message.messageType = kMessageTypeGameBegin;
    NSData *data = [NSData dataWithBytes:&message length:sizeof(MessageGameBegin)];
    [self sendData:data];
}

- (void)sendGameEnd:(BOOL)player1Won {
    MessageGameOver message;
    message.message.messageType = kMessageTypeGameOver;
    message.player1Won = player1Won;
    NSData *data = [NSData dataWithBytes:&message length:sizeof(MessageGameOver)];
    [self sendData:data];
}

- (void)tryStartGame {
    if (_isPlayer1 && _gameState == kGameStateWaitingForStart) {
        _gameState = kGameStateActive;
        [self sendGameBegin];
    }
}

- (void)processReceivedRandomNumber:(NSDictionary *)randomNumberDetails {
    if ([_orderOfPlayers containsObject:randomNumberDetails]) {
        [_orderOfPlayers removeObjectAtIndex:[_orderOfPlayers indexOfObject:randomNumberDetails]];
    }
    
    [_orderOfPlayers addObject:randomNumberDetails];
    
    NSSortDescriptor *sortByRandomNumber = [NSSortDescriptor sortDescriptorWithKey:randomNumberKey ascending:NO];
    NSArray *sortDescriptors = @[sortByRandomNumber];
    [_orderOfPlayers sortUsingDescriptors:sortDescriptors];
    
    if (self.allRandomNumbersAreReceieved) {
        _receivedAllRandomNumbers = YES;
    }
}

// Aaron's Note: Huh?  Pretty sure this can be dramatically simplified.
- (BOOL)allRandomNumbersAreReceieved {
    NSMutableArray *receivedRandomNumbers = [NSMutableArray array];
    
    for (NSDictionary *dictionary in _orderOfPlayers) {
        [receivedRandomNumbers addObject:dictionary[randomNumberKey]];
    }
    
    NSArray *arrayOfUniqueRandomNumbers = [[NSSet setWithArray:receivedRandomNumbers] allObjects];
    if (arrayOfUniqueRandomNumbers.count == BuzzGameKitManager.sharedBuzzGameKitManager.match.players.count + 1) {
        return YES;
    }
    return NO;
}

- (BOOL)isLocalPlayerPlayer1 {
    NSDictionary *dictionary = _orderOfPlayers[0];
    if ([dictionary[playerIdKey] isEqualToString:[GKLocalPlayer localPlayer].playerID]) {
        NSLog(@"I'm player 1.");
        return YES;
    }
    NSLog(@"I'm NOT player 1.");
    return NO;
}

- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromRemotePlayer:(GKPlayer *)player {
    Message *message = (Message *)data.bytes;
    
    if (message->messageType == kMessageTypeRandomNumber) {
        MessageRandomNumber *messageRandomNumber = (MessageRandomNumber *)data.bytes;
        NSLog(@"Received random number: %d", messageRandomNumber->randomNumber);
        
        BOOL tie = NO;
        if (messageRandomNumber->randomNumber == _ourRandomNumber) {
            NSLog(@"Tie");
            tie = YES;
            _ourRandomNumber = arc4random();
            [self sendRandomNumber];
        } else {
            NSDictionary *dictionary = @{playerIdKey : player.playerID,
                                         randomNumberKey : @(messageRandomNumber->randomNumber)};
            [self processReceivedRandomNumber:dictionary];
        }
        
        if (_receivedAllRandomNumbers) {
            _isPlayer1 = [self isLocalPlayerPlayer1];
        }
        
        if (!tie && _receivedAllRandomNumbers) {
            if (_gameState == kGameStateWaitingForRandomNumber) {
                _gameState = kGameStateWaitingForStart;
            }
            [self tryStartGame];
        }
    }
    
}

- (void)matchEnded {
    NSLog(@"Match has ended");
    [_delegate matchEnded];
}



@end

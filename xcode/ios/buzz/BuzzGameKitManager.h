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

@interface BuzzGameKitManager : NSObject

@property (nonatomic, readonly) UIViewController *authenticationViewController;
@property (nonatomic, readonly) NSError *lastError;

+ (instancetype)sharedBuzzGameKitManager;

- (void)authenticateLocalPlayer;

@end

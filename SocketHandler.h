//
//  SocketHandler.h
//  SocketExample
//
//  Created by sudeep on 29/09/15.
//  Copyright (c) 2015 Sudeep Jaiswal. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SIOSocket.h"

@interface SocketHandler : NSObject
@property (nonatomic) SIOSocket *socket;

+ (instancetype)shared;
- (void)connectSocket;
- (void)setUpEmit_on:(NSString *)event message:(NSArray *)argument;
- (void)disconnectSocket;
@end

/**
 *  let's say there's a class "ViewController" that needs to handle a socket event called "new_connection" from the server.
 *
 *  in the .m file, method "setUpListeners", we are handling that event. i am creating an NSNotification for this event.
 */

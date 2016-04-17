//
//  ContactBook.h
//  tawk@Eaze
//
//  Created by Santosh Narawade on 14/12/15.
//  Copyright (c) 2015 Santosh Narawade. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ContactBook : NSObject

+ (instancetype)shared;
+(NSArray *)contactNameFor:(NSArray *)contNumberArray;
- (NSArray *)getContactListFromDevice;

@end

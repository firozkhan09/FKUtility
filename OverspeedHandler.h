//
//  OverspeedHandler.h
//  Tawk@Eaze
//
//  Created by Santosh Narawade on 11/02/16.
//  Copyright (c) 2016 Santosh Narawade. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@protocol OverspeedHandlerDelegate <NSObject>

-(void)userMovingAtOverSpeed;

@end

@interface OverspeedHandler : NSObject <CLLocationManagerDelegate>

@property(nonatomic)id<OverspeedHandlerDelegate> speedDelegate;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *oldLocation, *currentLocation;
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSMutableArray *observerArray;

+ (instancetype)shared;

-(void)starDetectingSpeed;
-(void)stopDetectingSpeed;

@end

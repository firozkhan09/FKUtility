//
//  OverspeedHandler.m
//  Tawk@Eaze
//
//  Created by Santosh Narawade on 11/02/16.
//  Copyright (c) 2016 Santosh Narawade. All rights reserved.
//

#import "OverspeedHandler.h"

@implementation OverspeedHandler

+ (instancetype)shared {
  static OverspeedHandler *overspeedHandler = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    overspeedHandler = [[self alloc] init];
  });
  return overspeedHandler;
}

-(void)starDetectingSpeed
{  
  if (!_locationManager) {
    
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    _locationManager.distanceFilter = kCLDistanceFilterNone;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
    [_locationManager requestWhenInUseAuthorization];
  }
  
  //  _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateLocation) userInfo:nil repeats:YES];
}

-(void)stopDetectingSpeed
{
  //  [_timer invalidate];
  //  _oldLocation = nil;
  //  _currentLocation = nil;
  _locationManager.delegate = nil;
  [_locationManager stopUpdatingLocation];
  _locationManager = nil;
}

-(void)updateLocation
{
  
  [_locationManager startUpdatingLocation];
  if (_oldLocation && _locationManager.location.speed>=0) {
    CLLocationDistance itemDist = [_oldLocation distanceFromLocation:_locationManager.location];
    if (itemDist*3.6>15)
      //      [self.speedDelegate userMovingAtOverSpeed];
      [[NSNotificationCenter defaultCenter] postNotificationName:@"UserAtOverSpeed" object:_observerArray];
  }
  
  [_locationManager stopUpdatingLocation];
  _oldLocation = [[CLLocation alloc]
                  initWithLatitude  :_locationManager.location.coordinate.latitude
                  longitude :_locationManager.location.coordinate.longitude];
  _locationManager = [[CLLocationManager alloc] init];
}

#pragma mark - CLLocationManagerDelegate methods.

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
  if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
    [_locationManager startUpdatingLocation];
  }
}


- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
  
  CLLocation *location = [locations lastObject];
  
  if (location.speed*3.6>15             &&
      location.horizontalAccuracy <=10  &&
      location.horizontalAccuracy >0)
    [[NSNotificationCenter defaultCenter] postNotificationName:@"UserAtOverSpeed" object:_observerArray];
}

@end

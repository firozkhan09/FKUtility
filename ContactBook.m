//
//  ContactBook.m
//  tawk@Eaze
//
//  Created by Santosh Narawade on 14/12/15.
//  Copyright (c) 2015 Santosh Narawade. All rights reserved.
//

#import "ContactBook.h"
#import "UserInfo.h"
#import <AddressBookUI/AddressBookUI.h>
#import <AddressBook/AddressBook.h>

@interface ContactBook ()

- (NSArray*)getContactsWithAddressBook:(ABAddressBookRef)addressBook;
- (NSString*)stringByReplacingSymbolesFor:(NSString *)orignal;

@end

@implementation ContactBook

+ (instancetype)shared {
  static ContactBook *contactBook = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    contactBook = [[self alloc] init];
  });
  return contactBook;
}

+(NSArray *)contactNameFor:(NSArray *)contNumberArray
{
  NSData *userData = [[NSUserDefaults standardUserDefaults] objectForKey:@"user_login"];
  UserInfo *user = [NSKeyedUnarchiver unarchiveObjectWithData:userData];
  BOOL userExist = NO;
  NSMutableArray *contactNameList = [[NSMutableArray alloc]init];
  NSArray *diviceContactArray = [[ContactBook shared] getContactListFromDevice];
  for (NSString *contact in contNumberArray) {
    
    //search ContactName
    NSPredicate *predicate =[NSPredicate predicateWithFormat:@"Phone==%@", contact];
    NSArray *filteredArray = [diviceContactArray filteredArrayUsingPredicate:predicate];
    NSString *contactNameStr =(filteredArray.count>0)?filteredArray[0][@"name"]:contact;
    if (![contact isEqualToString:user.u_contact])
      [contactNameList addObject:contactNameStr];
    else
      userExist = YES;
  }
  if (userExist)[contactNameList addObject:@"You"];
  return contactNameList;
}

- (NSArray *)getContactListFromDevice{
  
  NSArray *contactList ;
  
  //get Divice Contact List
  ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
  
  __block BOOL accessGranted = NO;
  
  if (&ABAddressBookRequestAccessWithCompletion != NULL) { // We are on iOS 6
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
      accessGranted = granted;
      dispatch_semaphore_signal(semaphore);
    });
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
  }
  
  else { // We are on iOS 5 or Older
    accessGranted = YES;
    contactList = [self getContactsWithAddressBook:addressBook];
  }
  
  if (accessGranted) {
    contactList = [self getContactsWithAddressBook:addressBook];
  }
  return contactList;
}

-(NSArray*)getContactsWithAddressBook:(ABAddressBookRef)addressBook{
  NSMutableArray *tempContactList = [[NSMutableArray alloc] init];
  
  CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(addressBook);
  CFIndex nPeople = ABAddressBookGetPersonCount(addressBook);
  
  for (int i=0;i < nPeople;i++) {
    
    NSMutableDictionary *dOfPerson=[NSMutableDictionary dictionary];
    
    ABRecordRef ref = CFArrayGetValueAtIndex(allPeople,i);
    
    //For username and surname
    ABMultiValueRef phones =(__bridge ABMultiValueRef)((__bridge NSString*)ABRecordCopyValue(ref, kABPersonPhoneProperty));
    
    CFStringRef firstName, lastName, name;
    firstName = ABRecordCopyValue(ref, kABPersonFirstNameProperty);
    lastName  = ABRecordCopyValue(ref, kABPersonLastNameProperty);
    name  = ABRecordCopyCompositeName(ref);//(ref, kABPersonAddressCountryCodeKey);
    [dOfPerson setObject:[NSString stringWithFormat:@"%@", name] forKey:@"name"];
    
    //For Email ids
    ABMutableMultiValueRef eMail  = ABRecordCopyValue(ref, kABPersonEmailProperty);
    if(ABMultiValueGetCount(eMail) > 0) {
      
      [dOfPerson setObject:(__bridge NSString *)ABMultiValueCopyValueAtIndex(eMail, 0) forKey:@"email"];
    }
    
    //For Phone number
    NSArray *phoneNum = (__bridge NSArray *)ABMultiValueCopyArrayOfAllValues(phones);
    for (int k=0; k<[phoneNum count]; k++)
    {
      
      NSString *originalString =[phoneNum objectAtIndex:k];
      [dOfPerson setObject:[self stringByReplacingSymbolesFor:originalString] forKey:@"Phone"];
      
    }
    
    if ([dOfPerson[@"Phone"] isKindOfClass:[NSString class]] && [dOfPerson[@"name"] isKindOfClass:[NSString class]] && ![dOfPerson[@"name"] isEqualToString:@"(null)"]) {
      [tempContactList addObject:dOfPerson];
    }
    
  }
  
  return tempContactList;
}

-(NSString*)stringByReplacingSymbolesFor:(NSString *)orignal{
  
  NSMutableString *strippedString = [NSMutableString stringWithCapacity:orignal.length];
  
  NSScanner *scanner = [NSScanner scannerWithString:orignal];
  NSCharacterSet *numbers = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
  
  while ([scanner isAtEnd] == NO) {
    
    NSString *buffer;
    if ([scanner scanCharactersFromSet:numbers intoString:&buffer]) {
      
      [strippedString appendString:buffer];
    }
    else {
      
      [scanner setScanLocation:([scanner scanLocation] + 1)];
    }
  }
  
  if ([strippedString hasPrefix:@"0"] && [strippedString length] > 1) {
    
    strippedString = [[strippedString substringFromIndex:1] mutableCopy];
  }
  return strippedString;
}


@end

; //
//  SocketHandler.m
//  SocketExample
//
//  Created by sudeep on 29/09/15.
//  Copyright (c) 2015 Sudeep Jaiswal. All rights reserved.
//

#import "SocketHandler.h"
#import "UserInfo.h"
#import "DB_Handler.h"
#import "ContactBook.h"

//static NSString *const kBaseURL = @"http://192.168.0.6:8080";//local
static NSString *const kBaseURL = @"http://99.111.104.82:8080";//live

@interface SocketHandler ()

- (void)setUpSocketBlocks;
- (void)setUpListeners;
- (void)notifyUserSocketConnected:(BOOL)onConnect;
- (void)groupDetailUpdatedWith:(NSDictionary *)dataDict;
- (void)createGroupNotificationWith:(NSDictionary *)dataDict;
@end

@implementation SocketHandler

+ (instancetype)shared {
  static SocketHandler *socketHandler = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    socketHandler = [[self alloc] init];
  });
  return socketHandler;
}

#pragma mark - Socket

- (void)connectSocket
{
  
  [SIOSocket socketWithHost:kBaseURL response:^(SIOSocket *socket)
   {
     _socket = socket;
     [self setUpSocketBlocks];
     [self setUpListeners];
   }];
}

-(void)disconnectSocket{
  
  [_socket close];
}

- (void)setUpSocketBlocks {
  
  __weak SocketHandler *weakSelf = self;
  
  [_socket setOnConnect:^{
    // on connect
    NSLog(@"on connect");
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"on_connect"];
    
    UserInfo *user = [[UserInfo alloc]init];
    NSData *userData = [[NSUserDefaults standardUserDefaults] objectForKey:@"user_login"];
    [weakSelf notifyUserSocketConnected:YES];
    user = [NSKeyedUnarchiver unarchiveObjectWithData:userData];
    if (user){
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      [dict setObject:user.u_contact                      forKey:@"phone_no"];
      [dict setObject:user.u_id                           forKey:@"user_id"];
      [dict setObject:[[NSTimeZone localTimeZone]name]    forKey:@"timezone"];
      [weakSelf.socket emit:@"set_socket_id" args:@[dict]];
    }
  }];
  
  [_socket setOnConnectError:^(NSDictionary *info) {
    // on connect error
    NSLog(@"on connect error");
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"on_connect"];
  }];
  
  [_socket setOnDisconnect:^{
    // on disconnect
    NSLog(@"on disconnect");
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"on_connect"];
    [weakSelf notifyUserSocketConnected:NO];
  }];
  
  [_socket setOnError:^(NSDictionary *info) {
    // on error
    NSLog(@"on error");
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"on_connect"];
  }];
  
  [_socket setOnReconnect:^(NSInteger numberOfAttempts) {
    // on reconnect
    NSLog(@"on reconnect");
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"on_connect"];
  }];
  
  [_socket setOnReconnectionAttempt:^(NSInteger numberOfAttempts) {
    // on reconnection attempt
    NSLog(@"on reconnection attempt");
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"on_connect"];
  }];
  
  [_socket setOnReconnectionError:^(NSDictionary *info) {
    // on reconnect error
    NSLog(@"on reconnect error");
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"on_connect"];
  }];
}

-(void)setUpEmit_on:(NSString *)event message:(NSArray *)argument{
  
  [_socket emit:event args:argument];
}

- (void)groupDetailUpdatedWith:(NSDictionary *)dataDict{
  
  NSString *message ;
  NSData *userData = [[NSUserDefaults standardUserDefaults] objectForKey:@"user_login"];
  UserInfo *user = [NSKeyedUnarchiver unarchiveObjectWithData:userData];
  
  if ([dataDict[@"mode"]isEqualToString:@"update_name"]) {
    [[DB_Handler shared] updateGroupNameOf:dataDict[@"group_id"]
                                  withName:dataDict[@"title"]];
    NSArray *contactName =[ContactBook contactNameFor:@[dataDict[@"updated_by"]]];
    message  = [NSString stringWithFormat:@"%@ updated group name",contactName[0]];
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"NameUpdated" object:dataDict];
  }
  else if ([dataDict[@"mode"]isEqualToString:@"update_pic"]) {
    NSMutableDictionary *imageInfo = [[NSMutableDictionary alloc] init];
    [imageInfo setObject:dataDict[@"img_tag"]       forKey:@"image_tag"];
    [imageInfo setObject:dataDict[@"image_path"]    forKey:@"image_path"];
    [imageInfo setObject:@"no seen"                 forKey:@"seen_status"];
    [imageInfo setObject:dataDict[@"group_id"]      forKey:@"u_id"];
    [imageInfo setObject:@"no status"               forKey:@"cont_status"];
    [[DB_Handler shared] updateImageInfoFor:imageInfo];//group image
    
    NSArray *contactName =[ContactBook contactNameFor:@[dataDict[@"updated_by"]]];
    message  = [NSString stringWithFormat:@"%@ updated group icon",contactName[0]];
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"GroupIconUpdated" object:dataDict];
  }
  else if ([dataDict[@"mode"]isEqualToString:@"add_contact"]) {
    
    NSMutableDictionary *newGroupMember = [[NSMutableDictionary alloc] init];
    [newGroupMember setObject:dataDict[@"group_name"]   forKey:@"group_name"];
    [newGroupMember setObject:dataDict[@"group_id"]     forKey:@"group_id"];
    [newGroupMember setObject:dataDict[@"title"]        forKey:@"contact"];
    [newGroupMember setObject:dataDict[@"user_name"]    forKey:@"cont_name"];
    [newGroupMember setObject:@"member"                 forKey:@"role"];
    [[DB_Handler shared]insertIntoGroupDB:newGroupMember];
    
    NSArray *contactName =[ContactBook contactNameFor:@[dataDict[@"updated_by"],newGroupMember[@"contact"]]];
    message  = (![dataDict[@"updated_by"] isEqualToString:user.u_contact])?
              [NSString stringWithFormat:@"%@ added %@",contactName[0],contactName[1]]:
              [NSString stringWithFormat:@"You added %@",contactName[0]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ContactAdded" object:dataDict];
  }
  else if ([dataDict[@"mode"]isEqualToString:@"remove_contact"]) {
    
    [[DB_Handler shared] deleteMember:dataDict[@"removed_user"] fromGroup:dataDict[@"group_id"]];
    
    NSArray *contactName =[ContactBook contactNameFor: @[dataDict[@"updated_by"],dataDict[@"removed_user"]]];
    message =(![dataDict[@"updated_by"] isEqualToString:user.u_contact])?
             [NSString stringWithFormat:@"%@ removed %@",contactName[0],contactName[1]]:
             [NSString stringWithFormat:@"You removed %@",contactName[0]];
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"ContactRemoved"
     object:dataDict];
  }
  
  //insert Notification to Chat DB
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setDateFormat:@"dd MMM hh:mm a"];
  NSString *date = [formatter stringFromDate:[NSDate date]];
  
  NSMutableDictionary *chatDict = [[NSMutableDictionary alloc]init];
  [chatDict setObject:dataDict[@"group_name"]   forKey:@"chat_with"];
  [chatDict setObject:dataDict[@"group_id"]     forKey:@"cw_id"];
  [chatDict setObject:@"group"                  forKey:@"cw_type"];
  [chatDict setObject:message                   forKey:@"message"];
  [chatDict setObject:@"notification"           forKey:@"data_type"];
  [chatDict setObject:@"notification"           forKey:@"file_name"];
  [chatDict setObject:date                      forKey:@"date_time"];
  [chatDict setObject:dataDict[@"group_name"]   forKey:@"group_name"];
  [chatDict setObject:user.u_contact            forKey:@"from"];
  [chatDict setObject:user.u_id                 forKey:@"my_id"];
  [[DB_Handler shared]insertIntoChatDB:chatDict isRecived:YES isSended:YES];
  //end
  [[NSNotificationCenter defaultCenter] postNotificationName:@"GroupDetailUpdated"
                                                      object:dataDict];
}

-(void)createGroupNotificationWith:(NSDictionary *)dataDict
{
  //insert ChatMessage to Chat DB
  NSData *userData = [[NSUserDefaults standardUserDefaults] objectForKey:@"user_login"];
  UserInfo *user = [NSKeyedUnarchiver unarchiveObjectWithData:userData];
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setDateFormat:@"dd MMM hh:mm a"];
  NSString *date = [formatter stringFromDate:[NSDate date]];
  NSArray *contactName =[ContactBook contactNameFor:@[dataDict[@"created"]]];
  NSString *message = [NSString stringWithFormat:@"%@ create group",contactName[0]];
  
  NSMutableDictionary *chatDict = [[NSMutableDictionary alloc]init];
  [chatDict setObject:dataDict[@"group_name"]     forKey:@"chat_with"];
  [chatDict setObject:dataDict[@"group_id"]       forKey:@"cw_id"];
  [chatDict setObject:@"group"                    forKey:@"cw_type"];
  [chatDict setObject:message                     forKey:@"message"];
  [chatDict setObject:@"notification"             forKey:@"data_type"];
  [chatDict setObject:@"notification"             forKey:@"file_name"];
  [chatDict setObject:date                        forKey:@"date_time"];
  [chatDict setObject:dataDict[@"group_name"]     forKey:@"group_name"];
  [chatDict setObject:user.u_contact              forKey:@"from"];
  [chatDict setObject:user.u_id                   forKey:@"my_id"];
  [[DB_Handler shared]insertIntoChatDB:chatDict isRecived:YES isSended:YES];
  //end
  
  //insert ChatList Info DB
  if(![DB_Handler existUserFor:dataDict[@"group_id"]])
  {
    NSMutableDictionary *infoDict = [[NSMutableDictionary alloc]init];
    [infoDict setObject:dataDict[@"group_name"] forKey:@"contact"];
    [infoDict setObject:dataDict[@"group_id"]   forKey:@"u_id"];
    [infoDict setObject:@"group"                forKey:@"cont_type"];
    [infoDict setObject:@"no"                   forKey:@"seen_status"];
    [infoDict setObject:@"no"                   forKey:@"image_tag"];
    [infoDict setObject:@"no"                   forKey:@"image_path"];
    [infoDict setObject:@"no"                   forKey:@"cont_status"];
    [infoDict setObject:@"0"                    forKey:@"userBlocked"];
    [[DB_Handler shared]insertIntoInfoDB:infoDict];
  }
  //end
  
  //send socket for Group details
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  [dict setObject:dataDict[@"group_id"]           forKey:@"group_id"];
  [self.socket emit:@"get_group_data" args:@[dict]];
  //end
  
  //Notification to user
  [[NSNotificationCenter defaultCenter] postNotificationName:@"GroupCreatedResponse" object:dataDict];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"GroupDetailUpdated" object:dataDict];
  //end
}

-(void)notifyUserSocketConnected:(BOOL)onConnect{
  [[NSNotificationCenter defaultCenter] postNotificationName:@"OnConnectStatus"
                                                      object:[NSNumber numberWithBool:onConnect]];
}
- (void)setUpListeners {
  
  __weak SocketHandler *weakSelf = self;
  
  [_socket on:@"receive" callback:^(NSArray *args) {
    
    if ([args[0][@"flag"] isEqualToString:@"code_verification1"]) {
      
      [[NSNotificationCenter defaultCenter]
       postNotificationName:@"GetCodeResponce" object:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"code_verififcation2"]) {
      
      [[NSNotificationCenter defaultCenter] postNotificationName:@"GetConfirmationResponce" object:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"all_contacts_available"]) {
      
      for (NSDictionary *tempCont in args[0][@"data"])
      {
        if(![DB_Handler existUserFor:tempCont[@"u_id"]])
        {
          [[DB_Handler shared]insertIntoInfoDB:tempCont];
        }
      }
      [[NSNotificationCenter defaultCenter]
       postNotificationName:@"InitializingSuccess" object:nil];
    }
    else if ([args[0][@"flag"] isEqualToString:@"reply_database"]) {
      
      [[NSNotificationCenter defaultCenter]
       postNotificationName:@"RetriveDataBase" object:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"profile_update_res"]) {
      
      [[NSNotificationCenter defaultCenter] postNotificationName:@"ProfileUpdateResponse" object:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"status_reply"]) {
      
      [[NSNotificationCenter defaultCenter]
       postNotificationName:@"SeenStatus" object:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"typing_in_group"]) {
      
      [[NSNotificationCenter defaultCenter]
       postNotificationName:@"GroupTypingStatus" object:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"delivered_report"]) {
      
      [[DB_Handler shared] updateDeliveredStatusOf:args[0][@"user_id"]];
      
      [[NSNotificationCenter defaultCenter]
       postNotificationName:@"DS_StatusReport"object:args[0]];
      
    }
    else if ([args[0][@"flag"] isEqualToString:@"message_seen"]) {
      
      [[DB_Handler shared] updateSeenStatusForUser:args[0][@"user_id"] isRecived:NO];
      [[NSNotificationCenter defaultCenter]
       postNotificationName:@"DS_StatusReport" object:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"video_audio_reply"]) {
      
      [[NSNotificationCenter defaultCenter]
       postNotificationName:@"ReciveCall" object:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"call_histroy"]) {
      
      [[DB_Handler shared]insertLogDB:args[0]];
      [[NSNotificationCenter defaultCenter]
       postNotificationName:@"MissedCall" object:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"reject_call"]) {
      
      [[NSNotificationCenter defaultCenter]
       postNotificationName:@"RejectedCall" object:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"check_if_available"]) {//Done
      NSString *u_id = [NSString stringWithFormat:@"%@",args[0][@"user_id"]];
      NSData *userData = [[NSUserDefaults standardUserDefaults] objectForKey:@"user_login"];
      UserInfo *user = [NSKeyedUnarchiver unarchiveObjectWithData:userData];
      //DoneEnd
      if (![DB_Handler existUserFor:args[0][@"user_id"]] &&
          [args[0][@"status"] isEqualToString:@"true"]   &&
          ![u_id isEqualToString:user.u_id])
      {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
        [dict setObject:args[0][@"u_contact"]     forKey:@"contact"];
        [dict setObject:args[0][@"user_id"]       forKey:@"u_id"];
        [dict setObject:args[0][@"cont_type"]     forKey:@"cont_type"];
        [dict setObject:@"no"                     forKey:@"seen_status"];
        [dict setObject:@"no"                     forKey:@"image_tag"];
        [dict setObject:@"no"                     forKey:@"image_path"];
        [dict setObject:args[0][@"cont_status"]   forKey:@"cont_status"];
        [dict setObject:args[0][@"user_blocked"]  forKey:@"user_blocked"];
        [[DB_Handler shared]insertIntoInfoDB:dict];
      }
      
      [[NSNotificationCenter defaultCenter] postNotificationName:@"GetAvailableResponce" object:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"other_images"])
    { //change of Profile Image
      //            if ([args[0][@"status"] isEqualToString:@"change"])
      //            {
      [[DB_Handler shared]updateImageInfoFor:args[0]];
      //            }
    }
    else if ([args[0][@"flag"] isEqualToString: @"group_created_notification"])
    {
      [self createGroupNotificationWith:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"group_data"])
    {
      NSMutableDictionary *groupMemebers = [[NSMutableDictionary alloc]init];
      [groupMemebers setObject:args[0][@"cw_id"]            forKey:@"group_id"];
      [groupMemebers setObject:args[0][@"group_name"]       forKey:@"group_name"];
      for (NSDictionary *dataDict in args[0][@"data"])
      {
        if (![DB_Handler existUser:dataDict[@"cont_no"] ForGroup:args[0][@"cw_id"]])
        {
          [groupMemebers setObject:dataDict[@"cont_no"]   forKey:@"contact"];
          [groupMemebers setObject:@"demo"                forKey:@"cont_name"];
          [groupMemebers setObject:dataDict[@"role"]      forKey:@"role"];
          [[DB_Handler shared]insertIntoGroupDB:groupMemebers];
        }
      }
      NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
      [dict setObject:args[0][@"cw_id"]                     forKey:@"u_id"];
      [dict setObject:args[0][@"img_tag"]                   forKey:@"image_tag"];
      [dict setObject:args[0][@"image_path"]                forKey:@"image_path"];
      [dict setObject:@"no status"                          forKey:@"cont_status"];
      [[DB_Handler shared]updateImageInfoFor:dict];//group info
    }
    else if ([args[0][@"flag"] isEqualToString:@"group_exit"])
    {
      [[DB_Handler shared] deleteMember:args[0][@"user_no"] fromGroup:args[0][@"group_id"]];
      
      NSArray *contactName =[ContactBook contactNameFor:@[args[0][@"user_no"]]];
      NSString *message =[NSString stringWithFormat:@"%@ exit group",contactName[0]];
      
      [[NSNotificationCenter defaultCenter]
       postNotificationName:@"ContactRemoved"
       object:args[0]];
      
      //insert Notification to Chat DB
      NSData *userData = [[NSUserDefaults standardUserDefaults] objectForKey:@"user_login"];
      UserInfo *user = [NSKeyedUnarchiver unarchiveObjectWithData:userData];
      NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
      [formatter setDateFormat:@"dd MMM hh:mm a"];
      NSString *date = [formatter stringFromDate:[NSDate date]];
      
      NSMutableDictionary *chatDict = [[NSMutableDictionary alloc]init];
      [chatDict setObject:args[0][@"group_name"]    forKey:@"chat_with"];
      [chatDict setObject:args[0][@"group_id"]      forKey:@"cw_id"];
      [chatDict setObject:@"group"                  forKey:@"cw_type"];
      [chatDict setObject:message                   forKey:@"message"];
      [chatDict setObject:@"notification"           forKey:@"data_type"];
      [chatDict setObject:@"notification"           forKey:@"file_name"];
      [chatDict setObject:date                      forKey:@"date_time"];
      [chatDict setObject:args[0][@"group_name"]    forKey:@"group_name"];
      [chatDict setObject:user.u_contact            forKey:@"from"];
      [chatDict setObject:user.u_id                 forKey:@"my_id"];
      [[DB_Handler shared]insertIntoChatDB:chatDict isRecived:YES isSended:YES];
      //end
    }
    else if ([args[0][@"flag"] isEqualToString:@"group_details_update"])
    {
      [self groupDetailUpdatedWith:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"group_delivery_status"])
    {
      BOOL seen =([args[0][@"status"] isEqualToString:@"seen"])?YES:NO;
      [[DB_Handler shared] updateGrpMsgDeliveredStatus:YES seenStatus:seen forInfo:args[0]];
      [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageStatus" object:nil];
    }
    else if ([args[0][@"flag"] isEqualToString:@"you_are_blocked"])
    {
      BOOL userBlocked = [args[0][@"block_st"] boolValue];
      [[DB_Handler shared] updateUserBlockedInfo:userBlocked
                                     byContactID:args[0][@"blocked_from"]];
      //insert ChatMessage to Chat DB
      NSData *userData = [[NSUserDefaults standardUserDefaults] objectForKey:@"user_login"];
      UserInfo *user = [NSKeyedUnarchiver unarchiveObjectWithData:userData];
      NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
      [formatter setDateFormat:@"dd MMM hh:mm a"];
      NSString *date = [formatter stringFromDate:[NSDate date]];
      NSArray *contactName =[ContactBook contactNameFor:@[args[0][@"blocked_from_no"]]];
      NSString *message = [NSString stringWithFormat:@"%@ %@ you ",contactName[0],(userBlocked)?@"blocked":@"unblocked"];
      
      NSMutableDictionary *chatDict = [[NSMutableDictionary alloc]init];
      [chatDict setObject:args[0][@"blocked_from_no"]   forKey:@"chat_with"];
      [chatDict setObject:args[0][@"blocked_from"]      forKey:@"cw_id"];
      [chatDict setObject:@"individual"                 forKey:@"cw_type"];
      [chatDict setObject:message                       forKey:@"message"];
      [chatDict setObject:@"notification"               forKey:@"data_type"];
      [chatDict setObject:@"notification"               forKey:@"file_name"];
      [chatDict setObject:date                          forKey:@"date_time"];
      [chatDict setObject:@"no group"                   forKey:@"group_name"];
      [chatDict setObject:user.u_contact                forKey:@"from"];
      [chatDict setObject:user.u_id                     forKey:@"my_id"];
      [[DB_Handler shared]insertIntoChatDB:chatDict isRecived:YES isSended:YES];
      //end
      
    }
    else if ([args[0][@"flag"] isEqualToString:@"blocked_before_message"])
    {
      [[NSNotificationCenter defaultCenter] postNotificationName:@"YouBlocked" object:args[0]];
    }
    else if ([args[0][@"flag"] isEqualToString:@"receive_message"])
    {
      //insert ChatMessage to Chat DB
      NSMutableDictionary *chatInsertDict = [[NSMutableDictionary alloc]
                                             initWithDictionary:args[0]];
      [chatInsertDict setObject:@(NO)         forKey:@"file_downloaded"];
      [[DB_Handler shared]insertIntoChatDB:chatInsertDict isRecived:YES isSended:YES];
      //end
      
      //Notification to user
      [[NSNotificationCenter defaultCenter] postNotificationName:@"GetMessageResponce" object:args[0]];
      [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageBadge" object:nil];
      //end
      
      //insert ChatList Info DB
      if (![DB_Handler existUserFor:args[0][@"cw_id"]])
      {
        BOOL isGroup =([args[0][@"cw_type"] isEqualToString:@"group"])?YES:NO;
        NSString *contact = (isGroup)?args[0][@"group_name"]:args[0][@"chat_with"];
        NSString *status =(isGroup)?@"no status":args[0][@"cont_status"];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
        [dict setObject:contact                 forKey:@"contact"];
        [dict setObject:args[0][@"cw_id"]       forKey:@"u_id"];
        [dict setObject:args[0][@"cw_type"]     forKey:@"cont_type"];
        [dict setObject:@"no"                   forKey:@"seen_status"];
        [dict setObject:@"no"                   forKey:@"image_tag"];
        [dict setObject:@"no"                   forKey:@"image_path"];
        [dict setObject:status                  forKey:@"cont_status"];
        [dict setObject:@"0"                    forKey:@"user_blocked"];
        [[DB_Handler shared]insertIntoInfoDB:dict];
        
        //send socket for Group details
        if (isGroup)
        {
          NSMutableDictionary *dict = [NSMutableDictionary dictionary];
          [dict setObject:args[0][@"cw_id"]   forKey:@"group_id"];
          [weakSelf.socket emit:@"get_group_data" args:@[dict]];
        }
        //end
      }
      //end
    }
    else{
      NSLog(@"wrong flag recived with data :\n%@",args[0]);
    }
  }];
}

@end







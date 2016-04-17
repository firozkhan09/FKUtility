//
//  DB_Handler.m
//  tawk@Eaze
//
//  Created by Santosh Narawade on 09/10/15.
//  Copyright (c) 2015 Santosh Narawade. All rights reserved.
//

#import "DB_Handler.h"
#import "SocketHandler.h"
#import "UserInfo.h"

#import <UIKit/UIKit.h>

@interface DB_Handler ()

@end

@implementation DB_Handler

+ (instancetype)shared {
  static DB_Handler *dbHandler = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    dbHandler = [[self alloc] init];
  });
  return dbHandler;
}

#pragma mark - CHAT DB handler

+(NSString *)chatDB_path{
  
  NSArray *documentDirectory=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *directoryPath=[documentDirectory objectAtIndex:0];
  NSString *databasePath=[directoryPath stringByAppendingPathComponent:@"chat.db"];
  return databasePath;
}

+(NSArray *)onChatedList{
  
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler chatDB_path];
  NSMutableArray *onChatedArray=[[NSMutableArray alloc]init];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *selectSQL=[NSString stringWithFormat:@"SELECT DISTINCT cw_id,cw_type from chat_table  order by c_id desc"];
    
    const char *select_stmt=[selectSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(talkDB, select_stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW){
      
      NSMutableDictionary *onChatDict = [[NSMutableDictionary alloc]init];
      NSString *user_id=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
      NSString *cw_type=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
      
      NSString *chat_withSQL=[NSString stringWithFormat:@"SELECT DISTINCT chat_with from chat_table where cw_id=\"%@\" ",user_id];
      NSString *group_nameSQL=[NSString stringWithFormat:@"SELECT DISTINCT group_name from chat_table where cw_id=\"%@\" ",user_id];
      const char *contact_stmt=[([cw_type isEqualToString:@"group"])?group_nameSQL:chat_withSQL UTF8String];
      sqlite3_stmt *contact_statement;
      int i = 1;
      NSString *count = @"0";
      NSString *contact = @"me";
      NSString *group_name = @"no group";
      
      sqlite3_prepare_v2(talkDB, contact_stmt, -1, &contact_statement, NULL);
      while(sqlite3_step(contact_statement)==SQLITE_ROW){
        
        NSString *outputStr=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(contact_statement, 0)];
        
        if ([cw_type isEqualToString:@"group"]) group_name = outputStr;
        else contact = outputStr;
        
        NSString *statusSQL = [NSString stringWithFormat:@"SELECT is_seen from chat_table where cw_id=\"%@\" and is_seen=\"0\" and is_recived=\"1\" ",user_id];
        const char *status_stmt=[statusSQL UTF8String];
        sqlite3_stmt *status_statement;
        
        sqlite3_prepare_v2(talkDB, status_stmt, -1, &status_statement, NULL);
        while(sqlite3_step(status_statement)==SQLITE_ROW){
          
          count = [NSString stringWithFormat:@"%d",i++];
          
        }
      }
      
      [onChatDict setObject:contact forKey:@"Phone"];
      [onChatDict setObject:group_name forKey:@"group_name"];
      [onChatDict setObject:user_id forKey:@"cw_id"];
      [onChatDict setObject:cw_type forKey:@"cw_type"];
      [onChatDict setObject:count forKey:@"unreaded"];
      [onChatedArray addObject:onChatDict];
    }
    sqlite3_finalize(statement);
    
  }
  sqlite3_close(talkDB);
  
  return onChatedArray;
}

+(int)unseenMessageFor:(NSString *)cw_id{
  
  NSString *count = @"0";
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler chatDB_path];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *statusSQL = [NSString stringWithFormat:@"SELECT is_seen from chat_table where cw_id=\"%@\" and is_seen=\"0\" and is_recived=\"1\" ",cw_id];
    const char *status_stmt=[statusSQL UTF8String];
    sqlite3_stmt *status_statement;
    int i = 1;
    sqlite3_prepare_v2(talkDB, status_stmt, -1, &status_statement, NULL);
    while(sqlite3_step(status_statement)==SQLITE_ROW){
      count = [NSString stringWithFormat:@"%d",i++];
    }
    sqlite3_finalize(status_statement);
  }
  sqlite3_close(talkDB);
  
  return [count intValue];
}

+(int)numberOfUsersWithUnseenMessage{
  NSString *count = @"0";
  int i =1;
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler chatDB_path];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *selectSQL=[NSString stringWithFormat:@"SELECT DISTINCT cw_id,cw_type from chat_table  order by c_id desc"];
    
    const char *select_stmt=[selectSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(talkDB, select_stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW){
      
      NSString *user_id=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
      count = ([DB_Handler unseenMessageFor:user_id]>0)?[NSString stringWithFormat:@"%d",i++]:count;
    }
    sqlite3_finalize(statement);
    
  }
  sqlite3_close(talkDB);
  return [count intValue];
}

+(void)sendPendingMessages{
  
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler chatDB_path];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *statusSQL = [NSString stringWithFormat:@"SELECT chat_with, cw_id, cw_type, chat, data_type, file_name, sender_date_time, group_name from chat_table where is_seen=\"0\" and is_recived=\"0\" "];
    const char *stmt=[statusSQL UTF8String];
    sqlite3_stmt *statement;
    
    NSData *userData = [[NSUserDefaults standardUserDefaults] objectForKey:@"user_login"];
    UserInfo *user = [NSKeyedUnarchiver unarchiveObjectWithData:userData];
    
    sqlite3_prepare_v2(talkDB, stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW){
      
      NSMutableDictionary *chatDict = [[NSMutableDictionary alloc]init];
      NSString *contact=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
      NSString *cw_id=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
      NSString *cw_type=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 2)];
      NSString *message=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 3)];
      NSString *data_type=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 4)];
      NSString *file_name=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 5)];
      NSString *sender_date_time=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 6)];
      NSString *group_name=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 7)];
      
      [chatDict setObject:contact             forKey:@"chat_with"];
      [chatDict setObject:cw_id               forKey:@"cw_id"];
      [chatDict setObject:cw_type             forKey:@"cw_type"];
      [chatDict setObject:message             forKey:@"message"];
      [chatDict setObject:data_type           forKey:@"data_type"];
      [chatDict setObject:file_name           forKey:@"file_name"];
      [chatDict setObject:sender_date_time    forKey:@"date_time"];
      [chatDict setObject:group_name          forKey:@"group_name"];
      [chatDict setObject:user.u_contact      forKey:@"from"];
      [chatDict setObject:user.u_id           forKey:@"my_id"];
      
      NSString *eventStr = ([cw_type isEqualToString:@"group"])?
      @"group_message":@"send_message";
      //emit to node
      [[SocketHandler shared] setUpEmit_on:eventStr message:@[chatDict]];
      //end
      
    }
    sqlite3_finalize(statement);
  }
  sqlite3_close(talkDB);
}

//+(NSArray *)getChatMessagesFrom:(NSString *)cw_id limit:(NSUInteger)limit{
+(NSArray *)getChatMessagesFrom:(NSString *)cw_id{
  
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler chatDB_path];
  NSMutableArray *chatArray=[[NSMutableArray alloc]init];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *selectSQL=[NSString stringWithFormat:@"SELECT chat, is_recived, is_seen, is_delivered, is_sended, data_type, file_name, file_downloaded, chat_with, ph_image, my_date_time, c_id, file_underProgress from chat_table where cw_id=\"%@\"",cw_id];// order by c_id desc limit \"%d\"",cw_id,(int)limit]
    
    const char *select_stmt=[selectSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(talkDB, select_stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW){
      
      NSMutableDictionary *chatDict = [[NSMutableDictionary alloc]init];
      NSString *message=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
      NSString *recived_status=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
      NSString *seen_status=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 2)];
      NSString *is_delivered=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 3)];
      NSString *is_sended=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 4)];
      NSString *data_type=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 5)];
      NSString *file_name=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 6)];
      NSString *file_downloaded=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 7)];
      NSString *chat_with=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 8)];
      NSString *PHI_path=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 9)];
      NSString *my_date_time=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 10)];
      NSString *msg_id=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 11)];
      NSString *is_progressing=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 12)];
      
      [chatDict setObject:msg_id          forKey:@"msg_id"];
      [chatDict setObject:message         forKey:@"message"];
      [chatDict setObject:recived_status  forKey:@"recived_status"];
      [chatDict setObject:seen_status     forKey:@"seen_status"];
      [chatDict setObject:is_delivered    forKey:@"is_delivered"];
      [chatDict setObject:is_sended       forKey:@"is_sended"];
      [chatDict setObject:data_type       forKey:@"data_type"];
      [chatDict setObject:file_name       forKey:@"file_name"];
      [chatDict setObject:file_downloaded forKey:@"file_downloaded"];
      [chatDict setObject:is_progressing  forKey:@"is_progressing"];
      [chatDict setObject:chat_with       forKey:@"chat_with"];
      [chatDict setObject:PHI_path        forKey:@"PHI_path"];
      [chatDict setObject:my_date_time    forKey:@"date_time"];
      [chatArray addObject:chatDict];
    }
    sqlite3_finalize(statement);
  }
  sqlite3_close(talkDB);  
  return chatArray;//[[chatArray reverseObjectEnumerator] allObjects];
}

-(void)createChatDataBaseAt:(NSString *)path{
  
  NSFileManager *fileManager=[NSFileManager defaultManager];
  if([fileManager fileExistsAtPath:path]==NO && sqlite3_open([path UTF8String], &_talkDB)==SQLITE_OK){
    
    char *error;
    const char *create_stmt="create table if not exists chat_table (c_id INTEGER PRIMARY KEY   AUTOINCREMENT,chat_with VARCHAR,cw_id VARCHAR,cw_type VARCHAR, chat longtext, is_seen INTEGER, is_recived INTEGER, is_delivered INTEGER, is_sended INTEGER, sender_date_time VARCHAR, my_date_time VARCHAR, data_type VARCHAR, file_name VARCHAR, group_name VARCHAR, file_downloaded INTEGER, file_underProgress INTEGER, ph_image VARCHAR)";
    sqlite3_exec(_talkDB, create_stmt, NULL, NULL, &error);
    sqlite3_close(_talkDB);
  }
}

-(NSString *)insertIntoChatDB:(NSDictionary *)chatDict isRecived:(BOOL)recive_status isSended:(BOOL)send_status
{
  NSString *msgID;
  BOOL isSeen = ([chatDict[@"data_type"] isEqualToString:@"notification"])?YES:NO;
  NSString *DB_path = [DB_Handler chatDB_path];
  NSString *message = [chatDict[@"message"] stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"dd MMM hh:mm a"];
    NSString *my_date_time =[formatter stringFromDate:[NSDate date]];
    
    NSString *insertSQL=[NSString stringWithFormat:@"insert into chat_table (chat_with, cw_id, cw_type, chat, is_seen, is_recived, is_delivered, is_sended, sender_date_time, my_date_time, data_type, file_name, group_name, file_downloaded, file_underProgress, ph_image) values (\"%@\",\"%@\",\"%@\",\"%@\",\"%d\",\"%d\",\"0\",\"%d\",\"%@\",\"%@\",\"%@\",\"%@\",\"%@\",\"%@\",\"0\",\"no image\")", chatDict[@"chat_with"], chatDict[@"cw_id"], chatDict[@"cw_type"], message, (int)isSeen, (int)recive_status, (int)send_status, chatDict[@"date_time"], my_date_time, chatDict[@"data_type"], chatDict[@"file_name"], chatDict[@"group_name"], chatDict[@"file_downloaded"]];
    
    const char *insert_stmt=[insertSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, insert_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *insertAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Something goes wrong to saved data" delegate:nil cancelButtonTitle:@"close" otherButtonTitles:nil];
      [insertAlertView show];
    }
    msgID= [NSString stringWithFormat:@"%lld",sqlite3_last_insert_rowid(_talkDB)];
    sqlite3_finalize(statement);
    
  }
  sqlite3_close(_talkDB);
  return msgID;
}

-(void)updateSeenStatusForUser:(NSString *)cw_id isRecived:(BOOL)recived{
  
  NSString *DB_path = [DB_Handler chatDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *updateSQL=[NSString stringWithFormat:@"update chat_table set is_seen=\"1\" where cw_id=\"%@\" and is_recived=\"%d\" ",cw_id,(int)recived];
    const char *update_stmt=[updateSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, update_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *updateAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Unable to update Data" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
      [updateAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}

-(void)updateDeliveredStatusOf:(NSString *)cw_id{
  
  NSString *DB_path = [DB_Handler chatDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *updateSQL=[NSString stringWithFormat:@"update chat_table set is_delivered=\"1\" where cw_id=\"%@\" and is_recived=\"0\" ",cw_id];
    const char *update_stmt=[updateSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, update_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *updateAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Unable to update Data" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
      [updateAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}

-(void)updateSendedStatusOf:(NSString *)cw_id{
  
  NSString *DB_path = [DB_Handler chatDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *updateSQL=[NSString stringWithFormat:@"update chat_table set is_sended=\"1\" where cw_id=\"%@\" and is_recived=\"0\" ",cw_id];
    const char *update_stmt=[updateSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, update_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *updateAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Unable to update Data" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
      [updateAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}

-(void)updateFileProgressStatusTo:(BOOL)underProgress withError:(NSError *)error forURL:(NSString *)chatURL{
  
  NSString *DB_path = [DB_Handler chatDB_path];
  BOOL isDownloaded = (underProgress || error)?NO:YES;
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *updateSQL=[NSString stringWithFormat:@"update chat_table set file_underProgress=\"%d\" where file_downloaded=\"%d\" and chat=\"%@\"",(int)underProgress, isDownloaded,chatURL];
    const char *update_stmt=[updateSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, update_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *updateAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Unable to update Progress status" delegate:nil cancelButtonTitle:@"Retry" otherButtonTitles:nil];
      [updateAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}

-(void)updateFileProgressStatusForVideoType:(BOOL)videoType{
  
  NSString *DB_path = [DB_Handler chatDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *updateSQL=(videoType)?
    [NSString stringWithFormat:@"update chat_table set file_underProgress=\"%d\" where data_type=\"video\" and is_recived=\"%d\"",(int)NO,(int)YES]:
    [NSString stringWithFormat:@"update chat_table set file_underProgress=\"%d\"",(int)NO];
    const char *update_stmt=[updateSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, update_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *updateAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Unable to update Progress status" delegate:nil cancelButtonTitle:@"Retry" otherButtonTitles:nil];
      [updateAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}

-(void)updateDownloadStatusOf:(NSString *)downloaded_url withNewPath:(NSString *)newPath{
  
  NSString *DB_path = [DB_Handler chatDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    NSString *fileName = [downloaded_url componentsSeparatedByString:@"/"].lastObject;
    NSString *updateSQL=[NSString stringWithFormat:@"update chat_table set file_downloaded=\"1\", file_name=\"%@\", chat=\"%@\" where chat=\"%@\"",fileName ,newPath ,downloaded_url];
    const char *update_stmt=[updateSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, update_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *updateAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Unable to update Data" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
      [updateAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}

-(void)updatePHIOfVideoURL:(NSString *)video_url withPath:(NSString *)PHI_path{
  
  NSString *DB_path = [DB_Handler chatDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *updateSQL=[NSString stringWithFormat:@"update chat_table set ph_image=\"%@\" where chat=\"%@\"",PHI_path,video_url];
    const char *update_stmt=[updateSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, update_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *updateAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Unable to update PHI" delegate:nil cancelButtonTitle:@"Retry" otherButtonTitles:nil];
      [updateAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}

-(void)deleteMessage:(NSDictionary *)object forUser:(NSString *)cw_id{
  
  NSString *DB_path = [DB_Handler chatDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    NSString *deleteSQL=[NSString stringWithFormat:@"delete from chat_table where cw_id=\"%@\" and chat=\"%@\" and is_recived=\"%@\" and chat_with=\"%@\" and file_underProgress=\"%@\" ",cw_id ,object[@"message"] ,object[@"recived_status"] ,object[@"chat_with"],object[@"is_progressing"]];
    const char *delete_stmt=[deleteSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, delete_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)==SQLITE_DONE){
      
    }
    else{
      UIAlertView *deleteAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"something goes wrong to delete the message" delegate:self cancelButtonTitle:@"close" otherButtonTitles:nil];
      [deleteAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}

-(void)deleteChatFromUser:(NSString *)cw_id{
  
  NSString *DB_path = [DB_Handler chatDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    NSString *deleteSQL=[NSString stringWithFormat:@"delete from chat_table where cw_id=\"%@\" ",cw_id];
    const char *delete_stmt=[deleteSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, delete_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)==SQLITE_DONE){
      
    }
    else{
      UIAlertView *deleteAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"something goes wrong to delete the message" delegate:self cancelButtonTitle:@"close" otherButtonTitles:nil];
      [deleteAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}

#pragma mark - INFO DB handler

+(NSString *)infoDB_path{
  
  NSArray *documentDirectory=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *directoryPath=[documentDirectory objectAtIndex:0];
  NSString *databasePath=[directoryPath stringByAppendingPathComponent:@"info.db"];
  return databasePath;
}

+(NSArray *)getAllContactInfo{
  
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler infoDB_path];
  NSMutableArray *chatArray=[[NSMutableArray alloc]init];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *selectSQL=[NSString stringWithFormat:@"SELECT cont_info, cont_id, cont_img_tag, cont_img_path, cont_type, cont_status from info_table"];
    
    const char *select_stmt=[selectSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(talkDB, select_stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW){
      
      NSMutableDictionary *chatDict = [[NSMutableDictionary alloc]init];
      NSString *contact=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
      NSString *cont_id=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
      NSString *image_tag=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 2)];
      NSString *image_path=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 3)];
      NSString *cont_type=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 4)];
      NSString *cont_status=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 5)];
      
      [chatDict setObject:contact         forKey:@"contact"];
      [chatDict setObject:cont_id         forKey:@"cont_id"];
      [chatDict setObject:image_tag       forKey:@"image_tag"];
      [chatDict setObject:image_path      forKey:@"image_path"];
      [chatDict setObject:cont_type       forKey:@"cont_type"];
      [chatDict setObject:cont_status     forKey:@"cont_status"];
      
      [chatArray addObject:chatDict];
    }
    sqlite3_finalize(statement);
    
  }
  sqlite3_close(talkDB);
  
  return chatArray;
}

+(NSDictionary *)getInfoForContactID:(NSString *)cont_id{
  
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler infoDB_path];
  NSMutableDictionary *infoDict = [[NSMutableDictionary alloc]init];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *selectSQL=[NSString stringWithFormat:@"SELECT cont_status, isBlocked, user_blocked from info_table where cont_id=\"%@\"",cont_id];
    
    const char *select_stmt=[selectSQL UTF8String];
    sqlite3_stmt *statement;
    sqlite3_prepare_v2(talkDB, select_stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW)
    {
      NSString *cont_status=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
      NSString *isBlocked=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
      NSString *user_blocked=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 2)];
      
      [infoDict setObject:cont_status     forKey:@"cont_status"];
      [infoDict setObject:isBlocked       forKey:@"isBlocked"];
      [infoDict setObject:user_blocked    forKey:@"user_blocked"];
    }
    sqlite3_finalize(statement);
  }
  sqlite3_close(talkDB);
  return infoDict;
}

+(BOOL)existUserFor:(NSString *)user_id{
  BOOL exist = NO;
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler infoDB_path];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *selectSQL=[NSString stringWithFormat:@"SELECT cont_info from info_table where cont_id=\"%@\"",user_id];
    
    const char *select_stmt=[selectSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(talkDB, select_stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW){
      
      exist =  YES;
    }
    sqlite3_finalize(statement);
  }
  sqlite3_close(talkDB);
  
  return exist;
}

+(NSString *)getImageUrlForContact:(NSString *)contact{
  NSString * imagePath;
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler infoDB_path];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *selectSQL=[NSString stringWithFormat:@"SELECT cont_img_path from info_table where cont_info=\"%@\"",contact];
    
    const char *select_stmt=[selectSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(talkDB, select_stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW){
      imagePath = [[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
    }
    sqlite3_finalize(statement);
  }
  sqlite3_close(talkDB);
  
  return (imagePath)?imagePath:@"noImage";
}

+(NSString *)getImageUrlForID:(NSString *)cont_id{
  NSString * imagePath;
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler infoDB_path];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *selectSQL=[NSString stringWithFormat:@"SELECT cont_img_path from info_table where cont_id=\"%@\"",cont_id];
    
    const char *select_stmt=[selectSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(talkDB, select_stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW){
      imagePath = [[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
    }
    sqlite3_finalize(statement);
  }
  sqlite3_close(talkDB);
  
  return (imagePath)?imagePath:@"noImage";
}

-(void)createInfoDataBaseAt:(NSString *)path{
  
  NSFileManager *fileManager=[NSFileManager defaultManager];
  if([fileManager fileExistsAtPath:path]==NO && sqlite3_open([path UTF8String], &_talkDB)==SQLITE_OK){
    
    char *error;
    const char *create_stmt="create table if not exists info_table (info_id INTEGER PRIMARY KEY   AUTOINCREMENT,cont_info VARCHAR, cont_id VARCHAR, cont_img_tag VARCHAR, cont_img_path VARCHAR, seen_status VARCHAR, cont_type VARCHAR, cont_status VARCHAR, isBlocked INTEGER, user_blocked INTEGER)";
    sqlite3_exec(_talkDB, create_stmt, NULL, NULL, &error);
    sqlite3_close(_talkDB);
  }
}

-(void)insertIntoInfoDB:(NSDictionary *)infoDict{
  
//  NSLog(@"\nUserID: %@",infoDict[@"u_id"]);
//  NSString *u_id = [NSString stringWithFormat:@"%@",infoDict[@"u_id"]];
//  if ([u_id isEqualToString:@"37"]) {
//    return;
//  }
  NSString *DB_path = [DB_Handler infoDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *insertSQL=[NSString stringWithFormat:@"insert into info_table (cont_info,cont_id,cont_img_tag,cont_img_path,seen_status,cont_type,cont_status,isBlocked,user_blocked) values (\"%@\",\"%@\",\"%@\",\"%@\",\"%@\",\"%@\",\"%@\",\"%d\",\"%d\")",infoDict[@"contact"], infoDict[@"u_id"], infoDict[@"image_tag"], infoDict[@"image_path"], infoDict[@"seen_status"], infoDict[@"cont_type"], infoDict[@"cont_status"], (int) NO, (int)[infoDict[@"user_blocked"] boolValue]];
    
    const char *insert_stmt=[insertSQL UTF8String];
    sqlite3_stmt *statement;
    sqlite3_prepare_v2(_talkDB, insert_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE)
    {
      UIAlertView *insertAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Something goes wrong to saved info" delegate:nil cancelButtonTitle:@"close" otherButtonTitles:nil];
      [insertAlertView show];
    }
    sqlite3_finalize(statement);
  }
  sqlite3_close(_talkDB);
}

-(void)updateImageInfoFor:(NSDictionary *)infoDict{
  
  NSString *DB_path = [DB_Handler infoDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    NSString *updateSQL=[NSString stringWithFormat:@"update info_table set cont_img_tag=\"%@\",cont_img_path=\"%@\",seen_status=\"%@\", cont_status=\"%@\"where cont_id=\"%@\"",infoDict[@"image_tag"],infoDict[@"image_path"],infoDict[@"seen_status"],infoDict[@"cont_status"],infoDict[@"u_id"]];
    const char *update_stmt=[updateSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, update_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *updateAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Unable to update Info" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
      [updateAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}

-(void)updateContactBlockedInfo:(BOOL)isBlocked forContactID:(NSString *)cont_id{
  
  NSString *DB_path = [DB_Handler infoDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *updateSQL=[NSString stringWithFormat:@"update info_table set isBlocked=\"%d\" where cont_id=\"%@\"",(int)isBlocked,cont_id];
    const char *update_stmt=[updateSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, update_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *updateAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Unable to update Info" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
      [updateAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}

-(void)updateUserBlockedInfo:(BOOL)userBlocked byContactID:(NSString *)cont_id{
  
  NSString *DB_path = [DB_Handler infoDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *updateSQL=[NSString stringWithFormat:@"update info_table set user_blocked=\"%d\" where cont_id=\"%@\"",(int)userBlocked,cont_id];
    const char *update_stmt=[updateSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, update_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *updateAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Unable to update Info" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
      [updateAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}
#pragma mark - Group DB handler

+(NSString *)groupDB_path{
  
  NSArray *documentDirectory=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *directoryPath=[documentDirectory objectAtIndex:0];
  NSString *databasePath=[directoryPath stringByAppendingPathComponent:@"group.db"];
  return databasePath;
}

+(NSArray *)getGroupiesFor:(NSString *)group_id{
  
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler groupDB_path];
  NSMutableArray *groupiesArray=[[NSMutableArray alloc]init];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *selectSQL=[NSString stringWithFormat:@"SELECT grp_name,grp_cont,grp_cont_name,grp_role from group_data_table where grp_id=\"%@\"",group_id];
    
    const char *select_stmt=[selectSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(talkDB, select_stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW){
      
      NSMutableDictionary *chatDict = [[NSMutableDictionary alloc]init];
      NSString *name=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
      NSString *cont=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
      NSString *cont_name=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 2)];
      NSString *role=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 3)];
      
      [chatDict setObject:name        forKey:@"name"];
      [chatDict setObject:cont        forKey:@"cont"];
      [chatDict setObject:cont_name   forKey:@"cont_name"];
      [chatDict setObject:role        forKey:@"role"];
      [groupiesArray addObject:chatDict];
    }
    sqlite3_finalize(statement);
    
  }
  sqlite3_close(talkDB);
  
  return groupiesArray;
}

+(NSArray *)getMessageInfoForGroup:(NSString *)grp_id{
  
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler groupDB_path];
  NSMutableArray *msgInfoArray=[[NSMutableArray alloc]init];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *selectSQL=[NSString stringWithFormat:@"SELECT grp_cont, grp_msg_id, is_delivered, is_sended from group_data_table where grp_id=\"%@\"",grp_id];
    
    const char *select_stmt=[selectSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(talkDB, select_stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW){
      
      NSMutableDictionary *chatDict = [[NSMutableDictionary alloc]init];
      NSString *contact=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
      NSString *msg_id=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
      NSString *delivered=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 2)];
      NSString *seen=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 3)];
      
      [chatDict setObject:contact     forKey:@"contact"];
      [chatDict setObject:msg_id      forKey:@"msg_id"];
      [chatDict setObject:delivered   forKey:@"delivered"];
      [chatDict setObject:seen        forKey:@"seen"];
      [msgInfoArray addObject:chatDict];
    }
    sqlite3_finalize(statement);
    
  }
  sqlite3_close(talkDB);
  
  return msgInfoArray;
}

+(BOOL)existUser:(NSString *)user_cont ForGroup:(NSString *)group_id{
  BOOL exist = NO;
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler groupDB_path];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *selectSQL=[NSString stringWithFormat:@"SELECT gd_id from group_data_table where grp_cont=\"%@\" and grp_id=\"%@\"",user_cont,group_id];
    
    const char *select_stmt=[selectSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(talkDB, select_stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW){
      
      exist =  YES;
    }
    sqlite3_finalize(statement);
  }
  sqlite3_close(talkDB);
  
  return exist;
}

+(NSArray *)getGroupDetailWithContact:(NSString *)contact{
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler groupDB_path];
  NSMutableArray *groupListArray=[[NSMutableArray alloc]init];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *selectSQL=[NSString stringWithFormat:@"SELECT grp_name,grp_role,grp_id from group_data_table where grp_cont=\"%@\"",contact];
    
    const char *select_stmt=[selectSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(talkDB, select_stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW){
      
      NSMutableDictionary *detailDict = [[NSMutableDictionary alloc]init];
      NSString *grp_name=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
      NSString *grp_role=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
      NSString *grp_id=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 2)];
      NSArray *groupies=[DB_Handler getGroupiesFor:grp_id];
      NSString *imagePath = [DB_Handler getImageUrlForID:grp_id];
      
      [detailDict setObject:grp_name      forKey:@"grp_name"];
      [detailDict setObject:grp_role      forKey:@"grp_role"];
      [detailDict setObject:grp_id        forKey:@"grp_id"];
      [detailDict setObject:groupies      forKey:@"groupies"];
      [detailDict setObject:imagePath     forKey:@"imagePath"];
      [groupListArray addObject:detailDict];
    }
    sqlite3_finalize(statement);
    
  }
  sqlite3_close(talkDB);
  
  return groupListArray;
}

-(void)createGroupDataBaseAt:(NSString *)path{
  
  NSFileManager *fileManager=[NSFileManager defaultManager];
  if([fileManager fileExistsAtPath:path]==NO && sqlite3_open([path UTF8String], &_talkDB)==SQLITE_OK){
    
    char *error;
    const char *create_stmt="create table if not exists group_data_table (gd_id INTEGER PRIMARY KEY AUTOINCREMENT,grp_name VARCHAR, grp_id VARCHAR, grp_cont VARCHAR, grp_cont_name VARCHAR, grp_role VARCHAR, grp_msg_id VARCHAR, is_delivered INTEGER, is_sended INTEGER)";
    sqlite3_exec(_talkDB, create_stmt, NULL, NULL, &error);
    sqlite3_close(_talkDB);
  }
}

-(void)insertIntoGroupDB:(NSDictionary *)groupDict{
  
  NSString *DB_path = [DB_Handler groupDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *insertSQL=[NSString stringWithFormat:@"insert into group_data_table (grp_name, grp_id, grp_cont, grp_cont_name, grp_role, grp_msg_id, is_delivered, is_sended) values (\"%@\",\"%@\",\"%@\",\"%@\",\"%@\",\"0\",\"%d\",\"%d\")",groupDict[@"group_name"], groupDict[@"group_id"], groupDict[@"contact"], groupDict[@"cont_name"], groupDict[@"role"], (int)NO, (int)NO];
    
    const char *insert_stmt=[insertSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, insert_stmt, -1, &statement, NULL);
    
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *insertAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Something goes wrong to saved info" delegate:nil cancelButtonTitle:@"close" otherButtonTitles:nil];
      [insertAlertView show];
    }
    sqlite3_finalize(statement);
    
  }
  sqlite3_close(_talkDB);
}

-(void)updateGrpMsgDeliveredStatus:(BOOL)delivered seenStatus:(BOOL)seen forInfo:(NSDictionary *)infoDict
{
  NSString *GDB_path = [DB_Handler groupDB_path];
  if(sqlite3_open([GDB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *updateSQL=[NSString stringWithFormat:@"update group_data_table set grp_msg_id=\"%@\",is_delivered=\"%d\",is_sended=\"%d\" where grp_id=\"%@\" and grp_cont=\"%@\"", infoDict[@"delivered_msg_id"], (int)delivered,(int)seen, infoDict[@"delivered_group"],infoDict[@"delivered_to"]];
    const char *update_stmt=[updateSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, update_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *updateAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Unable to update delivered/seen status in Group_DB" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
      [updateAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}
-(void)updateGroupNameOf:(NSString *)grp_id withName:(NSString *)grp_name{
  
  NSString *GDB_path = [DB_Handler groupDB_path];
  if(sqlite3_open([GDB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *updateSQL=[NSString stringWithFormat:@"update group_data_table set grp_name=\"%@\" where grp_id=\"%@\"",grp_name ,grp_id];
    const char *update_stmt=[updateSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, update_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *updateAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Unable to update group name in Group_DB" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
      [updateAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
  
  NSString *CDB_path = [DB_Handler chatDB_path];
  if(sqlite3_open([CDB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *updateSQL=[NSString stringWithFormat:@"update chat_table set group_name=\"%@\" where cw_id=\"%@\"",grp_name ,grp_id];
    const char *update_stmt=[updateSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, update_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *updateAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Unable to update group name in Chat_DB" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
      [updateAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
  
}

-(void)deleteMember:(NSString *)contact fromGroup:(NSString *)grp_id{
  
  NSString *DB_path = [DB_Handler groupDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    NSString *deleteSQL=[NSString stringWithFormat:@"delete from group_data_table where grp_id=\"%@\" and grp_cont=\"%@\"",grp_id ,contact];
    const char *delete_stmt=[deleteSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, delete_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      
      UIAlertView *deleteAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"something goes wrong to delete the Contact from Group" delegate:self cancelButtonTitle:@"close" otherButtonTitles:nil];
      [deleteAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}

#pragma mark - Log DB handler

+(NSString *)logDB_path{
  
  NSArray *documentDirectory=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *directoryPath=[documentDirectory objectAtIndex:0];
  NSString *databasePath=[directoryPath stringByAppendingPathComponent:@"log.db"];
  return databasePath;
}

+(NSArray *)getCallLog{
  
  sqlite3 *talkDB;
  NSString *DB_path = [DB_Handler logDB_path];
  NSMutableArray *logArray=[[NSMutableArray alloc]init];
  if(sqlite3_open([DB_path UTF8String], &talkDB)==SQLITE_OK){
    
    NSString *selectSQL=[NSString stringWithFormat:@"SELECT caller_cont, caller_id, log_time, log_type, call_type from log_table order by log_id desc"];
    
    const char *select_stmt=[selectSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(talkDB, select_stmt, -1, &statement, NULL);
    while(sqlite3_step(statement)==SQLITE_ROW){
      
      NSMutableDictionary *chatDict = [[NSMutableDictionary alloc]init];
      NSString *cont=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
      NSString *cont_id=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
      NSString *log_time=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 2)];
      NSString *log_type=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 3)];
      NSString *call_type=[[NSString alloc]initWithUTF8String:(const char *)sqlite3_column_text(statement, 4)];
      
      [chatDict setObject:cont        forKey:@"contact"];
      [chatDict setObject:cont_id     forKey:@"cont_id"];
      [chatDict setObject:log_time    forKey:@"log_time"];
      [chatDict setObject:log_type    forKey:@"log_type"];
      [chatDict setObject:call_type   forKey:@"call_type"];
      [logArray addObject:chatDict];
    }
    sqlite3_finalize(statement);
    
  }
  sqlite3_close(talkDB);
  
  return logArray;
}

-(void)createLogDataBaseAt:(NSString *)path{
  
  NSFileManager *fileManager=[NSFileManager defaultManager];
  if([fileManager fileExistsAtPath:path]==NO && sqlite3_open([path UTF8String], &_talkDB)==SQLITE_OK){
    
    char *error;
    const char *create_stmt="create table if not exists log_table (log_id INTEGER PRIMARY KEY   AUTOINCREMENT,caller_cont VARCHAR, caller_id VARCHAR, call_type VARCHAR, log_time VARCHAR, log_type VARCHAR )";
    sqlite3_exec(_talkDB, create_stmt, NULL, NULL, &error);
    sqlite3_close(_talkDB);
  }
}

-(void)insertLogDB:(NSDictionary *)logDict{
  
  NSString *DB_path = [DB_Handler logDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    
    NSString *insertSQL=[NSString stringWithFormat:@"insert into log_table (caller_cont, caller_id, call_type, log_time, log_type) values (\"%@\",\"%@\",\"%@\",\"%@\",\"%@\")",logDict[@"contact"], logDict[@"cont_id"], logDict[@"call_type"], logDict[@"log_time"], logDict[@"log_type"]];
    
    const char *insert_stmt=[insertSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, insert_stmt, -1, &statement, NULL);
    
    if(sqlite3_step(statement)!=SQLITE_DONE){
      UIAlertView *insertAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"Something goes wrong to saved info" delegate:nil cancelButtonTitle:@"close" otherButtonTitles:nil];
      [insertAlertView show];
    }
    sqlite3_finalize(statement);
    
  }
  sqlite3_close(_talkDB);
}

-(void)deleteLog:(NSDictionary *)deleteDict{
  
  NSString *DB_path = [DB_Handler logDB_path];
  if(sqlite3_open([DB_path UTF8String], &_talkDB)==SQLITE_OK){
    NSString *deleteSQL=[NSString stringWithFormat:@"delete from log_table where caller_cont=\"%@\" and caller_id=\"%@\" and log_time=\"%@\" and log_type=\"%@\" and call_type=\"%@\"", deleteDict[@"contact"], deleteDict[@"cont_id"], deleteDict[@"log_time"], deleteDict[@"log_type"], deleteDict[@"call_type"]];
    const char *delete_stmt=[deleteSQL UTF8String];
    sqlite3_stmt *statement;
    
    sqlite3_prepare_v2(_talkDB, delete_stmt, -1, &statement, NULL);
    if(sqlite3_step(statement)!=SQLITE_DONE){
      
      UIAlertView *deleteAlertView=[[UIAlertView alloc]initWithTitle:@"message" message:@"something goes wrong to delete the call log" delegate:self cancelButtonTitle:@"close" otherButtonTitles:nil];
      [deleteAlertView show];
    }
    sqlite3_finalize(statement);
    sqlite3_close(_talkDB);
  }
}
@end






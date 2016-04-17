//
//  DB_Handler.h
//  tawk@Eaze
//
//  Created by Santosh Narawade on 09/10/15.
//  Copyright (c) 2015 Santosh Narawade. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@interface DB_Handler : NSObject

@property(nonatomic)sqlite3 *talkDB;

+ (instancetype)shared;

#pragma mark - Chat DB methods
+(NSString *)chatDB_path;
+(NSArray *)onChatedList;
+(int)numberOfUsersWithUnseenMessage;
+(int)unseenMessageFor:(NSString *)cw_id;
+(void)sendPendingMessages;
+(NSArray *)getChatMessagesFrom:(NSString *)cw_id;// limit:(NSUInteger)limit;

-(void)createChatDataBaseAt:(NSString *)path;
-(NSString *)insertIntoChatDB:(NSDictionary *)chatDict isRecived:(BOOL)recive_status isSended:(BOOL)send_status;
-(void)updateSeenStatusForUser:(NSString *)cw_id isRecived:(BOOL)recived;
-(void)updateDeliveredStatusOf:(NSString *)cw_id;
-(void)updateSendedStatusOf:(NSString *)cw_id;
-(void)updateFileProgressStatusForVideoType:(BOOL)videoType;
-(void)updateFileProgressStatusTo:(BOOL)underProgress withError:(NSError *)error forURL:(NSString *)chatURL;
-(void)updateDownloadStatusOf:(NSString *)downloaded_url withNewPath:(NSString *)newPath;
-(void)updatePHIOfVideoURL:(NSString *)video_url withPath:(NSString *)PHI_path;
-(void)deleteMessage:(NSDictionary *)object forUser:(NSString *)cw_id;
-(void)deleteChatFromUser:(NSString *)cw_id;


#pragma mark - Info DB methods
+(NSString *)infoDB_path;
+(NSArray *)getAllContactInfo;
+(NSDictionary *)getInfoForContactID:(NSString *)cont_id;
+(BOOL)existUserFor:(NSString *)contact;
+(NSString *)getImageUrlForContact:(NSString *)contact;
+(NSString *)getImageUrlForID:(NSString *)cont_id;

-(void)createInfoDataBaseAt:(NSString *)path;
-(void)insertIntoInfoDB:(NSDictionary *)infoDict;
-(void)updateImageInfoFor:(NSDictionary *)infoDict;
-(void)updateContactBlockedInfo:(BOOL)isBlocked forContactID:(NSString *)cont_id;
-(void)updateUserBlockedInfo:(BOOL)userBlocked byContactID:(NSString *)cont_id;

#pragma mark - Group DB methods
+(NSString *)groupDB_path;
+(NSArray *)getMessageInfoForGroup:(NSString *)grp_id;
+(NSArray *)getGroupiesFor:(NSString *)group_id;
+(BOOL)existUser:(NSString *)user_cont ForGroup:(NSString *)group_id;
+(NSArray *)getGroupDetailWithContact:(NSString *)contact;

-(void)createGroupDataBaseAt:(NSString *)path;
-(void)insertIntoGroupDB:(NSDictionary *)groupDict;
-(void)updateGroupNameOf:(NSString *)grp_id withName:(NSString *)grp_name;
-(void)updateGrpMsgDeliveredStatus:(BOOL)delivered seenStatus:(BOOL)seen forInfo:(NSDictionary *)infoDict;
-(void)deleteMember:(NSString *)contact fromGroup:(NSString *)grp_id;

#pragma mark - Log DB handler

+(NSString *)logDB_path;
+(NSArray *)getCallLog;

-(void)createLogDataBaseAt:(NSString *)path;
-(void)insertLogDB:(NSDictionary *)logDict;
-(void)deleteLog:(NSDictionary *)deleteDict;

@end

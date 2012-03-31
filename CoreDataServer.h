//
//  DataServer.h
//  HamiUIControl
//
//  Created by Dominic Chang on 10/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HamiMusicSong.h"
#import "HamiMusicAlbum.h"
#import "HamiMusicChannel.h"


//ManagedContext, Entity name, rawData Dictionary
typedef void (^objectOperationBlock)(NSManagedObjectContext *context,
                                     NSDictionary *hostObjectData,
                                     NSManagedObject *localManagedObject);


@protocol CoreDataServerDelegate;
@interface CoreDataServer : NSObject <NSCoding>
@property (nonatomic, retain) NSArray *rootChannelObjects;
@property (nonatomic, retain, readonly) NSDictionary *dataModelMapping;
@property (nonatomic, retain, readonly) HamiMusicChannel *myFavoriteChannel;
@property (nonatomic, readonly) NSUInteger myFavoriteChannelIndex;
@property (nonatomic, assign) id<CoreDataServerDelegate> delegate;

//Singleton object instance
+ (CoreDataServer *) sharedCoreDataServer;


//save the core data managed object context
- (void)saveContext;


//save the CoreDataServer object state to UserDefaults
- (void)saveObject;


//Server validation
- (void) validateServerData: (NSError **)outError;


//delete duplication
- (void) deleteObjects: (NSSet *)deathRoll;


- (NSUInteger) findChannel:(NSString *)channelID;
- (HamiMusicChannel *) channelAtIndex:(NSUInteger)index;
- (void) populateSongsInAlbum: (HamiMusicAlbum *)anAlbum;
- (void) flagNeedToUpdateChannelSongSortOrder;
- (void) preLoadFirstSongForAllChannel;

@end

#define SHARED_COREDATA_SERVER [CoreDataServer sharedCoreDataServer]

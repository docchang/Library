//
//  DataServer.m
//  HamiUIControl
//
//  Created by Dominic Chang on 10/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "CoreDataServerDelegate.h"
#import "CoreDataServer.h"
#import "RadioUtility.h"
//#import "TimeConversion.h"
#import "Constants.h"
#import "NSObject+PropertyArray.h"


@interface CoreDataServer ()
//Core Data Objects
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
- (NSURL *)applicationDocumentsDirectory;


@property (nonatomic, assign) NSTimeInterval timeStamp;
@property (nonatomic, retain, readwrite) NSDictionary *dataModelMapping;
@property (nonatomic, retain) NSMutableDictionary *keyStore;
@property (nonatomic, retain, readwrite) NSArray *rootSongObjects;
@property (nonatomic, retain, readwrite) HamiMusicChannel *myFavoriteChannel;
+ (CoreDataServer *) loadObject;

- (void) initializeChannelObjects;

- (void) repopulateCoreDataServer: (NSError **)outError;

- (id) mappingLookup:(NSString *)entity
                 key:(NSString *)key;

- (HamiMusicChannel *) createChannel:(NSManagedObjectContext *)context
        hostObjectData:(NSDictionary *)hostObjectData;

- (void) insertUniquely:(NSArray *)rawDataArray 
                 entity:(NSString *)entity 
           matchedBlock:(objectOperationBlock)matchedOperation
     hostUnmatchedBlock:(objectOperationBlock)hostUnmatchedOperation
    localUnmatchedBlock:(objectOperationBlock)localUnmatchedOperation
                  error:(NSError **)outError;

@end



@implementation CoreDataServer
//core data objects
@synthesize managedObjectContext = __managedObjectContext;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;

@synthesize timeStamp;
@synthesize dataModelMapping;
@synthesize keyStore;

@synthesize rootChannelObjects;
@synthesize rootSongObjects;

@synthesize myFavoriteChannel;
@synthesize myFavoriteChannelIndex;

@synthesize delegate;

//option values
const NSUInteger checkCodeErrorLimit = 50;
const NSTimeInterval kHoursToNextPullRequest = 12;       //0 to always pull, INT64_MAX to never pull, or 72 hours
const NSTimeInterval kSecondsToNextPullRequest = kHoursToNextPullRequest * 60 * 60; //Hours * Minues * Seconds = Total Seconds
const bool displayCompleteness = NO;
const bool verifyCoreDataStore = NO;


//Constants
NSString * const kCoreDataServerKey = @"HamiMusicCoreData";
NSString * const kDefaultMP3URL = @"defaultMP3URL";
NSString * const kDefaultRawDataID = @"defaultRawDataID";
NSString * const kDefaultObjectID = @"defaultObjectID";
NSString * const kDefaultSongList = @"defaultSongList";


/**
 * Get channel at the given index
 *
 * @param index
 *            Unsigned integer index
 *
 * @return HamiMusicChannel*
 *            Returns a pointer to the indexed channel
 */
- (HamiMusicChannel *) channelAtIndex:(NSUInteger)index {
    if (rootChannelObjects.count > 0 && rootChannelObjects.count > index )
        return [rootChannelObjects objectAtIndex:index];
    return nil;
}

/**
 returns a record count given an entity and the current context
 */
+ (NSUInteger) recordCount: (NSManagedObjectContext *)context
             entityForName: (NSString *) entityName {
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:entityName
                                   inManagedObjectContext:context];
    [fetchRequest setEntity:entity];
    NSError *error = nil;
    NSUInteger count = [context countForFetchRequest:fetchRequest error:&error];
    [fetchRequest release];
    
    if(count == NSNotFound) {
        //Handle error
        NSLog(@"Error: %@", error);
        return 0;
    }
    
    return count;
}

- (NSTimeInterval) secondsElapsed: (NSTimeInterval)time {
    return [[NSDate date]timeIntervalSince1970] - time;
}

- (NSUInteger) findChannel:(NSString *)channelID {
    NSLog(@"aChannel:%@", channelID);
    
    if ([channelID isEqualToString:kNotFound]) {
        return NSNotFound;
    }

    NSUInteger i = 0;
    for (HamiMusicChannel *aChannel in self.rootChannelObjects) {        
        NSLog(@"rootChannel:%@, testChannel:%@", aChannel.rc_id, channelID);
        
        if ([aChannel.rc_id isEqualToString:channelID]) {
            return i;
        }
        i++;
    }
    return NSNotFound;
}

- (BOOL) isCoreDataEmpty {
    return ([CoreDataServer recordCount:[self managedObjectContext] entityForName:kEntityNameChannel] == 0);
}

- (BOOL) shouldValidateServerData {
    //repopulate core data server when it is empty
    if (!timeStamp) {
        return YES;
    }
	
	//if accumulated checkcode error count exceeds limit than validation is required
	if ([RadioUtility checkCodeErrorCount] > checkCodeErrorLimit) {
		return YES;
	}
    
    NSLog(@"Last time system checked with server @ %@", [NSDate dateWithTimeIntervalSince1970:timeStamp]);    
    NSTimeInterval secondDifference = kSecondsToNextPullRequest - [self secondsElapsed:timeStamp];
    if (secondDifference < 0) {
        NSLog(@"Validation request granted!");
        return YES;
    }
    
    
    NSLog(@"%f seconds left to the next data validation request.", secondDifference);

    
//    NSLog(@"%@ left to the next data validation request.",
//          [TimeConversion 
//           displayTimeText:0 
//           minute:0 
//           second:secondDifference]);

    return NO;
}

#pragma mark -
#pragma mark deleteDuplication
- (void) deleteObjects: (NSSet *)deathRoll {
	for (NSManagedObject * obj in deathRoll) {
		[self.managedObjectContext deleteObject:obj];
	}
}

#pragma mark -
#pragma mark validateServerData
/**
 Validate server data populate when needed. Return YES if rootChannelObjects was altered
 */
- (void) validateServerData: (NSError **)outError {

    //repopulate core data server when it is empty
    if (!timeStamp || [self isCoreDataEmpty]) {
        NSLog(@"Re-populate granted");
        
        NSError *error = nil;
        [self repopulateCoreDataServer:&error];
        if (error) {
            *outError = error;
            return;
        }
        
        //initialize channel objects
        [self initializeChannelObjects];
        
        //core data was altered delegate
        if ([delegate respondsToSelector:@selector(coreDataWasPopulated)]) {
            [delegate coreDataWasPopulated];
        }

        return;
    }
    
    if (![self shouldValidateServerData]) {        
        //core data did not change delegate
        if ([delegate respondsToSelector:@selector(coreDataDidNotChange)]) {
            [delegate coreDataDidNotChange];
        }
        return;
    }
    
    //Gather server data
    NSError *error = nil;
    NSArray *hostChannels = [RadioUtility loadChannels:&error];
    if (error) {
        NSLog(@"Error! [RadioUtility loadChannels]: %@",[error localizedDescription]);
        *outError = error;
        return;
    }
    
    NSString *hostObjectLastModify = [self mappingLookup:kEntityNameChannel key:@"lastmodify"];
    
    //initialize key store prevent duplicates
    self.keyStore = [[NSMutableDictionary alloc] init];

    error = nil;
    
    NSMutableArray *mutaUpdatedChannels = [[NSMutableArray alloc] init];
    NSMutableArray *mutaCreatedChannels = [[NSMutableArray alloc] init];
    NSMutableArray *mutaDeletedChannels = [[NSMutableArray alloc] init];
    
    [self saveContext];
    [self 
     insertUniquely:hostChannels             
     entity:kEntityNameChannel
     matchedBlock:^(NSManagedObjectContext *context, NSDictionary *hostObjectData, NSManagedObject *localManagedObject) {

         //matched Channel
         HamiMusicChannel *channel = (HamiMusicChannel *)localManagedObject;         
         //if lastmodify field is the same do nothing
         if ([[hostObjectData objectForKey:hostObjectLastModify] isEqualToString:channel.lastmodify]) {
             return;
         }
         
         NSLog(@"Modifing matched channel:%@, %@, %@", channel.rc_id, channel.rc_name, channel.lastmodify);
         NSLog(@"matched hostObject:%@", hostObjectData);

         //delete and re-create
         [context deleteObject:localManagedObject];
         
         //re-create channel
         [mutaUpdatedChannels addObject:[self createChannel:context hostObjectData:hostObjectData]];
     }
     hostUnmatchedBlock:^(NSManagedObjectContext *context, NSDictionary *hostObjectData, NSManagedObject *localManagedObject) {
         localManagedObject = nil;

         NSLog(@"hostUnmatchedBlock hostObjectData: %@", hostObjectData);
         
         //create channel
         [mutaCreatedChannels addObject:[self createChannel:context hostObjectData:hostObjectData]];
     }
     localUnmatchedBlock:^(NSManagedObjectContext *context, NSDictionary *hostObjectData, NSManagedObject *localManagedObject) {
         hostObjectData = nil;
         
         HamiMusicChannel *channel = (HamiMusicChannel *)localManagedObject;
         NSLog(@"localUnmatchedBlock channel:%@, %@, %@", channel.rc_id, channel.rc_name, channel.lastmodify);
         
         //ignore My Favorite channels
         if ([channel.rc_id isEqualToString:kDefaultMyFavoriteChannelID]) {
             return;
         }
         
         //add local managed object to deleted list before deletion happens
         [mutaDeletedChannels addObject:localManagedObject];
         
         //delete local channel
         [context deleteObject:localManagedObject];
     }
     error:&error];

    if (error) {
        NSLog(@"Error! Unique inserting host channels: %@",[error localizedDescription]);
        [keyStore release];
        *outError = error;
        return;
    }
    
    //release keyStore
    [keyStore release];
    
    //renew a successful host verification time stamp
    timeStamp = [[NSDate date] timeIntervalSince1970];    
    
    if ([[self managedObjectContext] hasChanges] || rootChannelObjects.count == 0) {
        //save Context
        [self saveContext];
        [self saveObject];
        
        
        //initialize channel objects
        [self initializeChannelObjects];

        
        //core data was altered delegate
        if ([delegate respondsToSelector:@selector(coreDataWasAltered:createdChannels:deletedChannels:)]) {
            [delegate coreDataWasAltered:[NSArray arrayWithArray:mutaUpdatedChannels]
                         createdChannels:[NSArray arrayWithArray:mutaCreatedChannels]
                         deletedChannels:[NSArray arrayWithArray:mutaDeletedChannels]];
        }
    } else {        
        //core data did not change delegate
        if ([delegate respondsToSelector:@selector(coreDataDidNotChange)]) {
            [delegate coreDataDidNotChange];
        }
    }
    
    [mutaUpdatedChannels release];
    [mutaCreatedChannels release];
    [mutaDeletedChannels release];
}

/**
 Basic selection on a entity with predicate and sortDescriptors if exists
 */
- (NSArray *) selectEntity: (NSString *) entityName 
             withPredicate: (NSPredicate *) predicate
       withSortDescriptors: (NSArray *) sortDescriptors {
    
    //selecting
    NSManagedObjectContext *context = [self managedObjectContext];
    NSError *error;
    
    //populate root Channel NSManaged Objects
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription 
                                   entityForName:entityName
                                   inManagedObjectContext:context];
    [fetchRequest setEntity:entity];
    
    //    NSPredicate *predicate = [NSPredicate 
    //                              predicateWithFormat:@"channelid == %@", @"29"];
    
    if (predicate) {
        [fetchRequest setPredicate:predicate];
    }    
    
    //    // Edit the sort key as appropriate.
    //    NSSortDescriptor *createDateSortDcptor = [[NSSortDescriptor alloc] 
    //                                              initWithKey:@"createDateTime" 
    //                                              ascending:YES];
    //    NSArray *sortDescriptors = [[NSArray alloc] 
    //                                initWithObjects:createDateSortDcptor, 
    //                                nil];
    
    if (sortDescriptors) {
        [fetchRequest setSortDescriptors:sortDescriptors];
    }
    
    NSArray *fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
    //error handling
    if (fetchedObjects == nil) {
        NSLog(@"Error! couldn't fetche: %@", [error localizedDescription]);
    }
    [fetchRequest release];
    
    //    //printing
    //    for (Song *item in fetchedObjects) {
    //        NSLog(@"Fetched item: id:%@, name:%@", item.songid, item.songname);
    //    }
    
    return fetchedObjects;
}


- (id) mappingLookup:(NSString *)entity
                 key:(NSString *)key {
    return [[dataModelMapping objectForKey:entity] objectForKey:key];
}

- (BOOL) refreshMyFavoriteChannel {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"rc_id == %@", kDefaultMyFavoriteChannelID];
    NSArray *result = [self selectEntity:kEntityNameChannel withPredicate:predicate withSortDescriptors:nil];
    
    if (result.count == 0) {
        myFavoriteChannel = nil;
        myFavoriteChannelIndex = NSNotFound;
        return NO;
    }
    
    self.myFavoriteChannel = (HamiMusicChannel *)[result objectAtIndex:0];
    myFavoriteChannelIndex = [rootChannelObjects indexOfObject:myFavoriteChannel];
    return YES;
}

- (HamiMusicChannel *) createMyFavoriteChannel {
    if ([self refreshMyFavoriteChannel] == NO) {
        //create
        self.myFavoriteChannel = [NSEntityDescription 
                                  insertNewObjectForEntityForName:kEntityNameChannel 
                                  inManagedObjectContext:[self managedObjectContext]];
    
        //setting ManagedObject with raw data from server and its translator
        [myFavoriteChannel setPropertyValues:[RadioUtility getMyFavoriteChannel]
                              withTranslator:[dataModelMapping objectForKey:kEntityNameChannel]];
    }
    
    return myFavoriteChannel;
}

- (NSUInteger) myFavoriteChannelIndex {
    if (myFavoriteChannel == nil || myFavoriteChannelIndex == NSNotFound) {
        [self refreshMyFavoriteChannel];
    }
    return myFavoriteChannelIndex;
}
- (HamiMusicChannel *)myFavoriteChannel {
    if (myFavoriteChannel == nil || myFavoriteChannelIndex == NSNotFound) {
        [self refreshMyFavoriteChannel];
    }
    return myFavoriteChannel;
}


/**
 Create unique NSManagedObjects return previous created objects during
 collusion
 */
- (id) createNewManagedObject: (NSManagedObjectContext *)context 
                       entity: (NSString *)entity
                       values: (NSDictionary *)rawData {
    
    NSString *rawDataKeyValue = [rawData objectForKey:[self mappingLookup:entity key:kDefaultRawDataID]];
    
    //a key is generated using Entity.Entity_Default_Key, Channel.10 or Song.14-123232...
    NSString *keyPath = [NSString stringWithFormat: @"%@.%@", entity, rawDataKeyValue];
    
    //check to see if it exist
    if ([keyStore objectForKey:keyPath]) {
        return [keyStore objectForKey:keyPath];
    }
    
    //check data store
    NSString *objectID = [self mappingLookup:entity key:kDefaultObjectID];
    NSString *rawDataID = [rawData objectForKey:rawDataKeyValue];
    NSArray *results = [self selectEntity:entity
                            withPredicate:[NSPredicate predicateWithFormat:@"%K == %@", objectID, rawDataID]
                      withSortDescriptors:nil];
    if (results.count > 0) {
        [keyStore setObject:[results objectAtIndex:0] forKey:keyPath];
        return [results objectAtIndex:0];
    }
    
    
    id managedObject = [NSEntityDescription 
                        insertNewObjectForEntityForName:entity 
                        inManagedObjectContext:context];
    
    //setting ManagedObject with raw data from server and its translator
    [managedObject setPropertyValues:rawData 
                      withTranslator:[dataModelMapping objectForKey:entity]];
    
    //saving created object to keyStore to prevent duplicates
    [keyStore setObject:managedObject forKey:keyPath];
    
    
    return managedObject;
}

//static double completedCounter = 0.0;
- (void) displayPercentage:(double)completed
                     total:(double)total {
    if (displayCompleteness) {
        NSLog(@"%.0f out of %.0f completed: %2.2f%%", completed, total, (completed / total * 100));
    }
}

- (void) flagNeedToUpdateChannelSongSortOrder {
    [self.rootChannelObjects makeObjectsPerformSelector:@selector(flagNeedToUpdateSortOrder)];
}

- (void) preLoadFirstSongForAllChannel {
    NSLog(@"preLoadFirstSongForAllChannel");
    
    NSInteger const preLoadIndex = 0;
    for (HamiMusicChannel *aChannel in self.rootChannelObjects) {
        if (aChannel.sortedSongs.count > 0) {
            [(HamiMusicSong *)[aChannel.sortedSongs objectAtIndex:preLoadIndex] loadSongContentCompletionBlock:nil FailedBlock:nil];
        }
    }
}

- (void) initializeChannelObjects {
    [self createMyFavoriteChannel];
    
    // Set "priority_int" as the sort key
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"priority_int" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];

    //can NOT use sortDescriptor here because priority_int is NOT an entity property, it is an user defined property
    self.rootChannelObjects = [self selectEntity:kEntityNameChannel withPredicate:nil withSortDescriptors:nil];

    //sort using sortedArrayUsingDescriptors
    self.rootChannelObjects = [rootChannelObjects sortedArrayUsingDescriptors:sortDescriptors];
    
    //release sortDescriptors
    [sortDescriptor release];
    [sortDescriptors release];
    
    [self refreshMyFavoriteChannel];
}


- (NSArray *)fetchRequestContext:(NSManagedObjectContext *)context 
                          entity:(NSString *)entity
                       predicate:(NSPredicate *)predicate 
                 sortDescriptors:(NSArray *)sortDescriptors
                           error:(NSError **)outError {

    // create the fetch request to get all Employees matching the IDs
    NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];    
    [fetchRequest setEntity:[NSEntityDescription entityForName:entity inManagedObjectContext:context]];
    
    
    //Predicate
    [fetchRequest setPredicate:predicate];
    
    
    //sort the result
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    
    // Execute the fetch
    NSError *error = nil;
    NSArray *matchedPrimaryKeys = [context executeFetchRequest:fetchRequest error:&error];
    if (error != nil) {
        *outError = error;
        return nil;
    }
    
    return matchedPrimaryKeys;
}

- (NSArray *) aSortDescriptor:(NSString *)sortKey ascending:(BOOL)ascending {
    return [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey:sortKey ascending:ascending] autorelease]];
}

- (void) insertUniquely:(NSArray *)rawDataArray 
                    entity:(NSString *)entity 
              matchedBlock:(objectOperationBlock)matchedOperation
        hostUnmatchedBlock:(objectOperationBlock)hostUnmatchedOperation
       localUnmatchedBlock:(objectOperationBlock)localUnmatchedOperation
                     error:(NSError **)outError {
    
    
    if (rawDataArray) {
        //object primary key
        NSString * primaryKeyString = [self mappingLookup:entity key:kDefaultObjectID];
        //Raw data primary key mapping look up e.g. SONG_ID
        NSString * rawDataPrimaryKeyString = [self mappingLookup:entity key:primaryKeyString];
        //sort the raw data array using its primary key ascending order
        NSArray *sortedRawDataArray = [rawDataArray sortedArrayUsingDescriptors:[self aSortDescriptor:rawDataPrimaryKeyString ascending:YES]];
        //grab the keys only
        NSArray *insertingIDs = [sortedRawDataArray valueForKey:rawDataPrimaryKeyString];
//        NSLog(@"rawKey: %@, key: %@, SongIDs: %@", rawDataPrimaryKeyString, primaryKeyString, insertingIDs);

        
        
        
        if (insertingIDs.count > 0) {
            //initiate a fetch that finds existing primary keys
            //get the current context
            NSManagedObjectContext *context = [self managedObjectContext];
            
            
            //fetch unmatching objects
            if (localUnmatchedOperation != nil) {
                NSError *error = nil;
                NSArray *localUnmatchedArray = [self fetchRequestContext:context
                                                                  entity:entity
                                                               predicate:[NSPredicate predicateWithFormat:@"NOT (%K IN %@)", primaryKeyString, insertingIDs]
                                                         sortDescriptors:[self aSortDescriptor:primaryKeyString ascending:YES]
                                                                   error:&error];
                if (error != nil) {
                    *outError = error;
                    NSLog(@"error fetching local unmatched objects: %@", error);
                    return;
                }
                
                //perform desinated operation for fetched localUnmatchedArray                
                for (NSManagedObject * object in localUnmatchedArray) {
                    localUnmatchedOperation(context, nil, object);
                }
            }
            
            
            //fetch matching objects
            NSError *error = nil;
            NSArray *matchedArray = [self fetchRequestContext:context
                                                       entity:entity
                                                    predicate:[NSPredicate predicateWithFormat:@"(%K IN %@)", primaryKeyString, insertingIDs]
                                              sortDescriptors:[self aSortDescriptor:primaryKeyString ascending:YES]
                                                        error:&error];
            if (error != nil) {
                *outError = error;
                NSLog(@"error fetching local matching objects: %@", error);
                return;
            }

            
            //calculate host unmatched objects and matched objects
            NSArray *matchedIDs = [matchedArray valueForKey:primaryKeyString];            
            if (matchedIDs.count > 0 && (matchedOperation != nil || hostUnmatchedOperation != nil)) {    
                
                //implementing Find-or-Create algorithm described at the apple documentation link below
                //http://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/CoreData/Articles/cdImporting.html#//apple_ref/doc/uid/TP40003174-SW1
                NSUInteger i = 0;   //index of matched ID
                for (NSDictionary *rawData in sortedRawDataArray) {

                    //rawData Primary ID
                    NSString *oneID = [rawData objectForKey:rawDataPrimaryKeyString];
        
                    if (i < matchedArray.count && [[matchedIDs objectAtIndex:i] isEqualToString:oneID]) {
                        if (matchedOperation) {
                            matchedOperation(context, rawData, [matchedArray objectAtIndex:i]);
                        }
                        i++;
                        continue;
                    } else {
                        if (hostUnmatchedOperation) {
                            hostUnmatchedOperation(context, rawData, nil);
                        }
                    }
                }
            }
        }
    }
}

- (void) populateSongsInAlbum:(HamiMusicAlbum *)anAlbum {
    //get the JSON song list array
    NSDictionary *rawDataAlbum = [RadioUtility getAlbum:anAlbum.album_id];
    //update album information
    [anAlbum setPropertyValues:rawDataAlbum withTranslator:[dataModelMapping objectForKey:kEntityNameAlbum]];

    NSLog(@"Album Release Date: %@", anAlbum.release_date);
    
    NSString *localMP3URLKey = [[self mappingLookup:kEntityNameSong key:kDefaultAlbumMp3URLKey] objectForKey:kURL];

    NSArray *rawDataSongs = [rawDataAlbum objectForKey:[self mappingLookup:kEntityNameAlbum key:kDefaultSongList]];
    NSError *error = nil;
    [self insertUniquely:rawDataSongs 
                  entity:kEntityNameSong
            matchedBlock:^(NSManagedObjectContext *context, NSDictionary *hostObjectData, NSManagedObject *localManagedObject) {
                
                //setting album mp3 url link 
                HamiMusicSong *localSong = (HamiMusicSong *)localManagedObject;
                [localSong setValue:[hostObjectData objectForKey:[self mappingLookup:kEntityNameSong key:localMP3URLKey]]
                             forKey:localMP3URLKey];

            }
      hostUnmatchedBlock:^(NSManagedObjectContext *context, NSDictionary *hostObjectData, NSManagedObject *localManagedObject) {
          
          //create song
          HamiMusicSong *aSong = [NSEntityDescription insertNewObjectForEntityForName:kEntityNameSong inManagedObjectContext:context];
          
          //setting ManagedObject with raw data from server and its translator
          [aSong setPropertyValues:hostObjectData withTranslator:[dataModelMapping objectForKey:kEntityNameSong]];
          
          //add song to its album
          [anAlbum addSongsinalbumObject:aSong];

      }
     localUnmatchedBlock:nil 
                   error:&error];
}

////Synchronously populating albums
//- (void) populateAlbums {
//    NSLog(@"Populating Albums...");
//    NSManagedObjectContext *context = [self managedObjectContext];
//    
//    //building albums and its songs
//    for (NSString *albumID in albumIDArray) {
//        //retrieve albums
//        NSDictionary *rawDataOneAlbum = [RadioUtility getAlbum:albumID];
//        //create album managed object
//        HamiMusicAlbum *anAlbum = [self createNewManagedObject:context entity:kEntityNameAlbum values:rawDataOneAlbum];
//        //get the songs within the raw data
//        NSArray *rawDataSongs = [rawDataOneAlbum objectForKey:[self mappingLookup:kEntityNameAlbum key:kDefaultSongList]];
//        //insert songs uniquely
//        [anAlbum addSongsinalbum:[self insertUniquely:rawDataSongs entity:kEntityNameSong]];
//    }
//    NSLog(@"Populating Albums Completed");
//}

#pragma mark -
#pragma mark createChannel
- (HamiMusicChannel *) createChannel:(NSManagedObjectContext *)context
        hostObjectData:(NSDictionary *)hostObjectData {
    
    //create Channel NSManagedObject
    HamiMusicChannel *aChannel = [self createNewManagedObject:context
                                                       entity:kEntityNameChannel
                                                       values:hostObjectData];
    
    int i = 0;
    NSMutableDictionary *songPriorityKey = [[NSMutableDictionary alloc] init];
    NSArray *rawDataSongs = [[RadioUtility getChannel:aChannel.rc_id] objectForKey:[self mappingLookup:kEntityNameChannel key:kDefaultSongList]];    
    for (NSDictionary *rawDataOneSong in rawDataSongs) {
        HamiMusicSong *aSong = [self createNewManagedObject:context
                                                     entity:kEntityNameSong
                                                     values:rawDataOneSong];
        
        //Song Raw Data also contains some album information
        HamiMusicAlbum *anAlbum = [self createNewManagedObject:context
                                                        entity:kEntityNameAlbum
                                                        values:rawDataOneSong];
        
        //add the album to song
        [aSong setAlbuminsong:anAlbum];
        
        //add the channel to song
        [aSong addChannelsinsongObject: aChannel];
        
        //add song in order
        [songPriorityKey setObject:[NSNumber numberWithInt:i] forKey:aSong.song_id];
        i++;
    }
    
    //save the song priority key into core data
    [aChannel setSongprioritykey:[NSKeyedArchiver archivedDataWithRootObject:[NSDictionary dictionaryWithDictionary:songPriorityKey]]];
    //flag the need to update sort order
    [aChannel flagNeedToUpdateSortOrder];
    //release key
    [songPriorityKey release];
    
    return aChannel;
}


/**
 Channels Re-population
 */
- (void) populateChannels: (NSError **)outError {
    NSLog(@"Populating Channels...");
    
    NSManagedObjectContext *context = [self managedObjectContext];
        
    //importing channels without its songs from server
    NSError *error = nil;
    NSArray *rawDataChannels = [RadioUtility loadChannels:&error];
    if (error) {
        NSLog(@"Error populateChannels: %@", error);
        *outError = error;
        return;
    }
    
    for (NSDictionary *rawDataOneChannel in rawDataChannels) {
        
        [self createChannel:context hostObjectData:rawDataOneChannel];

    }    
    
    //timestamp received data
    timeStamp = [[NSDate date] timeIntervalSince1970];
    
    
    //save Context
    [self saveContext];
    [self saveObject];
    
    
    
    NSLog(@"Channels Completed");
}

/**
 Remove all current objects in the Core Data Store
 */
- (void)resetCoreDataComponents {
    [[self managedObjectContext] lock];
    [[self managedObjectContext] reset];
    
    NSPersistentStore* store = [[__persistentStoreCoordinator persistentStores] lastObject];
    NSURL *storeURL = store.URL;
    NSError *error = nil;
    
    [__persistentStoreCoordinator removePersistentStore:store error:&error];
    
    // Release CoreData chain
    [__managedObjectContext release];
    __managedObjectContext = nil;
    [__managedObjectModel release];
    __managedObjectModel = nil;
    [__persistentStoreCoordinator release];
    __persistentStoreCoordinator = nil;
    
    
    [[NSFileManager defaultManager] removeItemAtPath:storeURL.path error:&error];
    if (error) {
        NSLog(@"filemanager error %@", error);
    } else {
        NSLog(@"Reset presistent store completed!");
    }
    
    //now recreate persistent store
    [self persistentStoreCoordinator];
    [[self managedObjectContext] unlock];
    
    __managedObjectContext = [self managedObjectContext];
}

/**
 Re-populate Core Data Server
 */
- (void) repopulateCoreDataServer: (NSError **)outError {
    //get current time to display time elapsed
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    
    
    //reset Core Data Components
    [self resetCoreDataComponents];
    
    
    
    //initialize key store prevent duplicates
    self.keyStore = [[NSMutableDictionary alloc] init];

    
    
    
    //importing channels from server
    NSError *error = nil;
    [self populateChannels:&error];
    if (error) {
        NSLog(@"Error populating channel: %@", error);
        *outError = error;
    }
    
    
    
    //release key store
    [keyStore release];
    keyStore = nil;
    
    
    
    //display time elapsed
    NSLog(@"Core Data Repopulated in %3.2f seconds.", [self secondsElapsed: startTime]);
}

/**
 Please use asynchronice call
 */
- (void) initCommon {
    //initialize translators
    self.dataModelMapping = [[NSDictionary alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DataModelMapping" ofType:@"plist"]];
    
    
    //initialize root channel objects
    [self initializeChannelObjects];
    
//    //Data server logic determines if it needs a purge
//    if ([self shouldResetDataStore]) {
//        NSLog(@"Reseting Data Store...");
//        
//        //will finish channels first and delegate AlbumObjects when it is ready
//        [self repopulateCoreDataServer];
//    } else {    //core data store already loaded
//        //initializing properties objects
//        [self initializeChannelObjects];        
//    }
}

- (void) saveObject {
    //archive self into NSData using "encodeWithCoder"
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
    
    //save data into UserDefault and associates with a operation key
	[[NSUserDefaults standardUserDefaults] setObject:data forKey:(NSString *)kCoreDataServerKey];
    
    //saves NSUserDefaults into file
	[[NSUserDefaults standardUserDefaults] synchronize];
}

/**
 It is recommended to asynchronously use + (CoreDataServer *) sharedCoreDataServer 
 to intialize CoreDataServer object like below:

 
 
 dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ), ^{
    <YOUR_OBJECT> = [CoreDataServer sharedCoreDataServer];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Finished loading core data");
    });
 });
 
 
 
 */
+ (CoreDataServer *) loadObject {    
    CoreDataServer *object = nil;
    @try {
        NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:(NSString *)kCoreDataServerKey];
        if (data == nil) {
            object = [[CoreDataServer alloc] init];
            [object saveObject];
            [object autorelease];
        } else {
            object = (CoreDataServer *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
        }
    } @catch (NSException * e) {
        NSLog(@"Error Loading Core Data\n%@", [e reason]);
    } @finally {
        return object;
    }
}

static CoreDataServer *sharedDispatchCoreDataServer = nil;
+ (CoreDataServer *) sharedCoreDataServer {    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDispatchCoreDataServer = [CoreDataServer loadObject];
    });
	return sharedDispatchCoreDataServer;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super init])) {
        timeStamp = [aDecoder decodeDoubleForKey:@"timeStamp"];
        [self initCommon];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeDouble:timeStamp forKey:@"timeStamp"];
}

- (id) init {
    if ((self = [super init])) {
        [self initCommon];
    }
    return self;
}

- (void)dealloc {
    [dataModelMapping release];
    [keyStore release];
//    [albumIDArray release];
    
    [rootChannelObjects release];
    [rootSongObjects release];
    [myFavoriteChannel release];
    
    [__managedObjectContext release];
    [__managedObjectModel release];
    [__persistentStoreCoordinator release];
    [super dealloc];
}



- (void)awakeFromNib
{
    /*
     Typically you should set up the Core Data stack here, usually by passing the managed object context to the first view controller.
     self.<#View controller#>.managedObjectContext = self.managedObjectContext;
     */
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil)
    {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error])
        {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}


#pragma mark - Core Data stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext != nil)
    {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil)
    {
        __managedObjectContext = [[NSManagedObjectContext alloc] init];
        [__managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return __managedObjectContext;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel != nil)
    {
        return __managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"HamiUIControl" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];    
    return __managedObjectModel;
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (__persistentStoreCoordinator != nil)
    {
        return __persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"HamiUIControl.sqlite"];
    
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
							 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
	
    NSError *error = nil;
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error])
    {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter: 
         [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return __persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

/**
 Returns the URL to the application's Documents directory.
 */
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end

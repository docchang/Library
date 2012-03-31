//
//  Constants.h
//  HamiMusic
//
//  Created by Dominic Chang on 10/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//


//used in DataModelMapping.plist
extern NSString * const kDefaultChannelMp3URLKey;
extern NSString * const kDefaultAlbumMp3URLKey;
extern NSString * const kDefaultAlbumCoverURLKey;

//Core Data Entity Names
extern NSString * const kEntityNameSong;
extern NSString * const kEntityNameAlbum;
extern NSString * const kEntityNameChannel;

//keyValuePair
extern NSString * const kURL;
extern NSString * const kContent;

//keyValuePair type
extern NSString * const kType;
extern NSString * const kImage;
extern NSString * const kMusic;

//Notifications
extern NSString * const kNotificationAnimateActivityIndicator;
extern NSString * const kNotificationStopAnimateActivityIndicator;
extern NSString * const kNotificationHamiMusicViewWillAppear;
extern NSString * const kNotificationAudioManagerSongUpdated;
extern NSString * const kNotificationAlbumStartAnimateActivityIndicator;
extern NSString * const kNotificationAlbumStopAnimateActivityIndicator;

//default MyFavorite rc_id
extern NSString * const kDefaultMyFavoriteChannelID;

//default number of sections
extern NSInteger const kDefaultSection;

//Maximum concurrent operations
extern NSInteger const kMaxConcurrentOperationCount;

//default song and channel index
extern NSInteger const kDefaultChannelIndex;
extern NSInteger const kDefaultSongIndex;


extern NSString * const kNotFound;
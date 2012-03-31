//
//  Constants.cpp
//  HamiMusic
//
//  Created by Dominic Chang on 10/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//


#import "Constants.h"


NSString * const kDefaultChannelMp3URLKey = @"defaultChannelMp3URLKey";
NSString * const kDefaultAlbumMp3URLKey = @"defaultAlbumMp3URLKey";
NSString * const kDefaultAlbumCoverURLKey = @"defaultAlbumCoverURLKey";

NSString * const kEntityNameSong = @"HamiMusicSong";
NSString * const kEntityNameAlbum = @"HamiMusicAlbum";
NSString * const kEntityNameChannel = @"HamiMusicChannel";

NSString * const kURL = @"url";
NSString * const kContent = @"content";

NSString * const kNotificationAnimateActivityIndicator = @"com.springhouse.beingloadingcontent";
NSString * const kNotificationStopAnimateActivityIndicator = @"com.springhouse.finishedloadingcontent";
NSString * const kNotificationHamiMusicViewWillAppear = @"com.springhouse.hamimusic.viewwillappear";
NSString * const kNotificationAudioManagerSongUpdated = @"com.springhouse.audiomanager.songupdated";
NSString * const kNotificationAlbumStartAnimateActivityIndicator = @"com.springhouse.albumloadingcontent";
NSString * const kNotificationAlbumStopAnimateActivityIndicator = @"com.springhouse.albumfinishedloadingcontent";

NSString * const kDefaultMyFavoriteChannelID = @"0";

NSInteger const kDefaultSection = 0;

NSInteger const kMaxConcurrentOperationCount = 4;

NSInteger const kDefaultChannelIndex = 0;
NSInteger const kDefaultSongIndex = 0;


NSString * const kNotFound = @"NotFound";
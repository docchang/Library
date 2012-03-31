//
//  Utility.h
//  HamiMusic
//
//  Created by Dominic Chang on 10/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Constants.h"

@interface Utility : NSObject

+ (NSString *) sizeToString: (CGSize)size;
+ (NSString *) frameToString: (CGRect)frame;
+ (BOOL) isImageKeyValuePair: (NSDictionary *) keyValuePair;
+ (BOOL) isMusicKeyValuePair: (NSDictionary *) keyValuePair;
+ (void) saveObject: (id) obj withKey: (NSString *)key;
+ (void) executeDelegate:(id)delegate selector:(SEL)selector;

+ (void) translateUIViewAnimation: (CALayer *)layer 
							 with: (CGFloat )factor
						   forKey: (NSString *) key	
						 delegate: (id)object;


@end

//
//  NSOperationQueue+SharedQueue.h
//  HamiUIControl
//
//  Created by Dominic Chang on 11/1/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSOperationQueue (SharedQueue)

+ (NSOperationQueue *) sharedOperationQueue;
//- (void)performSelectorOnBackgroundQueue:(SEL)aSelector withObject:(id)anObject;

@end

#define SHARED_OPERATION_QUEUE [NSOperationQueue sharedOperationQueue]

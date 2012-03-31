//
//  NSOperationQueue+SharedQueue.m
//  HamiUIControl
//
//  Created by Dominic Chang on 11/1/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "NSOperationQueue+SharedQueue.h"

@implementation NSOperationQueue (SharedQueue)

+ (NSOperationQueue *) sharedOperationQueue {

    static dispatch_once_t pred;
    static NSOperationQueue* sharedQueue;
    
    dispatch_once(&pred, ^{
        sharedQueue = [[NSOperationQueue alloc] init];
    });
    
    return sharedQueue;
}

- (void) performSelectorOnBackgroundQueue:(SEL)aSelector withObject:(id)anObject {
    
    NSOperation* operation = [[NSInvocationOperation alloc] 
                              initWithTarget:self
                              selector:aSelector
                              object:anObject];
    [[NSOperationQueue sharedOperationQueue] addOperation:operation];   
    [operation release];
}

@end



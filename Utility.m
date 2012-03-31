//
//  Utility.m
//  HamiMusic
//
//  Created by Dominic Chang on 10/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Utility.h"
#import <QuartzCore/QuartzCore.h>

@implementation Utility

NSString * const kType = @"type";
NSString * const kImage = @"image";
NSString * const kMusic = @"mp3";

+ (NSString *) sizeToString: (CGSize)size {
	return [NSString stringWithFormat:@"(%5.2f, %5.2f)", size.width, size.height];
}

+ (NSString *) frameToString: (CGRect)frame {
	return [NSString stringWithFormat:@"(%5.2f, %5.2f, %5.2f, %5.2f)", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height];
}

+ (BOOL) isImageKeyValuePair: (NSDictionary *) keyValuePair {
    return ([(NSString *)[keyValuePair objectForKey:kType] isEqualToString:kImage]);
}

+ (BOOL) isMusicKeyValuePair: (NSDictionary *) keyValuePair {
    return ([(NSString *)[keyValuePair objectForKey:kType] isEqualToString:kMusic]);
}

+ (void) saveObject: (id) obj withKey: (NSString *)key {
    //archive self into NSData using "encodeWithCoder"
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:obj];
    
    //save data into UserDefault and associates with a operation key
	[[NSUserDefaults standardUserDefaults] setObject:data forKey:key];
    
    //saves NSUserDefaults into file
	[[NSUserDefaults standardUserDefaults] synchronize];

}

+ (void) executeDelegate: (id)delegate selector: (SEL) selector {
    if (delegate && [delegate respondsToSelector:selector]) {
        [delegate selector];
    }
}

+ (void) translateUIViewAnimation: (CALayer *)layer 
							 with: (CGFloat )factor
						   forKey: (NSString *) key	
						 delegate: (id)object {
	
	CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    animation.toValue = [NSNumber numberWithFloat: factor];
    animation.autoreverses = NO;
	animation.repeatCount = 0;
	animation.duration = 2.0;
	animation.removedOnCompletion = NO;
	animation.fillMode = kCAFillModeBoth; 
	animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	animation.delegate = object;
	[layer addAnimation:animation forKey:key];
}


@end

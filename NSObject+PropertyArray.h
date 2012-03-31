//
//  NSObject+PropertyArray.h
//  HamiUIControl
//
//  Created by Dominic Chang on 10/19/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (PropertyArray)


- (NSArray *) propertyKeys;

- (NSDictionary *) propertyDictionary;

- (void) setPropertyValues: (NSDictionary *)valueDictionary 
            withTranslator: (NSDictionary *)translator;

- (void) setNilPropertyValues: (NSDictionary *)valueDictionary 
               withTranslator: (NSDictionary *)translator;

@end

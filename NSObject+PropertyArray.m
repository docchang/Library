//
//  NSObject+PropertyArray.m
//  HamiUIControl
//
//  Created by Dominic Chang on 10/19/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "NSObject+PropertyArray.h"
#import <objc/runtime.h>

@implementation NSObject (PropertyArray)


/**
 Put all property names into an array
 */
- (NSArray *) propertyKeys {
    Class clazz = [self class];
    u_int count;
    
    objc_property_t* properties = class_copyPropertyList(clazz, &count);
    NSMutableArray* propertyArray = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count ; i++) {
        const char* propertyName = property_getName(properties[i]);
        [propertyArray addObject:[NSString  stringWithCString:propertyName encoding:NSUTF8StringEncoding]];
    }
    free(properties);
    
    return [NSArray arrayWithArray:propertyArray];
}

/**
 Put all properties and its value into a dictionary
 */
- (NSDictionary *) propertyDictionary {
    return [self dictionaryWithValuesForKeys:[self propertyKeys]];
}

- (void) setNilPropertyValues: (NSDictionary *)valueDictionary 
               withTranslator: (NSDictionary *)translator {
    //copys the original property and its value
    NSDictionary *properties = [[self propertyDictionary] copy];
    for (NSString *key in [translator allKeys]) {
        
        //continue to the next key when key does NOT exist at the current object
        if ([properties objectForKey:key] == nil || [self valueForKey:key] != nil) {
            continue;
        }
        
        //getting the newValue
        id obj = [valueDictionary objectForKey:[translator objectForKey:key]];
        
        if (obj) {
            //removing white spaces if object is a string type
            if ([obj isKindOfClass:[NSString class]]) {
                [self setValue: [(NSString *)obj stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] 
                        forKey: key];
            } else {
                [self setValue:obj forKey:key];
            }
        }
    }
    [properties release];
}

/**
 Using translator to set property values with a value dictionary
 It ensures translated key exists at the current object.
 It ensures the new value contains a non nil value
 */
- (void) setPropertyValues: (NSDictionary *)valueDictionary 
            withTranslator: (NSDictionary *)translator {

    //copys the original property and its value
    NSDictionary *properties = [[self propertyDictionary] copy];
    for (NSString *key in [translator allKeys]) {
        
        //continue to the next key when key does NOT exist at the current object
        if ([properties objectForKey:key] == nil) {
            continue;
        }
        
        //getting the newValue
        id obj = [valueDictionary objectForKey:[translator objectForKey:key]];

        if (obj) {
            //removing white spaces if object is a string type
            if ([obj isKindOfClass:[NSString class]]) {
                [self setValue: [(NSString *)obj stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] 
                        forKey: key];
            } else {
                [self setValue:obj forKey:key];
            }
        }
//        else {
//            NSLog(@"valueDictionary: %@", valueDictionary);
//            NSLog(@"key:%@, object:%@",[translator objectForKey:key], obj);
//        }
    }
    [properties release];
}

@end

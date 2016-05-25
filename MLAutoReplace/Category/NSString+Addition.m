//
//  NSString+Addition.m
//
//  Created by Molon on 13-11-12.
//  Copyright (c) 2013年 Molon. All rights reserved.
//

#import "NSString+Addition.h"

@implementation NSString (Addition)

+ (BOOL)IsNilOrEmpty:(NSString *)str {
    if (![str isKindOfClass:[NSString class]]) {
        return YES;
    }
    
	if (str == nil||str.length<=0) {
		return YES;
	}
    return ([str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length<=0);
}

@end

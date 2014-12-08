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
    
	if (str == nil) {
		return YES;
	}
	
	NSMutableString *string = [[NSMutableString alloc] init];
	[string setString:str];
	CFStringTrimWhitespace((__bridge CFMutableStringRef)string);
	if([string length] == 0)
	{
		return YES;
	}
	return NO;
}

@end

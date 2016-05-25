//
//  NSTextView+Addtion.m
//  MLAutoReplace
//
//  Created by molon on 4/25/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "NSTextView+Addition.h"
#import "NSString+Addition.h"
#import "NSString+PDRegex.h"

@implementation NSTextView (Addition)

- (NSInteger)ml_currentCurseLocation
{
    return [[[self selectedRanges] objectAtIndex:0] rangeValue].location;
}

- (NSString *)ml_textOfCurrentLine
{
    NSString *string = self.textStorage.string;
    if ([NSString IsNilOrEmpty:string]) {
        return nil;
    }
    
    NSInteger curseLocation = [self ml_currentCurseLocation];
    NSRange range = NSMakeRange(0, curseLocation);
    
    NSUInteger thisLineBeginLocation = [string rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:NSBackwardsSearch range:range].location;
    thisLineBeginLocation = (thisLineBeginLocation==NSNotFound)?0:thisLineBeginLocation+1;
    
    range = NSMakeRange(thisLineBeginLocation, string.length-thisLineBeginLocation);
    
    NSUInteger thisLineEndLocation = [string rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:NSLiteralSearch range:range].location;
    thisLineEndLocation = (thisLineEndLocation==NSNotFound)?string.length-1:thisLineEndLocation-1;
    
    NSRange lineRange = NSMakeRange(thisLineBeginLocation, thisLineEndLocation-thisLineBeginLocation+1);
    if (lineRange.location<string.length&&NSMaxRange(lineRange)<string.length) {
        return [string substringWithRange:lineRange];
    }
    return nil;
}

- (NSUInteger)ml_beginLocationOfCurrentLine
{
    NSString *string = self.textStorage.string;
    if ([NSString IsNilOrEmpty:string]) {
        return 0;
    }
    
    NSInteger curseLocation = [self ml_currentCurseLocation];
    NSRange range = NSMakeRange(0, curseLocation);
    
    NSUInteger thisLineBeginLocation = [string rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:NSBackwardsSearch range:range].location;
    thisLineBeginLocation = (thisLineBeginLocation==NSNotFound)?0:thisLineBeginLocation+1;
    
    if (thisLineBeginLocation<string.length) {
        return thisLineBeginLocation;
    }
    
    return 0;
}

- (NSUInteger)ml_endLocationOfCurrentLine
{
    NSString *string = self.textStorage.string;
    if ([NSString IsNilOrEmpty:string]) {
        return 0;
    }
    
    NSInteger curseLocation = [self ml_currentCurseLocation];
    NSRange range = NSMakeRange(0, curseLocation);
    
    NSUInteger thisLineBeginLocation = [string rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:NSBackwardsSearch range:range].location;
    thisLineBeginLocation = (thisLineBeginLocation==NSNotFound)?0:thisLineBeginLocation+1;
    
    range = NSMakeRange(thisLineBeginLocation, string.length-thisLineBeginLocation);
    
    NSUInteger thisLineEndLocation = [string rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:NSLiteralSearch range:range].location;
    thisLineEndLocation = (thisLineEndLocation==NSNotFound)?string.length-1:thisLineEndLocation-1;
    if (thisLineEndLocation<string.length) {
        return thisLineEndLocation;
    }
    
    return 0;
    
}

-(NSString *)ml_textUntilNextString:(NSString *)findString
{
    return [self.textStorage.string vvv_textUntilNextString:findString currentLocation:[self ml_currentCurseLocation]];
}

@end

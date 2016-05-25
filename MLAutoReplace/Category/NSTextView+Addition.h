//
//  NSTextView+Addition.h
//  MLAutoReplace
//
//  Created by molon on 4/25/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSTextView (Addition)

- (NSInteger)ml_currentCurseLocation;

//get begin location of current curse location line
- (NSUInteger)ml_beginLocationOfCurrentLine;

//get end
- (NSUInteger)ml_endLocationOfCurrentLine;

//get text of current curse location line
- (NSString *)ml_textOfCurrentLine;

//从当前位置往后找字符串直到找到XXX为止
-(NSString *)ml_textUntilNextString:(NSString *)findString;

@end

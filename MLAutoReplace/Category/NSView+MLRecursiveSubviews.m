//
//  NSView+MLRecursiveSubviews.m
//  MLAutoReplace
//
//  Created by molon on 4/26/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "NSView+MLRecursiveSubviews.h"

@implementation NSView (MLRecursiveSubviews)

- (NSArray *)allSubviews {
    NSMutableArray *allSubviews = [NSMutableArray arrayWithObject:self];
    NSArray *subviews = [self subviews];
    for (NSView *view in subviews) {
        [allSubviews addObjectsFromArray:[view allSubviews]];
    }
    return allSubviews;
}

@end

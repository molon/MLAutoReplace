//
//  MLAutoReplace.h
//  MLAutoReplace
//
//  Created by molon on 4/25/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface MLAutoReplace : NSObject

+ (id)sharedInstance;
- (void)loadReplacePlist;

@end
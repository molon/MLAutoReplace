//
//  SettingWindowController.h
//  MLAutoReplace
//
//  Created by molon on 4/26/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SettingWindowController : NSWindowController

@property (nonatomic, assign, readonly) BOOL isUseAutoReIntent;

- (IBAction)reloadPlist:(id)sender;

@end

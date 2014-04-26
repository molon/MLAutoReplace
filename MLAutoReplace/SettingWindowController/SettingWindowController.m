//
//  SettingWindowController.m
//  MLAutoReplace
//
//  Created by molon on 4/26/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "SettingWindowController.h"
#import "MLAutoReplace.h"

#define kEditPlistApplicationName @"Xcode"

@interface SettingWindowController ()

@end

@implementation SettingWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)dealloc
{
	DLOG(@"SettingWindowController dealloc");
}

- (IBAction)openGetterPlist:(id)sender {
    //打开替换getter的plist文件
    NSString *documentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *documentPath  = [documentDirectory stringByAppendingPathComponent:@"XCodePluginSetting/MLAutoReplace/ReplaceGetter.plist"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath]){
        NSString *tips = [NSString stringWithFormat:@"Please check whether .plist file exists.\n\nThe path:\n%@",documentPath];
        SHOM_SIMPLE_TIPS(tips);
        return;
    }
    
    [[NSWorkspace sharedWorkspace]openFile:documentPath withApplication:kEditPlistApplicationName];
}

- (IBAction)openOtherPlist:(id)sender {
    //打开替换getter的plist文件
    NSString *documentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *documentPath  = [documentDirectory stringByAppendingPathComponent:@"XCodePluginSetting/MLAutoReplace/ReplaceOther.plist"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath]){
        NSString *tips = [NSString stringWithFormat:@"Please check whether .plist file exists.\n\nThe path:\n%@",documentPath];
        SHOM_SIMPLE_TIPS(tips);
        return;
    }
    
    [[NSWorkspace sharedWorkspace]openFile:documentPath withApplication:kEditPlistApplicationName];
}

- (IBAction)reloadPlist:(id)sender {
    if ([[MLAutoReplace sharedInstance]loadReplacePlist]) {
        SHOM_SIMPLE_TIPS(@"Reload the data of .plist successfuly!");
    }else{
        SHOM_SIMPLE_TIPS(@"Reload the data of .plist failed!");
    }
}

@end
